const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const User = require('../models/User');
const Account = require('../models/Account');
const Dependent = require('../models/Dependent');
const AuthorizedPerson = require('../models/AuthorizedPerson');
const Booking = require('../models/Booking');
const Service = require('../models/Service');
const Notification = require('../models/Notification');
const Report = require('../models/Report');
const BookingRequest = require('../models/BookingRequest');
const Payment = require('../models/Payment');
const ServiceProvider = require('../models/ServiceProvider');
const Feedback = require('../models/Feedback');
const clientController = require('../controllers/clientController');

const multer = require('multer');
const path = require('path');
const fs = require('fs');
const nodemailer = require('nodemailer');

// ==================== دوال مساعدة لتطبيع البيانات ====================
function normalizeArray(field) {
  if (Array.isArray(field)) return field;
  if (typeof field === 'string') {
    try {
      const parsed = JSON.parse(field);
      return Array.isArray(parsed) ? parsed : [];
    } catch(e) { return []; }
  }
  return [];
}

function normalizeObject(field) {
  if (field && typeof field === 'object' && !Array.isArray(field)) return field;
  if (typeof field === 'string') {
    try {
      const parsed = JSON.parse(field);
      return (parsed && typeof parsed === 'object') ? parsed : {};
    } catch(e) { return {}; }
  }
  return {};
}

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
      if (!key.startsWith('_')) {
        obj[key.toString()] = value;
      }
    }
    return obj;
  }
  return {};
}

async function sendEmail(to, subject, text) {
  try {
    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 587,
      secure: false,
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
    });
    const info = await transporter.sendMail({
      from: `"CareApp Support" <${process.env.EMAIL_USER}>`,
      to: to,
      subject: subject,
      text: text,
    });
    console.log(`Email sent to ${to}: ${info.messageId}`);
  } catch (error) {
    console.error(`Failed to send email to ${to}:`, error.message);
  }
}

const dependentStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = 'uploads/dependents';
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'dependent-' + uniqueSuffix + path.extname(file.originalname));
  }
});
const uploadDependentFiles = multer({ storage: dependentStorage }).array('files', 10);

const bookingRequestsStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = 'uploads/booking-requests';
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'booking-file-' + uniqueSuffix + path.extname(file.originalname));
  }
});
const uploadBookingFiles = multer({ storage: bookingRequestsStorage });

router.use(authMiddleware);

router.get('/profile', async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select('-passwordHash');
    if (!user) return res.status(404).json({ message: 'User not found' });
    const account = await Account.findOne({ email: user.email });
    res.json({ ...user.toObject(), accountStatus: account?.status || 'active', nbReceiving: account?.nb_receiving || 0 });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/profile/:userId', authMiddleware, async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId).select('-passwordHash');
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json({
      fullName: user.fullName,
      email: user.email,
      phoneNumber: user.phoneNumber,
      address: user.address,
      wilaya: user.wilaya,
      profilePicture: user.profilePicture,
      createdAt: user.createdAt,
      role: user.role
    });
  } catch (error) {
    console.error('Error fetching user profile by ID:', error);
    res.status(500).json({ message: error.message });
  }
});

router.put('/profile', async (req, res) => {
  try {
    const { fullName, phoneNumber, address, wilaya, postalCode } = req.body;
    const user = await User.findByIdAndUpdate(req.user.userId, { fullName, phoneNumber, address, wilaya, postalCode }, { new: true }).select('-passwordHash');
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/stats', async (req, res) => {
  try {
    const activeBookings = await Booking.countDocuments({ clientId: req.user.userId, status: { $in: ['Pending', 'In Progress'] } });
    const completedServices = await Booking.countDocuments({ clientId: req.user.userId, status: 'Completed' });
    const totalDependants = await Dependent.countDocuments({ clientId: req.user.userId });
    res.json({ activeBookings, completedServices, totalDependants });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/dependents', async (req, res) => {
  try {
    const dependents = await Dependent.find({ clientId: req.user.userId });
    res.json(dependents);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/dependents', authMiddleware, uploadDependentFiles, clientController.addDependent);
router.put('/dependents/:id', authMiddleware, uploadDependentFiles, clientController.updateDependent);
router.delete('/dependents/:id', authMiddleware, clientController.deleteDependent);
router.get('/dependents/:id', authMiddleware, clientController.getDependentById);
router.get('/dependents/:id/files', authMiddleware, clientController.getDependentFiles);
router.delete('/dependents/:dependentId/files/:fileId', authMiddleware, clientController.deleteDependentFile);
router.post('/dependents/:dependentId/medical-info', authMiddleware, clientController.saveMedicalInfo);
router.get('/dependents/:dependentId/medical-info', authMiddleware, clientController.getMedicalInfo);

router.get('/authorized', async (req, res) => {
  try {
    const persons = await AuthorizedPerson.find({ id_U_CL: req.user.userId }).populate('userId', 'fullName email phoneNumber');
    res.json(persons);
  } catch (error) {
    console.error('Error fetching authorized persons:', error);
    res.status(500).json({ message: error.message });
  }
});

router.post('/authorized', async (req, res) => {
  try {
    let { email, fullName, phoneNumber, relationship, password, canTrack, canChat, canViewLocation } = req.body;
    const bcrypt = require('bcryptjs');
    email = email.toLowerCase().trim();
    if (!email || !fullName || !password) {
      return res.status(400).json({ message: 'Email, full name and password are required' });
    }
    if (password.length < 4) {
      return res.status(400).json({ message: 'Password must be at least 4 characters' });
    }
    const hashedPassword = await bcrypt.hash(password, 10);
    let account = await Account.findOne({ email });
    if (!account) {
      account = new Account({ email: email, password: hashedPassword, status: 'active', nb_receiving: 0, created_at: new Date(), updated_at: new Date() });
      await account.save();
      console.log(`Account created for ${email}`);
    } else {
      account.password = hashedPassword;
      account.updated_at = new Date();
      await account.save();
      console.log(`Account updated for ${email}`);
    }
    let user = await User.findOne({ email });
    if (!user) {
      user = new User({ fullName: fullName, email: email, passwordHash: hashedPassword, accountEmail: email, phoneNumber: phoneNumber || '', role: 'AuthorizedPerson', isActive: true, isVerified: true });
      await user.save();
      console.log(`User created for ${email}`);
    } else {
      user.fullName = fullName;
      user.passwordHash = hashedPassword;
      user.phoneNumber = phoneNumber || '';
      await user.save();
      console.log(`User updated for ${email}`);
    }
    let authorized = await AuthorizedPerson.findOne({ email });
    if (!authorized) {
      authorized = new AuthorizedPerson({ name: fullName, phone_number: phoneNumber || '', national_id: '', id_U_CL: req.user.userId, email: email, relationship: relationship || '', canTrack: canTrack ?? true, canChat: canChat ?? true, canViewLocation: canViewLocation ?? true, userId: user._id });
      await authorized.save();
      console.log(`AuthorizedPerson created for ${email}`);
    } else {
      authorized.name = fullName;
      authorized.phone_number = phoneNumber || '';
      authorized.relationship = relationship || '';
      authorized.canTrack = canTrack ?? true;
      authorized.canChat = canChat ?? true;
      authorized.canViewLocation = canViewLocation ?? true;
      await authorized.save();
      console.log(`AuthorizedPerson updated for ${email}`);
    }
    const client = await User.findById(req.user.userId);
    const clientName = client ? client.fullName : 'A client';
    const emailSubject = 'You have been added as an Authorized Person on CareApp';
    const emailText = `Dear ${fullName},\n\nYou have been added as an authorized person by ${clientName}.\n\nYour login credentials are:\nEmail: ${email}\nPassword: ${password}\n\nPlease login to the CareApp to track services, chat, and manage appointments.\n\nBest regards,\nCareApp Team`;
    await sendEmail(email, emailSubject, emailText);
    res.status(201).json({ message: 'Authorized person added successfully', authorized });
  } catch (error) {
    console.error('Error adding authorized person:', error);
    res.status(500).json({ message: error.message });
  }
});

router.delete('/authorized/:id', async (req, res) => {
  try {
    const authorized = await AuthorizedPerson.findOneAndDelete({ _id: req.params.id, id_U_CL: req.user.userId });
    if (!authorized) return res.status(404).json({ message: 'Authorized person not found' });
    res.json({ message: 'Deleted' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/providers', async (req, res) => {
  try {
    const { service, location, name } = req.query;
    const query = { role: 'Provider', isActive: true, isVerified: true };
    if (service) {
      const serviceDoc = await Service.findOne({ name: service });
      if (serviceDoc) query['serviceId'] = serviceDoc._id;
    }
    if (location) query.wilaya = location;
    if (name) query.fullName = { $regex: name, $options: 'i' };
    const providers = await User.find(query).select('-passwordHash').limit(50);
    res.json(providers);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/providers/:id', async (req, res) => {
  try {
    const provider = await User.findById(req.params.id).select('-passwordHash');
    if (!provider) return res.status(404).json({ message: 'Provider not found' });
    res.json(provider);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/availability/:providerId', clientController.getProviderAvailability);

router.get('/bookings', async (req, res) => {
  try {
    const { status } = req.query;
    const query = { clientId: req.user.userId };
    if (status && status !== 'All') query.status = status;
    const bookings = await Booking.find(query).populate('providerId', 'fullName phoneNumber profilePicture').populate('serviceId', 'name price').sort({ createdAt: -1 });
    res.json(bookings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/bookings/:id', async (req, res) => {
  try {
    const booking = await Booking.findOne({ _id: req.params.id, clientId: req.user.userId })
      .populate('providerId', 'fullName phoneNumber profilePicture')
      .populate('serviceId', 'name price')
      .populate('dependentId');
    if (!booking) return res.status(404).json({ message: 'Booking not found' });

    res.json({
      id: booking._id,
      provider: booking.providerId?.fullName,
      providerId: booking.providerId?._id,
      providerPhone: booking.providerId?.phoneNumber,
      providerAvatar: booking.providerId?.profilePicture,
      service: booking.serviceId?.name,
      serviceId: booking.serviceId?._id,
      date: booking.date,
      time: booking.startTime,
      startTime: booking.startTime,
      endTime: booking.endTime,
      status: booking.status,
      location: booking.location,
      notes: booking.notes,
      totalPrice: booking.totalPrice,
      halfPaid: booking.halfPaid || false,
      halfAmount: booking.halfAmount || 0,
      remainingAmount: booking.remainingAmount || 0,
      paymentStatus: booking.paymentStatus,
      paymentMethod: booking.paymentMethod,
      dependentId: booking.dependentId,
      clientTasks: normalizeArray(booking.clientTasks),
      trackingStage: booking.trackingStage,
      stageTimes: normalizeObject(booking.stageTimes),
      rating: booking.rating,
      feedback: booking.feedback
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/bookings', async (req, res) => {
  try {
    const { providerId, serviceId, date, time, location, notes, dependentId } = req.body;
    const provider = await User.findById(providerId);
    if (!provider) return res.status(404).json({ message: 'Provider not found' });
    const service = await Service.findById(serviceId);
    if (!service) return res.status(404).json({ message: 'Service not found' });
    const client = await User.findById(req.user.userId);
    const endTime = (() => {
      try {
        const [t, mod] = time.split(' ');
        let [h, m] = t.split(':');
        let hour = parseInt(h);
        if (mod === 'PM' && hour !== 12) hour += 12;
        if (mod === 'AM' && hour === 12) hour = 0;
        hour += 2;
        let newMod = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour === 0) { hour = 12; newMod = 'AM'; }
        return `${hour}:${m} ${newMod}`;
      } catch(e) { return '06:00 PM'; }
    })();
    const booking = new Booking({
      client: client.fullName, clientId: req.user.userId, clientPhone: client.phoneNumber,
      provider: provider.fullName, providerId, providerPhone: provider.phoneNumber,
      service: service.name, serviceId,
      date: new Date(date), startTime: time, endTime,
      location: location || client.address || 'Not specified', notes: notes || '', dependentId: dependentId || null,
      status: 'Pending', totalPrice: service.price, paymentStatus: 'Pending'
    });
    await booking.save();
    await Notification.create({ userId: providerId, title: 'New Booking Request', message: `${client.fullName} requested ${service.name} on ${date} at ${time}`, type: 'booking' });
    res.status(201).json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/bookings/:id/cancel', async (req, res) => {
  try {
    const booking = await Booking.findOneAndUpdate({ _id: req.params.id, clientId: req.user.userId }, { status: 'Cancelled' }, { new: true });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    res.json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/booking-requests', authMiddleware, uploadBookingFiles.array('files'), clientController.createBookingRequest);
router.get('/booking-requests', async (req, res) => {
  try {
    const requests = await BookingRequest.find({ clientId: req.user.userId }).sort({ createdAt: -1 });
    res.json(requests);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/tracking/:bookingId', async (req, res) => {
  try {
    const booking = await Booking.findOne({ _id: req.params.bookingId, clientId: req.user.userId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });

    res.json({
      stage: booking.trackingStage || 'Pending',
      status: booking.status,
      workSteps: normalizeArray(booking.workSteps),
      attachments: normalizeArray(booking.attachments),
      stageTimes: normalizeObject(booking.stageTimes),
      eta: booking.eta,
      providerLat: booking.providerLat,
      providerLng: booking.providerLng,
      lastUpdate: booking.updatedAt,
      clientTasks: normalizeArray(booking.clientTasks)
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/payments', async (req, res) => {
  try {
    const { bookingId, amount, paymentMethod } = req.body;
    const booking = await Booking.findOne({ _id: bookingId, clientId: req.user.userId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    booking.paymentStatus = 'Completed';
    booking.paymentMethod = paymentMethod;
    booking.paidAt = new Date();
    await booking.save();
    res.status(201).json({ message: 'Payment completed successfully', booking: { id: booking._id, paymentStatus: booking.paymentStatus, paymentMethod: booking.paymentMethod, paidAt: booking.paidAt } });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/payments/pending', async (req, res) => {
  try {
    const bookings = await Booking.find({ clientId: req.user.userId, status: 'Confirmed', halfPaid: false }).populate('providerId', 'fullName phoneNumber profilePicture').populate('serviceId', 'name');
    const pending = [];
    for (const booking of bookings) {
      const providerDetails = await ServiceProvider.findOne({ userid: booking.providerId });
      pending.push({
        _id: booking._id,
        bookingId: booking._id,
        service: booking.serviceId?.name || booking.service,
        provider: booking.providerId?.fullName,
        amount: booking.totalPrice,
        dueDate: booking.date,
        providerBank: {
          ccp: providerDetails?.ccp || '',
          bankName: providerDetails?.bankAccount?.bankName || '',
          accountNumber: providerDetails?.bankAccount?.accountNumber || '',
          accountHolder: providerDetails?.bankAccount?.accountHolder || '',
          rib: providerDetails?.bankAccount?.rib || ''
        }
      });
    }
    res.json(pending);
  } catch (error) {
    console.error('Get pending payments error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.put('/bookings/:id/pay-half', async (req, res) => {
  try {
    const { id } = req.params;
    const { paymentMethod, clientPaymentDetails } = req.body;
    const booking = await Booking.findOne({ _id: id, clientId: req.user.userId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    if (booking.paymentStatus === 'Completed') return res.status(400).json({ message: 'Already fully paid' });
    if (booking.halfPaid) return res.status(400).json({ message: 'Half payment already made' });
    const halfAmount = booking.totalPrice / 2;
    const payment = new Payment({ bookingId: booking._id, amount: halfAmount, status: 'half_paid', payment_method: paymentMethod, clientPaymentInfo: clientPaymentDetails || {} });
    await payment.save();
    booking.halfPaid = true;
    booking.halfAmount = halfAmount;
    booking.remainingAmount = booking.totalPrice - halfAmount;
    booking.paymentStatus = 'HalfPaid';
    booking.paymentMethod = paymentMethod;
    booking.trackingStage = 'Accepted';
    booking.stageTimes = booking.stageTimes || {};
    booking.stageTimes['Accepted'] = new Date().toISOString();
    await booking.save();
    await Notification.create({ userId: booking.providerId, title: 'Half Payment Received', message: `Client paid half (${halfAmount} DZD). Tracking has started.`, type: 'payment', bookingId: booking._id });
    await Notification.create({ userId: booking.clientId, title: 'Tracking Started', message: 'Your service tracking has started. You can now see live updates from the provider.', type: 'tracking', bookingId: booking._id });
    res.json({ message: 'Half payment successful. Tracking started.', halfAmount, remainingAmount: booking.remainingAmount, trackingStage: booking.trackingStage, stageTimes: booking.stageTimes });
  } catch (error) {
    console.error('Half payment error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.post('/bookings/:id/pay-remaining', async (req, res) => {
  try {
    const { id } = req.params;
    const clientId = req.user.userId;
    let booking = await Booking.findOne({ _id: id, clientId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    if (booking.paymentStatus === 'Completed' && booking.remainingAmount > 0) {
      console.log('Inconsistent data: fixing paymentStatus to HalfPaid');
      booking.paymentStatus = 'HalfPaid';
      await booking.save();
    }
    if (booking.status !== 'Completed') return res.status(400).json({ message: 'Service not yet completed' });
    if (booking.paymentStatus === 'Completed') return res.status(400).json({ message: 'Already fully paid' });
    const remainingAmount = booking.remainingAmount || 0;
    if (remainingAmount <= 0) return res.status(400).json({ message: 'No remaining amount to pay' });
    booking.paymentStatus = 'Completed';
    booking.paidAt = new Date();
    await booking.save();
    await Notification.create({ userId: booking.providerId, title: 'Remaining Payment Received', message: `Client completed payment of ${remainingAmount} DZD.`, type: 'payment', bookingId: booking._id });
    const io = req.app.get('io');
    if (io) io.to(`tracking_${booking._id}`).emit('trackingUpdate', { bookingId: booking._id, paymentStatus: 'Completed', remainingAmount: 0, stage: booking.trackingStage });
    res.json({ success: true, message: 'Payment successful', remainingAmount });
  } catch (error) {
    console.error('Pay remaining error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.post('/bookings/:id/rate-provider', clientController.rateProvider);

router.post('/bookings/:id/tasks', async (req, res) => {
  try {
    const { id } = req.params;
    const { tasks } = req.body;
    const booking = await Booking.findOne({ _id: id, clientId: req.user.userId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    const existingTasks = booking.clientTasks || [];
    const newTasks = tasks.map(t => ({ taskName: t.taskName, status: 'pending' }));
    booking.clientTasks = [...existingTasks, ...newTasks];
    booking.clientTasksSubmittedAt = new Date();
    await booking.save();
    res.json({ message: 'Tasks added successfully', tasks: booking.clientTasks });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});
// ==================== CHAT MESSAGES ====================
// جلب رسائل حجز معين
router.get('/bookings/:bookingId/messages', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const clientId = req.user.userId;

    const booking = await Booking.findOne({ _id: bookingId, clientId }).select('messages');
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // تطبيع الرسائل (تأكد من أنها مصفوفة)
    const messages = Array.isArray(booking.messages) ? booking.messages : [];
    res.json(messages);
  } catch (error) {
    console.error('Error fetching messages:', error);
    res.status(500).json({ message: error.message });
  }
});

// إرسال رسالة جديدة (يحفظها تلقائياً في الحجز)
router.post('/bookings/:bookingId/messages', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const clientId = req.user.userId;
    const { message } = req.body;

    if (!message || message.trim() === '') {
      return res.status(400).json({ message: 'Message cannot be empty' });
    }

    const booking = await Booking.findOne({ _id: bookingId, clientId });
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    // جلب اسم العميل (يمكن تخزينه مع الرسالة)
    const clientUser = await User.findById(clientId).select('fullName');
    const senderName = clientUser?.fullName || 'Client';

    // إنشاء الرسالة
    const newMessage = {
      senderId: clientId,
      senderName: senderName,
      message: message.trim(),
      timestamp: new Date(),
      isRead: false
    };

    // إضافة الرسالة إلى مصفوفة messages
    if (!booking.messages) booking.messages = [];
    booking.messages.push(newMessage);
    await booking.save();

    // إعلام المزود عبر Socket.io (إذا كان متصلاً)
    const io = req.app.get('io');
    if (io) {
      io.to(`booking_${bookingId}`).emit('newBookingMessage', {
        bookingId,
        message: newMessage
      });
    }

    // إشعار للمزود (اختياري)
    await Notification.create({
      userId: booking.providerId,
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

router.post('/feedback', async (req, res) => {
  try {
    const { bookingId, rating, comment } = req.body;
    const clientId = req.user.userId;
    const booking = await Booking.findOne({ _id: bookingId, clientId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    if (booking.status !== 'Completed') return res.status(400).json({ message: 'Service not completed yet' });
    if (booking.rating) return res.status(400).json({ message: 'Already rated this booking' });
    const feedback = new Feedback({ overall_rating: rating, comment: comment || '', bookingId: booking._id, clientId: booking.clientId, providerId: booking.providerId });
    await feedback.save();
    booking.rating = rating;
    booking.feedback = comment || '';
    await booking.save();
    const allRatings = await Booking.find({ providerId: booking.providerId, rating: { $exists: true } });
    const avgRating = allRatings.length > 0 ? allRatings.reduce((sum, b) => sum + b.rating, 0) / allRatings.length : rating;
    await ServiceProvider.findOneAndUpdate({ userid: booking.providerId }, { averageRating: avgRating, totalReviews: allRatings.length });
    await Notification.create({ userId: booking.providerId, title: 'New Feedback', message: `Client gave you ${rating} stars: ${comment || ''}`, type: 'review', bookingId: booking._id });
    res.status(201).json({ message: 'Feedback submitted successfully', feedback });
  } catch (error) {
    console.error('Feedback error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.get('/feedback', async (req, res) => {
  try {
    const clientId = req.user.userId;
    const feedbacks = await Feedback.find({ clientId }).populate('bookingId', 'service provider date').sort({ createdAt: -1 });
    const formatted = feedbacks.map(f => ({ id: f._id, bookingId: f.bookingId?._id, service: f.bookingId?.service || 'Service', provider: f.bookingId?.provider || 'Provider', rating: f.overall_rating, comment: f.comment, reply: f.reply, createdAt: f.createdAt }));
    res.json(formatted);
  } catch (error) {
    console.error('Get feedback error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.post('/complaints', async (req, res) => {
  try {
    const report = new Report({ sender: req.user.userId, reason: req.body.title, description: req.body.description, status: 'Pending' });
    await report.save();
    res.status(201).json(report);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/complaints', async (req, res) => {
  try {
    const reports = await Report.find({ sender: req.user.userId });
    res.json(reports);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/notifications', async (req, res) => {
  try {
    const notifications = await Notification.find({ userId: req.user.userId }).sort({ createdAt: -1 });
    res.json(notifications);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/notifications/:id/read', async (req, res) => {
  try {
    await Notification.findByIdAndUpdate(req.params.id, { isRead: true });
    res.json({ message: 'Marked as read' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/history', async (req, res) => {
  try {
    const bookings = await Booking.find({ clientId: req.user.userId, status: 'Completed' }).populate('providerId', 'fullName').populate('serviceId', 'name price').populate('dependentId', 'fullName').sort({ createdAt: -1 });
    res.json(bookings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;