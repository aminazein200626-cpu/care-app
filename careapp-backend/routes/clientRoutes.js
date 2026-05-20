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
const clientController = require('../controllers/clientController');

const multer = require('multer');
const path = require('path');
const fs = require('fs');

// إعداد تخزين الملفات للمعالين
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

router.post('/dependents', authMiddleware, (req, res) => {
  uploadDependentFiles(req, res, async (err) => {
    if (err) {
      console.error('Multer error:', err);
      return res.status(400).json({ message: 'File upload error: ' + err.message });
    }

    try {
      const { fullName, relationship, dateOfBirth, nationalId, healthNotes } = req.body;
      
      if (!fullName || !relationship || !dateOfBirth) {
        return res.status(400).json({ message: 'Missing required fields: fullName, relationship, dateOfBirth' });
      }

      const dependentData = {
        clientId: req.user.userId,
        fullName,
        relationship,
        dateOfBirth: new Date(dateOfBirth),
        nationalId: nationalId || '',
        healthNotes: healthNotes || '',
        files: []
      };

      if (req.files && req.files.length > 0) {
        dependentData.files = req.files.map(file => ({
          filename: file.originalname,
          url: `/uploads/dependents/${file.filename}`,
          fileType: path.extname(file.originalname).substring(1),
          uploadedAt: new Date()
        }));
      }

      const dependent = new Dependent(dependentData);
      await dependent.save();

      const Client = require('../models/Client');
      await Client.findOneAndUpdate(
        { userId: req.user.userId },
        { $push: { dependents: dependent._id } }
      );

      res.status(201).json(dependent);
    } catch (error) {
      console.error('Error adding dependent:', error);
      res.status(500).json({ message: error.message });
    }
  });
});

router.put('/dependents/:id', async (req, res) => {
  try {
    const dependent = await Dependent.findOneAndUpdate({ _id: req.params.id, clientId: req.user.userId }, req.body, { new: true });
    if (!dependent) return res.status(404).json({ message: 'Dependent not found' });
    res.json(dependent);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.delete('/dependents/:id', async (req, res) => {
  try {
    const dependent = await Dependent.findOneAndDelete({ _id: req.params.id, clientId: req.user.userId });
    if (!dependent) return res.status(404).json({ message: 'Dependent not found' });
    res.json({ message: 'Deleted' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/authorized', async (req, res) => {
  try {
    const persons = await AuthorizedPerson.find({ clientId: req.user.userId }).populate('userId', 'fullName email phoneNumber');
    res.json(persons);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/authorized', async (req, res) => {
  try {
    const { email, fullName, phoneNumber, relationship, password, canTrack, canChat, canViewLocation } = req.body;
    let user = await User.findOne({ email });
    const bcrypt = require('bcryptjs');
    if (!user) {
      if (!password || password.length < 4) return res.status(400).json({ message: 'Password must be at least 4 characters' });
      const account = new Account({ email, psw: await bcrypt.hash(password, 10), status: 'active', nb_receiving: 0 });
      await account.save();
      user = new User({ fullName, email, passwordHash: await bcrypt.hash(password, 10), accountEmail: email, phoneNumber, role: 'AuthorizedPerson', isActive: true, isVerified: true });
      await user.save();
    } else {
      if (password && password.length >= 4) {
        const hashedPassword = await bcrypt.hash(password, 10);
        user.passwordHash = hashedPassword;
        await user.save();
        await Account.findOneAndUpdate({ email }, { psw: hashedPassword });
      }
    }
    const authorized = new AuthorizedPerson({ clientId: req.user.userId, userId: user._id, fullName: fullName || user.fullName, email, phoneNumber, relationship, canTrack: canTrack ?? true, canChat: canChat ?? true, canViewLocation: canViewLocation ?? true });
    await authorized.save();
    res.status(201).json({ message: 'Authorized person added successfully', authorized });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.delete('/authorized/:id', async (req, res) => {
  try {
    const authorized = await AuthorizedPerson.findOneAndDelete({ _id: req.params.id, clientId: req.user.userId });
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
      clientTasks: booking.clientTasks || [],
      trackingStage: booking.trackingStage,
      stageTimes: booking.stageTimes || {},
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
      service: service.name, serviceId, date: new Date(date), startTime: time, endTime,
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

router.post('/booking-requests', async (req, res) => {
  try {
    const { providerId, serviceName, date, startTime, endTime, location, notes, dependantId, tasks } = req.body;
    const bookingRequest = new BookingRequest({
      clientId: req.user.userId, providerId, serviceName, date, startTime, endTime,
      location, notes, dependantId, tasks: tasks || []
    });
    await bookingRequest.save();
    await Notification.create({ userId: providerId, title: 'New Booking Request', message: `You have a new request for ${serviceName} on ${date}`, type: 'booking' });
    res.status(201).json({ message: 'Booking request sent successfully', requestId: bookingRequest._id });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

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
      workSteps: booking.workSteps || [],
      attachments: booking.attachments || [],
      stageTimes: booking.stageTimes || {},
      eta: booking.eta,
      providerLat: booking.providerLat,
      providerLng: booking.providerLng,
      lastUpdate: booking.updatedAt,
      clientTasks: booking.clientTasks || []
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

// ✅ جلب المدفوعات المعلقة مع معلومات البنك للمزود
router.get('/payments/pending', async (req, res) => {
  try {
    const bookings = await Booking.find({
      clientId: req.user.userId,
      status: 'Confirmed',
      halfPaid: false
    }).populate('providerId', 'fullName phoneNumber profilePicture')
      .populate('serviceId', 'name');
    
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

// ✅ تحديث نصف الدفع
router.put('/bookings/:id/pay-half', async (req, res) => {
  try {
    const { id } = req.params;
    const { paymentMethod, clientPaymentDetails } = req.body;
    
    const booking = await Booking.findOne({ _id: id, clientId: req.user.userId });
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }
    if (booking.paymentStatus === 'Completed') {
      return res.status(400).json({ message: 'Already fully paid' });
    }
    if (booking.halfPaid) {
      return res.status(400).json({ message: 'Half payment already made' });
    }
    
    const halfAmount = booking.totalPrice / 2;
    
    const payment = new Payment({ 
      bookingId: booking._id, 
      amount: halfAmount, 
      status: 'half_paid', 
      payment_method: paymentMethod,
      clientPaymentInfo: clientPaymentDetails || {}
    });
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
    
    await Notification.create({ 
      userId: booking.providerId, 
      title: 'Half Payment Received', 
      message: `Client paid half (${halfAmount} DZD). Tracking has started.`, 
      type: 'payment',
      bookingId: booking._id
    });
    
    await Notification.create({ 
      userId: booking.clientId, 
      title: 'Tracking Started', 
      message: 'Your service tracking has started. You can now see live updates from the provider.', 
      type: 'tracking',
      bookingId: booking._id
    });
    
    res.json({ 
      message: 'Half payment successful. Tracking started.', 
      halfAmount, 
      remainingAmount: booking.remainingAmount,
      trackingStage: booking.trackingStage,
      stageTimes: booking.stageTimes
    });
  } catch (error) {
    console.error('Half payment error:', error);
    res.status(500).json({ message: error.message });
  }
});

// ✅ دفع الرصيد المتبقي (مع تصحيح تلقائي وإرسال Socket)
router.post('/bookings/:id/pay-remaining', async (req, res) => {
  try {
    const { id } = req.params;
    const clientId = req.user.userId;
    
    let booking = await Booking.findOne({ _id: id, clientId });
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }
    
    // ✅ تصحيح تلقائي: إذا كان paymentStatus = Completed ولكن remainingAmount > 0
    if (booking.paymentStatus === 'Completed' && booking.remainingAmount > 0) {
      console.log('⚠️ Inconsistent data: fixing paymentStatus to HalfPaid');
      booking.paymentStatus = 'HalfPaid';
      await booking.save();
    }
    
    if (booking.status !== 'Completed') {
      return res.status(400).json({ message: 'Service not yet completed' });
    }
    
    if (booking.paymentStatus === 'Completed') {
      return res.status(400).json({ message: 'Already fully paid' });
    }
    
    const remainingAmount = booking.remainingAmount || 0;
    if (remainingAmount <= 0) {
      return res.status(400).json({ message: 'No remaining amount to pay' });
    }
    
    booking.paymentStatus = 'Completed';
    booking.paidAt = new Date();
    booking.remainingAmount = 0;
    await booking.save();
    
    await Notification.create({
      userId: booking.providerId,
      title: 'Remaining Payment Received',
      message: `Client completed payment of ${remainingAmount} DZD.`,
      type: 'payment',
      bookingId: booking._id
    });
    
    // ✅ إرسال تحديث عبر Socket.IO للمزود
    const io = req.app.get('io');
    if (io) {
      io.to(`tracking_${booking._id}`).emit('trackingUpdate', {
        bookingId: booking._id,
        paymentStatus: 'Completed',
        remainingAmount: 0,
        stage: booking.trackingStage
      });
    }
    
    res.json({ success: true, message: 'Payment successful', remainingAmount });
  } catch (error) {
    console.error('Pay remaining error:', error);
    res.status(500).json({ message: error.message });
  }
});

// ✅ تقييم المزود من قبل العميل (مصحح: لا يتحقق من paymentStatus، فقط من status)
router.post('/bookings/:id/rate-provider', async (req, res) => {
  try {
    const { id } = req.params;
    const { rating, comment } = req.body;
    const clientId = req.user.userId;
    
    console.log(`📡 Rate provider request: bookingId=${id}, clientId=${clientId}, rating=${rating}`);
    
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ message: 'Rating must be between 1 and 5' });
    }
    
    const booking = await Booking.findOne({ _id: id, clientId });
    if (!booking) {
      console.log('❌ Booking not found');
      return res.status(404).json({ message: 'Booking not found' });
    }
    
    // ✅ السماح بالتقييم إذا كانت الخدمة مكتملة فقط (لا نتحقق من paymentStatus)
    if (booking.status !== 'Completed') {
      console.log('❌ Service not completed');
      return res.status(400).json({ message: 'Service not completed yet' });
    }
    
    if (booking.rating) {
      console.log('❌ Already rated');
      return res.status(400).json({ message: 'Already rated' });
    }
    
    // حفظ التقييم
    booking.rating = rating;
    booking.feedback = comment || '';
    await booking.save();
    console.log('✅ Booking rating saved');
    
    // تحديث متوسط التقييم للمزود
    const allBookings = await Booking.find({
      providerId: booking.providerId,
      rating: { $exists: true }
    });
    console.log(`📊 Found ${allBookings.length} ratings for provider ${booking.providerId}`);
    
    const avgRating = allBookings.length > 0
      ? allBookings.reduce((sum, b) => sum + (b.rating || 0), 0) / allBookings.length
      : rating;
    
    // تحديث ServiceProvider باستخدام userid
    const provider = await ServiceProvider.findOneAndUpdate(
      { userid: booking.providerId },
      { 
        averageRating: avgRating,
        totalReviews: allBookings.length,
        totalServices: await Booking.countDocuments({ providerId: booking.providerId, status: 'Completed' })
      },
      { new: true }
    );
    
    if (!provider) {
      console.log('⚠️ ServiceProvider not found for userid:', booking.providerId);
    } else {
      console.log('✅ ServiceProvider updated');
    }
    
    // حساب التقييمات السلبية وحظر المزود إذا لزم الأمر
    const negativeReviews = allBookings.filter(b => b.rating <= 2).length;
    console.log(`⭐ Negative reviews: ${negativeReviews}`);
    
    if (negativeReviews >= 5) {
      const providerUser = await User.findById(booking.providerId);
      if (providerUser && providerUser.role === 'Provider') {
        providerUser.isActive = false;
        await providerUser.save();
        console.log('🚫 Provider blocked due to negative reviews');
        
        await Notification.create({
          userId: booking.providerId,
          title: 'Account Suspended',
          message: 'Your account has been suspended due to 5 negative reviews.',
          type: 'system'
        });
        
        const admin = await User.findOne({ role: 'Admin' });
        if (admin) {
          await Notification.create({
            userId: admin._id,
            title: 'Provider Auto-Blocked',
            message: `${providerUser.fullName} has been blocked due to 5 negative reviews.`,
            type: 'system'
          });
        }
      }
    }
    
    // إشعار للمزود بأنه تم تقييمه
    await Notification.create({
      userId: booking.providerId,
      title: 'You Have Been Rated',
      message: `Client rated you ${rating} stars.${comment ? ` Comment: ${comment}` : ''}`,
      type: 'review',
      bookingId: booking._id
    });
    
    // إشعار للأدمن (اختياري)
    const admin = await User.findOne({ role: 'Admin' });
    if (admin) {
      await Notification.create({
        userId: admin._id,
        title: 'Provider Rated',
        message: `${booking.client} rated provider ${booking.provider} with ${rating} stars.`,
        type: 'review',
        bookingId: booking._id
      });
    }
    
    res.json({ success: true, message: 'Rating submitted', averageRating: avgRating });
  } catch (error) {
    console.error('❌ Rate provider error:', error);
    res.status(500).json({ message: error.message });
  }
});

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

router.post('/feedback', async (req, res) => {
  try {
    const { bookingId, rating, comment } = req.body;
    const booking = await Booking.findOne({ _id: bookingId, clientId: req.user.userId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    booking.rating = rating;
    booking.feedback = comment;
    await booking.save();
    res.status(201).json({ message: 'Feedback submitted successfully', booking: { id: booking._id, rating: booking.rating, feedback: booking.feedback } });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/feedback', async (req, res) => {
  try {
    const bookings = await Booking.find({ clientId: req.user.userId, rating: { $exists: true, $ne: null } }).populate('serviceId', 'name');
    const feedbacks = bookings.map(b => ({ id: b._id, bookingId: b._id, service: b.serviceId?.name, rating: b.rating, comment: b.feedback, reply: b.feedbackReply, createdAt: b.createdAt }));
    res.json(feedbacks);
  } catch (error) {
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
    const bookings = await Booking.find({ clientId: req.user.userId, status: 'Completed' })
      .populate('providerId', 'fullName')
      .populate('serviceId', 'name price')
      .populate('dependentId', 'fullName')
      .sort({ createdAt: -1 });
    res.json(bookings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;