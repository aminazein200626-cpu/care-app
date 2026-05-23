const express = require('express');
const router = express.Router();
const providerController = require('../controllers/providerController');
const { authMiddleware } = require('../middleware/auth');
const upload = require('../middleware/upload');
const BookingRequest = require('../models/BookingRequest');
const Booking = require('../models/Booking');
const Notification = require('../models/Notification');
const User = require('../models/User');
const Dependent = require('../models/Dependent');
const ServiceProvider = require('../models/ServiceProvider');
const File = require('../models/File');
const Feedback = require('../models/Feedback');
const DependentFile = require('../models/DependentFile');
const MedicalInfo = require('../models/MedicalInfo');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

router.use(authMiddleware);

// Setup upload directories
const workStepsDir = path.join(__dirname, '../uploads/worksteps');
const attachmentsDir = path.join(__dirname, '../uploads/attachments');
if (!fs.existsSync(workStepsDir)) fs.mkdirSync(workStepsDir, { recursive: true });
if (!fs.existsSync(attachmentsDir)) fs.mkdirSync(attachmentsDir, { recursive: true });

const workStepsStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, workStepsDir),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname)
});
const attachmentStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, attachmentsDir),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname)
});

const uploadWorkStep = multer({ storage: workStepsStorage }).single('file');
const uploadAttachment = multer({ storage: attachmentStorage }).single('file');

// ==================== PROVIDER ROUTES ====================
router.get('/services', providerController.getServices);
router.get('/profile', providerController.getProfile);
router.put('/profile', providerController.updateProfile);
router.put('/profile/professional', providerController.updateProfessionalInfo);
router.post('/profile/picture', upload.single('profilePicture'), providerController.uploadProfilePicture);
router.get('/stats', providerController.getStats);
router.get('/bookings', providerController.getBookings);
router.get('/bookings/:id', providerController.getBookingDetails);
router.put('/bookings/:id/accept', providerController.acceptBooking);
router.put('/bookings/:id/reject', providerController.rejectBooking);
router.get('/tracking/:bookingId', providerController.getTrackingInfo);
router.post('/tracking', providerController.updateTracking);
router.post('/attachments', providerController.addAttachment);
router.post('/work-steps', providerController.addWorkStep);
router.get('/earnings', providerController.getEarnings);
router.get('/payments', providerController.getPaymentHistory);
router.post('/withdraw', providerController.requestWithdrawal);
router.get('/ads', providerController.getMyAds);
router.post('/ads', providerController.createAd);
router.put('/ads/:id/pause', providerController.pauseAd);
router.get('/notifications', providerController.getNotifications);
router.put('/notifications/:id/read', providerController.markNotificationRead);
router.delete('/notifications/:id', providerController.deleteNotification);
router.post('/notifications', providerController.createNotification);
router.get('/withdrawals', providerController.getWithdrawals);
router.get('/calls', providerController.getCallHistory);
router.get('/blocked-users', providerController.getBlockedUsers);
router.post('/block/:userId', providerController.blockUser);
router.delete('/block/:userId', providerController.unblockUser);
router.delete('/account', providerController.deleteAccount);
router.get('/bookings/:id/client-tasks', providerController.getClientTasks);
router.get('/availability', providerController.getAvailability);
router.post('/availability', providerController.addAvailability);
router.delete('/availability', providerController.deleteAvailability);
router.get('/half-payments', providerController.getHalfPayments);
router.put('/bookings/:bookingId/tasks/:taskIndex', providerController.updateClientTaskStatus);
router.post('/work-steps-with-file', uploadWorkStep, providerController.addWorkStepWithFile);
router.post('/attachments/upload', uploadAttachment, providerController.uploadAttachment);
router.post('/tracking/location', providerController.updateLocation);
router.post('/bookings/:id/rate-client', providerController.rateClient);
router.get('/task-files/:taskId', async (req, res) => {
  try {
    const { taskId } = req.params;
    const files = await File.find({ taskId });
    res.json(files);
  } catch (error) {
    console.error('Error fetching task files:', error);
    res.status(500).json({ message: error.message });
  }
});

// ==================== DEPENDENT DETAILS FOR PROVIDER ====================
router.get('/dependents/:dependentId', async (req, res) => {
  try {
    const { dependentId } = req.params;
    const dependent = await Dependent.findById(dependentId);
    if (!dependent) return res.status(404).json({ message: 'Dependent not found' });
    const files = await DependentFile.find({ dependentId: dependent._id });
    const medicalInfo = dependent.medicalInfoId ? await MedicalInfo.findById(dependent.medicalInfoId) : null;
    res.json({ ...dependent.toObject(), files, medicalInfo });
  } catch (error) {
    console.error('Error fetching dependent details:', error);
    res.status(500).json({ message: error.message });
  }
});

// ==================== BOOKING REQUESTS ====================
router.get('/booking-requests', async (req, res) => {
  try {
    const provider = await ServiceProvider.findOne({ userid: req.user.userId });
    if (!provider) return res.json([]);

    const requests = await BookingRequest.find({
      $or: [
        { providerId: req.user.userId },
        { providerId: provider._id }
      ]
    }).sort({ createdAt: -1 });

    const uniqueRequests = [];
    const seenIds = new Set();
    for (const reqDoc of requests) {
      if (!seenIds.has(reqDoc._id.toString())) {
        seenIds.add(reqDoc._id.toString());
        uniqueRequests.push(reqDoc);
      }
    }

    const formatted = await Promise.all(uniqueRequests.map(async (reqDoc) => {
      let client = null;
      if (reqDoc.clientId) {
        client = await User.findById(reqDoc.clientId).select('fullName email phoneNumber address wilaya').lean();
      }
      let dependent = null;
      const dependentId = reqDoc.dependantId || reqDoc.dependentId;
      if (dependentId) {
        const dep = await Dependent.findById(dependentId).lean();
        if (dep) {
          const files = await DependentFile.find({ dependentId: dep._id });
          const medicalInfo = dep.medicalInfoId ? await MedicalInfo.findById(dep.medicalInfoId) : null;
          dependent = {
            name: dep.fullName,
            relationship: dep.relationship,
            age: dep.dateOfBirth ? new Date().getFullYear() - new Date(dep.dateOfBirth).getFullYear() : null,
            healthNotes: dep.healthNotes || '',
            files: files || [],
            medicalInfo: medicalInfo || {}
          };
        }
      }
      return {
        id: reqDoc._id,
        clientId: reqDoc.clientId,
        clientName: client?.fullName || 'Unknown',
        clientEmail: client?.email || 'Not provided',
        clientPhone: client?.phoneNumber || 'Not provided',
        clientAddress: client?.address || 'Not specified',
        clientWilaya: client?.wilaya || 'Not specified',
        serviceName: reqDoc.serviceName,
        date: reqDoc.date,
        startTime: reqDoc.startTime,
        endTime: reqDoc.endTime,
        location: reqDoc.location,
        notes: reqDoc.notes,
        tasks: reqDoc.tasks || [],
        status: reqDoc.status,
        createdAt: reqDoc.createdAt,
        respondedAt: reqDoc.respondedAt,
        dependent,
        taskId: reqDoc.taskId,
        bookingId: reqDoc.bookingId || null   // ✅ إضافة bookingId
      };
    }));

    res.json(formatted);
  } catch (error) {
    console.error('Error fetching booking requests:', error);
    res.status(500).json({ message: error.message });
  }
});

// ==================== ACCEPT BOOKING REQUEST ====================
router.put('/booking-requests/:id/accept', async (req, res) => {
  try {
    const { id } = req.params;
    const request = await BookingRequest.findOne({ _id: id, providerId: req.user.userId, status: 'pending' });
    if (!request) return res.status(404).json({ message: 'Request not found' });

    request.status = 'accepted';
    request.respondedAt = new Date();
    await request.save();

    const client = await User.findById(request.clientId);
    const providerUser = await User.findById(req.user.userId);
    const providerDetails = await ServiceProvider.findOne({ userid: req.user.userId });
    if (!providerDetails) return res.status(400).json({ message: 'Provider details incomplete' });

    const hourlyRate = providerDetails.hourlyRate || 0;
    const startHours = parseTimeToHours(request.startTime);
    const endHours = parseTimeToHours(request.endTime);
    const hours = Math.max(0, endHours - startHours);
    const totalPrice = hourlyRate * hours;

    const booking = new Booking({
      client: client.fullName,
      clientId: request.clientId,
      clientPhone: client.phoneNumber,
      provider: providerUser.fullName,
      providerId: req.user.userId,
      providerPhone: providerUser.phoneNumber,
      service: request.serviceName,
      date: new Date(request.date),
      startTime: request.startTime,
      endTime: request.endTime,
      location: request.location,
      notes: request.notes,
      dependentId: request.dependantId || request.dependentId,
      status: 'Confirmed',
      totalPrice,
      paymentStatus: 'Pending',
      clientTasks: request.tasks ? request.tasks.map(t => ({ taskName: t.taskName, status: 'pending' })) : [],
      taskId: request.taskId
    });
    await booking.save();

    // ✅ ربط bookingId بالطلب
    request.bookingId = booking._id;
    await request.save();

    await Notification.create({
      userId: request.clientId,
      title: 'Booking Accepted',
      message: `${providerUser.fullName} has accepted your booking request. Please complete half payment to start tracking.`,
      type: 'booking',
      bookingId: booking._id
    });

    res.json({ message: 'Booking request accepted', bookingId: booking._id, totalPrice, halfAmount: totalPrice / 2 });
  } catch (error) {
    console.error('Accept booking error:', error);
    res.status(500).json({ message: error.message });
  }
});

// ==================== REJECT BOOKING REQUEST ====================
router.put('/booking-requests/:id/reject', async (req, res) => {
  try {
    const { id } = req.params;
    const request = await BookingRequest.findOne({ _id: id, providerId: req.user.userId, status: 'pending' });
    if (!request) return res.status(404).json({ message: 'Request not found' });

    request.status = 'rejected';
    request.respondedAt = new Date();
    await request.save();

    const providerUser = await User.findById(req.user.userId);
    await Notification.create({
      userId: request.clientId,
      title: 'Booking Rejected',
      message: `${providerUser.fullName} has rejected your booking request.`,
      type: 'booking'
    });

    res.json({ message: 'Booking request rejected' });
  } catch (error) {
    console.error('Reject booking error:', error);
    res.status(500).json({ message: error.message });
  }
});

// ==================== AVAILABILITY ROUTES ====================
router.get('/availability', providerController.getAvailability);
router.post('/availability', providerController.addAvailability);
router.delete('/availability', providerController.deleteAvailability);
router.get('/availability/:providerId', async (req, res) => {
  try {
    const { providerId } = req.params;
    let provider = await ServiceProvider.findOne({ userid: providerId });
    if (!provider) {
      const user = await User.findById(providerId);
      if (user?.email) provider = await ServiceProvider.findOne({ email: user.email });
    }
    if (!provider) return res.json({});
    let availability = {};
    if (provider.availability) {
      if (typeof provider.availability === 'string') {
        try { availability = JSON.parse(provider.availability); } catch(e) { availability = {}; }
      } else {
        availability = provider.availability;
      }
    }
    res.json(availability);
  } catch (error) {
    console.error('Availability error:', error);
    res.status(500).json({ message: error.message });
  }
});
// ==================== CHAT MESSAGES ====================
// جلب رسائل حجز معين (للمزود)
router.get('/bookings/:bookingId/messages', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const providerId = req.user.userId;

    const booking = await Booking.findOne({ _id: bookingId, providerId }).select('messages');
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    const messages = Array.isArray(booking.messages) ? booking.messages : [];
    res.json(messages);
  } catch (error) {
    console.error('Error fetching messages:', error);
    res.status(500).json({ message: error.message });
  }
});

// إرسال رسالة جديدة (للمزود)
router.post('/bookings/:bookingId/messages', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const providerId = req.user.userId;
    const { message } = req.body;

    if (!message || message.trim() === '') {
      return res.status(400).json({ message: 'Message cannot be empty' });
    }

    const booking = await Booking.findOne({ _id: bookingId, providerId });
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // جلب اسم المزود
    const providerUser = await User.findById(providerId).select('fullName');
    const senderName = providerUser?.fullName || 'Provider';

    const newMessage = {
      senderId: providerId,
      senderName: senderName,
      message: message.trim(),
      timestamp: new Date(),
      isRead: false
    };

    if (!booking.messages) booking.messages = [];
    booking.messages.push(newMessage);
    await booking.save();

    // إعلام العميل عبر Socket.io
    const io = req.app.get('io');
    if (io) {
      io.to(`booking_${bookingId}`).emit('newBookingMessage', {
        bookingId,
        message: newMessage
      });
    }

    // إشعار للعميل
    await Notification.create({
      userId: booking.clientId,
      title: 'New Message',
      message: `${senderName}: ${message.substring(0, 50)}${message.length > 50 ? '...' : ''}`,
      type: 'message',
      bookingId: booking._id
    });

    res.status(201).json({ message: 'Message sent', data: newMessage });
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({ message: error.message });
  }
});
// ==================== REVIEWS ====================
router.get('/reviews', async (req, res) => {
  try {
    const providerId = req.user.userId;
    const feedbacks = await Feedback.find({ providerId })
      .populate('clientId', 'fullName')
      .populate('bookingId', 'service date')
      .sort({ createdAt: -1 });
    const formatted = feedbacks.map(f => ({
      id: f._id,
      client: f.clientId?.fullName || 'Unknown',
      rating: f.overall_rating,
      comment: f.comment,
      reply: f.reply,
      date: (f.createdAt ? new Date(f.createdAt) : new Date()).toISOString().split('T')[0],
      service: f.bookingId?.service || 'Service',
      replied: !!f.reply
    }));
    res.json(formatted);
  } catch (error) {
    console.error('Get reviews error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.post('/reviews/:id/reply', async (req, res) => {
  try {
    const { id } = req.params;
    const { reply } = req.body;
    const providerId = req.user.userId;
    if (!reply) return res.status(400).json({ message: 'Reply message is required' });
    const feedback = await Feedback.findById(id);
    if (!feedback) return res.status(404).json({ message: 'Review not found' });
    if (feedback.providerId.toString() !== providerId) {
      return res.status(403).json({ message: 'Unauthorized to reply to this review' });
    }
    feedback.reply = reply;
    feedback.replyAt = new Date();
    await feedback.save();
    if (feedback.bookingId) {
      await Booking.findByIdAndUpdate(feedback.bookingId, { feedbackReply: reply });
    }
    await Notification.create({
      userId: feedback.clientId,
      title: 'Provider Replied to Your Review',
      message: `Provider replied: ${reply}`,
      type: 'review',
      bookingId: feedback.bookingId
    });
    res.json({ message: 'Reply sent to review', reply });
  } catch (error) {
    console.error('Reply to review error:', error);
    res.status(500).json({ message: error.message });
  }
});

// ==================== OTHER ROUTES ====================
router.post('/complaints', providerController.fileComplaint);
router.get('/withdrawals', providerController.getWithdrawals);
router.get('/calls', providerController.getCallHistory);
router.get('/blocked-users', providerController.getBlockedUsers);
router.post('/block/:userId', providerController.blockUser);
router.delete('/block/:userId', providerController.unblockUser);
router.delete('/account', providerController.deleteAccount);

function parseTimeToHours(timeStr) {
  if (!timeStr || typeof timeStr !== 'string') return 0;
  const trimmed = timeStr.trim().toUpperCase();
  const parts = trimmed.match(/(\d+):(\d+)/);
  if (!parts) return 0;
  let hour = parseInt(parts[1]);
  const minute = parseInt(parts[2]);
  if (trimmed.includes('PM') && hour !== 12) hour += 12;
  if (trimmed.includes('AM') && hour === 12) hour = 0;
  return hour + minute / 60;
}

module.exports = router;