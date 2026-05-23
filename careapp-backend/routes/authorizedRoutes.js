const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const User = require('../models/User');
const Account = require('../models/Account');
const Booking = require('../models/Booking');
const AuthorizedPerson = require('../models/AuthorizedPerson');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Ensure upload directory exists
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

// All routes require authentication
router.use(authMiddleware);

// ==================== PROFILE ====================
router.get('/profile', async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select('-passwordHash');
    if (!user) return res.status(404).json({ message: 'User not found' });
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
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json(user);
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.post('/profile/picture', upload.single('profilePicture'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'No file uploaded' });
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
    if (!user) return res.status(404).json({ message: 'User not found' });
    const isValid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isValid) return res.status(401).json({ message: 'Current password is incorrect' });
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    user.passwordHash = hashedPassword;
    await user.save();
    await Account.findOneAndUpdate({ email: user.email }, { password: hashedPassword });
    res.json({ message: 'Password changed successfully' });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ message: error.message });
  }
});

// ==================== SERVICES (ACTIVE BOOKINGS FOR AUTHORIZED PERSON) ====================
router.get('/services', async (req, res) => {
  try {
    const authorizedPersonId = req.user.userId;
    // Find all clients that have authorized this person
    const authorizedPersons = await AuthorizedPerson.find({ userId: authorizedPersonId }).populate('id_U_CL', 'fullName');
    if (!authorizedPersons.length) {
      return res.json([]);
    }
    const clientIds = authorizedPersons.map(ap => ap.id_U_CL._id);
    // Find active bookings for those clients
    const bookings = await Booking.find({
      clientId: { $in: clientIds },
      status: { $in: ['Confirmed', 'In Progress', 'Pending'] }
    })
      .populate('providerId', 'fullName phoneNumber profilePicture')
      .populate('serviceId', 'name')
      .sort({ createdAt: -1 });
    const services = bookings.map(booking => ({
      id: booking._id,
      service: booking.serviceId?.name || booking.service || 'Service',
      provider: booking.providerId?.fullName || 'Unknown',
      providerId: booking.providerId?._id,
      providerAvatar: booking.providerId?.profilePicture,
      clientName: booking.clientId?.fullName || 'Client',
      date: booking.date,
      time: booking.startTime,
      status: booking.status,
      trackingStage: booking.trackingStage || 'Pending'
    }));
    res.json(services);
  } catch (error) {
    console.error('Get authorized services error:', error);
    res.status(500).json({ message: error.message });
  }
});

// ==================== TRACKING INFO FOR A SPECIFIC SERVICE ====================
router.get('/tracking/:serviceId', async (req, res) => {
  try {
    const { serviceId } = req.params;
    const authorizedPersonId = req.user.userId;
    const booking = await Booking.findById(serviceId);
    if (!booking) {
      return res.status(404).json({ message: 'Service not found' });
    }
    // Verify authorization: does this authorized person have permission to track this client's service?
    const isAuthorized = await AuthorizedPerson.exists({
      userId: authorizedPersonId,
      id_U_CL: booking.clientId,
      canTrack: true
    });
    if (!isAuthorized) {
      return res.status(403).json({ message: 'You are not authorized to track this service' });
    }
    // Return tracking details
      res.json({
      stage: booking.trackingStage || 'Pending',
      status: booking.status,
      workSteps: booking.workSteps || [],
      attachments: booking.attachments || [],
      stageTimes: normalizeStageTimes(booking.stageTimes), // تطبيع
      eta: booking.eta,
      providerLat: booking.providerLat,
      providerLng: booking.providerLng,
      lastUpdate: booking.updatedAt,
      clientTasks: booking.clientTasks || []
    });
  } catch (error) {
    console.error('Get tracking info error:', error);
    res.status(500).json({ message: error.message });
  }
});
function normalizeStageTimes(stageTimes) {
  if (!stageTimes) return {};
  if (Array.isArray(stageTimes)) {
    const stageNames = [
      "Request Accepted", "Provider On The Way", "Provider Arrived",
      "Service Started", "In Progress", "Almost Done", "Completed"
    ];
    const obj = {};
    for (let i = 0; i < stageTimes.length && i < stageNames.length; i++) {
      obj[stageNames[i]] = stageTimes[i];
    }
    return obj;
  }
  if (typeof stageTimes === 'object') {
    const obj = {};
    for (const [key, value] of Object.entries(stageTimes)) {
      if (!key.startsWith('_')) { // تجاهل _id وغيره
        obj[String(key)] = value;
      }
    }
    return obj;
  }
  return {};
}
// ==================== CHAT MESSAGES ====================
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

router.post('/chat/:serviceId', async (req, res) => {
  try {
    const { message } = req.body;
    if (!message) return res.status(400).json({ message: 'Message is required' });
    const booking = await Booking.findById(req.params.serviceId);
    if (!booking) return res.status(404).json({ message: 'Service not found' });
    // Check authorization
    const isAuthorized = await AuthorizedPerson.exists({
      userId: req.user.userId,
      id_U_CL: booking.clientId,
      canChat: true
    });
    if (!isAuthorized) return res.status(403).json({ message: 'Not authorized to chat for this service' });
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

// ==================== NOTIFICATIONS ====================
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

// ==================== PROVIDER PROFILE (FOR AUTHORIZED PERSON TO VIEW) ====================
router.get('/provider/:providerId', async (req, res) => {
  try {
    const { providerId } = req.params;
    const provider = await User.findById(providerId)
      .select('fullName phoneNumber profilePicture address wilaya');
    if (!provider) return res.status(404).json({ message: 'Provider not found' });
    const ServiceProvider = require('../models/ServiceProvider');
    const providerDetails = await ServiceProvider.findOne({ userid: providerId })
      .select('bio hourlyRate yearsOfExperience averageRating totalServices');
    res.json({
      ...provider.toObject(),
      providerDetails: providerDetails || {}
    });
  } catch (error) {
    console.error('Get provider profile error:', error);
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;