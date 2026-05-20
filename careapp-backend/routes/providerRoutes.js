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
const multer = require('multer');
const path = require('path');
const fs = require('fs');

router.use(authMiddleware);

// ========== إعداد مجلدات رفع الملفات ==========
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

// ========== Routes existantes ==========
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
router.get('/reviews', providerController.getReviews);
router.post('/reviews/:id/reply', providerController.replyToReview);
router.post('/complaints', providerController.fileComplaint);
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

// ========== تحديث حالة مهمة العميل ==========
router.put('/bookings/:bookingId/tasks/:taskIndex', providerController.updateClientTaskStatus);

// ========== إضافة خطوة عمل مع إمكانية رفع ملف ==========
router.post('/work-steps-with-file', uploadWorkStep, providerController.addWorkStepWithFile);

// ========== رفع مرفق (صورة/فيديو) مع وصف ==========
router.post('/attachments/upload', uploadAttachment, providerController.uploadAttachment);

// ========== تحديث الموقع الجغرافي ==========
router.post('/tracking/location', providerController.updateLocation);

// ========== تقييم العميل من قبل المزود ==========
router.post('/bookings/:id/rate-client', providerController.rateClient);

// ========== Get booking requests ==========
router.get('/booking-requests', async (req, res) => {
  try {
    const requests = await BookingRequest.find({ providerId: req.user.userId }).sort({ createdAt: -1 });
    const formatted = await Promise.all(requests.map(async (reqDoc) => {
      let client = null;
      if (reqDoc.clientId) {
        client = await User.findById(reqDoc.clientId).select('fullName email phoneNumber address wilaya').lean();
      }
      let dependent = null;
      const dependentId = reqDoc.dependantId || reqDoc.dependentId;
      if (dependentId) {
        const dep = await Dependent.findById(dependentId).lean();
        if (dep) {
          dependent = {
            name: dep.fullName,
            relationship: dep.relationship,
            age: dep.dateOfBirth ? new Date().getFullYear() - new Date(dep.dateOfBirth).getFullYear() : null,
            healthNotes: dep.healthNotes || '',
            files: dep.files || []
          };
        }
      }
      return {
        id: reqDoc._id,
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
        dependent: dependent
      };
    }));
    res.json(formatted);
  } catch (error) {
    console.error('Error fetching booking requests:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// ========== قبول طلب الحجز ==========
router.put('/booking-requests/:id/accept', async (req, res) => {
  try {
    const { id } = req.params;
    const request = await BookingRequest.findOne({ _id: id, providerId: req.user.userId, status: 'pending' });
    if (!request) return res.status(404).json({ message: 'Request not found' });

    request.status = 'accepted';
    request.respondedAt = new Date();
    await request.save();

    const client = await User.findById(request.clientId);
    const provider = await User.findById(request.providerId);
    const providerDetails = await ServiceProvider.findOne({ userid: request.providerId });
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
      provider: provider.fullName,
      providerId: request.providerId,
      providerPhone: provider.phoneNumber,
      service: request.serviceName,
      date: new Date(request.date),
      startTime: request.startTime,
      endTime: request.endTime,
      location: request.location,
      notes: request.notes,
      dependentId: request.dependantId || request.dependentId,
      status: 'Confirmed',
      totalPrice: totalPrice,
      paymentStatus: 'Pending',
      clientTasks: request.tasks ? request.tasks.map(t => ({ taskName: t.taskName, status: 'pending' })) : []
    });
    await booking.save();

    await Notification.create({
      userId: request.clientId,
      title: 'Booking Accepted',
      message: `${provider.fullName} has accepted your booking request. Please complete half payment to start tracking.`,
      type: 'booking',
      bookingId: booking._id
    });

    res.json({ message: 'Booking request accepted', bookingId: booking._id, totalPrice: totalPrice, halfAmount: totalPrice / 2 });
  } catch (error) {
    console.error('Accept booking error:', error);
    res.status(500).json({ message: error.message });
  }
});

// ========== رفض طلب الحجز ==========
router.put('/booking-requests/:id/reject', async (req, res) => {
  try {
    const { id } = req.params;
    const request = await BookingRequest.findOne({ _id: id, providerId: req.user.userId, status: 'pending' });
    if (!request) return res.status(404).json({ message: 'Request not found' });

    request.status = 'rejected';
    request.respondedAt = new Date();
    await request.save();

    const provider = await User.findById(req.user.userId);
    await Notification.create({
      userId: request.clientId,
      title: 'Booking Rejected',
      message: `${provider.fullName} has rejected your booking request.`,
      type: 'booking'
    });

    res.json({ message: 'Booking request rejected' });
  } catch (error) {
    console.error('Reject booking error:', error);
    res.status(500).json({ message: error.message });
  }
});

// ========== التوفرية ==========
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