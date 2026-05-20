const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const Booking = require('../models/Booking');
const ServiceProvider = require('../models/ServiceProvider');
const Service = require('../models/Service');
const Notification = require('../models/Notification');
const Client = require('../models/Client');

// ==================== إنشاء حجز ====================
router.post('/bookings', authMiddleware, async (req, res) => {
  try {
    const clientId = req.user.userId;
    const {
      providerId,
      serviceId,
      date,
      startTime,
      endTime,
      dependentId,
      notes,
      location,
      clientTasks
    } = req.body;

    // التحقق من البيانات المطلوبة
    if (!providerId || !serviceId || !date || !startTime || !endTime) {
      return res.status(400).json({
        success: false,
        message: 'البيانات المطلوبة: المزود، الخدمة، التاريخ، الوقت'
      });
    }

    // التحقق من وجود المزود والخدمة
    const provider = await ServiceProvider.findById(providerId);
    const service = await Service.findById(serviceId);

    if (!provider || !service) {
      return res.status(404).json({
        success: false,
        message: 'المزود أو الخدمة غير موجودة'
      });
    }

    // التحقق من توفرية المزود
    const bookingDate = new Date(date);
    const dateStr = bookingDate.toISOString().split('T')[0];
    const availability = Object.fromEntries(provider.availability || new Map());

    if (!availability[dateStr]) {
      return res.status(400).json({
        success: false,
        message: 'المزود غير متوفر في هذا التاريخ'
      });
    }

    const slot = availability[dateStr].find(s => s.startTime === startTime);
    if (!slot || slot.isBooked) {
      return res.status(400).json({
        success: false,
        message: 'الموعد غير متاح'
      });
    }

    // حساب السعر
    const [startHour, startMin] = startTime.split(':').map(Number);
    const [endHour, endMin] = endTime.split(':').map(Number);
    const hours = (endHour + endMin / 60) - (startHour + startMin / 60);
    const totalPrice = provider.hourlyRate * hours;

    // إنشاء الحجز
    const booking = new Booking({
      clientId,
      providerId,
      serviceId,
      date: new Date(date),
      startTime,
      endTime,
      dependentId: dependentId || null,
      notes: notes || '',
      location: location || '',
      clientTasks: clientTasks || [],
      totalPrice,
      status: 'Pending',
      paymentStatus: 'Pending',
      trackingStage: 'Pending'
    });

    await booking.save();

    // تحديث التوفرية
    availability[dateStr] = availability[dateStr].map(s =>
      s.startTime === startTime ? { ...s, isBooked: true } : s
    );
    provider.availability = new Map(Object.entries(availability));
    await provider.save();

    // إضافة إشعار للمزود
    const client = await Client.findOne({ userId: clientId });
    const notification = new Notification({
      userId: providerId,
      type: 'booking_request',
      title: 'طلب حجز جديد',
      message: `${client?.fullName || 'عميل'} يطلب حجز الخدمة ${service.name}`,
      bookingId: booking._id,
      isRead: false
    });
    await notification.save();

    res.status(201).json({
      success: true,
      message: 'تم إنشاء الحجز بنجاح',
      data: booking
    });
  } catch (error) {
    console.error('Booking error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== الحصول على الحجوزات ====================
router.get('/bookings', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { status, role } = req.query;

    let filter = {};

    // تحديد ما إذا كان العميل أم المزود
    if (role === 'provider') {
      filter.providerId = userId;
    } else {
      filter.clientId = userId;
    }

    if (status) filter.status = status;

    const bookings = await Booking.find(filter)
      .populate('clientId', 'fullName phoneNumber profilePicture')
      .populate('providerId', 'fullName phoneNumber profilePicture')
      .populate('serviceId', 'name basePrice')
      .populate('dependentId', 'fullName')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: bookings.length,
      data: bookings
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== تفاصيل الحجز ====================
router.get('/bookings/:bookingId', authMiddleware, async (req, res) => {
  try {
    const { bookingId } = req.params;

    const booking = await Booking.findById(bookingId)
      .populate('clientId')
      .populate('providerId')
      .populate('serviceId')
      .populate('dependentId');

    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'الحجز غير موجود'
      });
    }

    res.json({
      success: true,
      data: booking
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== قبول/رفض الحجز (المزود) ====================
router.put('/bookings/:bookingId/respond', authMiddleware, async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { action, reason } = req.body;

    if (!['accept', 'reject'].includes(action)) {
      return res.status(400).json({
        success: false,
        message: 'الإجراء يجب أن يكون accept أو reject'
      });
    }

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'الحجز غير موجود'
      });
    }

    if (action === 'accept') {
      booking.status = 'Confirmed';
      booking.trackingStage = 'Accepted';
    } else {
      booking.status = 'Cancelled';
      booking.notes = (booking.notes || '') + `\nرفض المزود: ${reason || 'بدون سبب'}`;

      // إعادة التوفرية
      const provider = await ServiceProvider.findById(booking.providerId);
      const dateStr = new Date(booking.date).toISOString().split('T')[0];
      const availability = Object.fromEntries(provider.availability || new Map());

      if (availability[dateStr]) {
        availability[dateStr] = availability[dateStr].map(s =>
          s.startTime === booking.startTime ? { ...s, isBooked: false } : s
        );
        provider.availability = new Map(Object.entries(availability));
        await provider.save();
      }
    }

    await booking.save();

    // إرسال إشعار للعميل
    const notification = new Notification({
      userId: booking.clientId,
      type: action === 'accept' ? 'booking_confirmed' : 'booking_rejected',
      title: action === 'accept' ? 'تم قبول طلبك' : 'تم رفض طلبك',
      message: action === 'accept'
        ? 'قبل المزود طلب الحجز الخاص بك'
        : `رفض المزود طلبك: ${reason || 'بدون سبب'}`,
      bookingId: booking._id,
      isRead: false
    });
    await notification.save();

    res.json({
      success: true,
      message: `تم ${action === 'accept' ? 'قبول' : 'رفض'} الطلب بنجاح`,
      data: booking
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== تحديث المهام ====================
router.put('/bookings/:bookingId/tasks', authMiddleware, async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { clientTasks } = req.body;

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'الحجز غير موجود'
      });
    }

    booking.clientTasks = clientTasks || [];
    booking.clientTasksSubmittedAt = new Date();
    await booking.save();

    res.json({
      success: true,
      message: 'تم تحديث المهام بنجاح',
      data: booking.clientTasks
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== تحديث تقدم الخدمة ====================
router.put('/bookings/:bookingId/progress', authMiddleware, async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { trackingStage, workSteps, attachments, location } = req.body;

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'الحجز غير موجود'
      });
    }

    if (trackingStage) {
      booking.trackingStage = trackingStage;
      booking.stageTimes = booking.stageTimes || new Map();
      booking.stageTimes.set(trackingStage, new Date().toISOString());
    }

    if (workSteps) {
      booking.workSteps = workSteps;
    }

    if (attachments) {
      booking.attachments = attachments;
    }

    if (location) {
      booking.providerLat = location.latitude;
      booking.providerLng = location.longitude;
    }

    if (trackingStage === 'Completed') {
      booking.status = 'Completed';
    }

    await booking.save();

    // إرسال إشعار للعميل
    const notification = new Notification({
      userId: booking.clientId,
      type: 'booking_update',
      title: 'تحديث على حجزك',
      message: `تم تحديث حالة الخدمة: ${trackingStage}`,
      bookingId: booking._id,
      isRead: false
    });
    await notification.save();

    res.json({
      success: true,
      message: 'تم تحديث التقدم بنجاح',
      data: booking
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== تقييم الخدمة ====================
router.post('/bookings/:bookingId/rate', authMiddleware, async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { rating, feedback } = req.body;

    if (!rating || rating < 0 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'التقييم يجب أن يكون بين 0 و 5'
      });
    }

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'الحجز غير موجود'
      });
    }

    booking.rating = rating;
    booking.feedback = feedback || '';
    await booking.save();

    // تحديث متوسط تقييم المزود
    const allRatings = await Booking.find({
      providerId: booking.providerId,
      rating: { $exists: true }
    });

    const avgRating = allRatings.reduce((sum, b) => sum + b.rating, 0) / allRatings.length;
    await ServiceProvider.findByIdAndUpdate(
      booking.providerId,
      {
        averageRating: avgRating,
        totalReviews: allRatings.length
      }
    );

    res.json({
      success: true,
      message: 'تم حفظ التقييم بنجاح'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

module.exports = router;
