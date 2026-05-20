const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const User = require('../models/User');
const Account = require('../models/Account');
const Booking = require('../models/Booking');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

router.use(authMiddleware);

const uploadDir = path.join(__dirname, '../uploads/profiles');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'profile-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ storage, limits: { fileSize: 5 * 1024 * 1024 } });

router.get('/profile', async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select('-passwordHash');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const account = await Account.findOne({ email: user.email });
    
    res.json({
      ...user.toObject(),
      accountStatus: account?.status || 'active',
      nbReceiving: account?.nb_receiving || 0
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.put('/profile', async (req, res) => {
  try {
    const { fullName, phoneNumber, address, wilaya, postalCode } = req.body;
    const user = await User.findByIdAndUpdate(
      req.user.userId,
      { fullName, phoneNumber, address, wilaya, postalCode },
      { new: true }
    ).select('-passwordHash');
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    res.json(user);
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.post('/profile/picture', upload.single('profilePicture'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }
    const profilePictureUrl = `/uploads/profiles/${req.file.filename}`;
    await User.findByIdAndUpdate(req.user.userId, { profilePicture: profilePictureUrl });
    res.json({ message: 'Profile picture updated', profilePicture: profilePictureUrl });
  } catch (error) {
    console.error('Upload profile picture error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.put('/change-password', async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: 'Current password and new password are required' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'New password must be at least 6 characters' });
    }
    
    const user = await User.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const isValid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isValid) {
      return res.status(401).json({ message: 'Current password is incorrect' });
    }
    
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    user.passwordHash = hashedPassword;
    await user.save();
    
    await Account.findOneAndUpdate(
      { email: user.email },
      { psw: hashedPassword }
    );
    
    res.json({ message: 'Password changed successfully' });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.get('/services', async (req, res) => {
  try {
    const bookings = await Booking.find({
      authorizedPersonId: req.user.userId,
      status: { $in: ['In Progress', 'Confirmed', 'Pending'] }
    }).populate('providerId', 'fullName phoneNumber profilePicture')
      .populate('clientId', 'fullName')
      .populate('serviceId', 'name');
    
    const services = bookings.map(booking => ({
      id: booking._id,
      service: booking.serviceId?.name || booking.service,
      provider: booking.providerId?.fullName || 'Unknown',
      providerId: booking.providerId?._id,
      providerAvatar: booking.providerId?.profilePicture,
      clientName: booking.clientId?.fullName,
      date: booking.date,
      time: booking.startTime,
      status: booking.status
    }));
    
    res.json(services);
  } catch (error) {
    console.error('Get services error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.get('/tracking/:serviceId', async (req, res) => {
  try {
    const booking = await Booking.findOne({ 
      _id: req.params.serviceId,
      authorizedPersonId: req.user.userId
    });
    
    if (!booking) {
      return res.status(404).json({ message: 'Service not found or you are not authorized' });
    }
    
    res.json({
      stage: booking.trackingStage || 'Pending',
      status: booking.status,
      workSteps: booking.workSteps || [],
      attachments: booking.attachments || [],
      stageTimes: booking.stageTimes || {},
      eta: booking.eta,
      providerLat: booking.providerLat,
      providerLng: booking.providerLng,
      lastUpdate: booking.updatedAt
    });
  } catch (error) {
    console.error('Get tracking error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.get('/chat/:serviceId', async (req, res) => {
  try {
    const ChatMessage = require('../models/ChatMessage');
    const messages = await ChatMessage.find({
      serviceId: req.params.serviceId,
      $or: [
        { senderId: req.user.userId },
        { receiverId: req.user.userId }
      ]
    }).sort({ timestamp: 1 });
    
    res.json(messages);
  } catch (error) {
    console.error('Get chat messages error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.get('/notifications', async (req, res) => {
  try {
    const Notification = require('../models/Notification');
    const notifications = await Notification.find({ userId: req.user.userId })
      .sort({ createdAt: -1 });
    res.json(notifications);
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.put('/notifications/:id/read', async (req, res) => {
  try {
    const Notification = require('../models/Notification');
    await Notification.findByIdAndUpdate(req.params.id, { isRead: true });
    res.json({ message: 'Marked as read' });
  } catch (error) {
    console.error('Mark notification read error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.post('/chat/:serviceId', async (req, res) => {
  try {
    const { message } = req.body;
    
    if (!message) {
      return res.status(400).json({ message: 'Message is required' });
    }
    
    const booking = await Booking.findById(req.params.serviceId);
    if (!booking) {
      return res.status(404).json({ message: 'Service not found' });
    }
    
    const ChatMessage = require('../models/ChatMessage');
    const newMessage = new ChatMessage({
      serviceId: req.params.serviceId,
      conversationId: `${req.params.serviceId}_${req.user.userId}`,
      senderId: req.user.userId,
      receiverId: booking.providerId,
      message: message,
      timestamp: new Date()
    });
    
    await newMessage.save();
    res.status(201).json(newMessage);
  } catch (error) {
    console.error('Send chat message error:', error);
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;