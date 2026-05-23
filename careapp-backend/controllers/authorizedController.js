const Booking = require('../models/Booking');
const AuthorizedPerson = require('../models/AuthorizedPerson');

// الحصول على قائمة الخدمات (الحجوزات النشطة) التي يسمح للشخص المفوض بتتبعها
exports.getAuthorizedServices = async (req, res) => {
  try {
    const authorizedPersonId = req.user.userId;

    // البحث عن جميع العملاء الذين أذن لهم هذا الشخص المفوض
    const authorizedPersons = await AuthorizedPerson.find({ userId: authorizedPersonId })
      .populate('id_U_CL', 'fullName'); // id_U_CL هو العميل

    if (!authorizedPersons.length) {
      return res.json([]);
    }

    // استخراج معرفات العملاء
    const clientIds = authorizedPersons.map(ap => ap.id_U_CL._id);

    // البحث عن الحجوزات النشطة لهؤلاء العملاء
    const bookings = await Booking.find({
      clientId: { $in: clientIds },
      status: { $in: ['Confirmed', 'In Progress', 'Pending'] }
    })
      .populate('providerId', 'fullName phoneNumber profilePicture')
      .populate('serviceId', 'name')
      .sort({ createdAt: -1 });

    // تنسيق البيانات للواجهة
    const services = bookings.map(booking => ({
      id: booking._id,
      service: booking.serviceId?.name || booking.service,
      provider: booking.providerId?.fullName || 'Unknown',
      providerId: booking.providerId?._id,
      providerAvatar: booking.providerId?.profilePicture,
      clientName: booking.client?.fullName || 'Client',
      date: booking.date,
      time: booking.startTime,
      status: booking.status,
      trackingStage: booking.trackingStage || 'Pending'
    }));

    res.json(services);
  } catch (error) {
    console.error('Error fetching authorized services:', error);
    res.status(500).json({ message: error.message });
  }
};

// الحصول على تفاصيل التتبع لخدمة محددة
exports.getTrackingInfo = async (req, res) => {
  try {
    const { serviceId } = req.params;
    const authorizedPersonId = req.user.userId;

    // التحقق من أن الشخص المفوض لديه صلاحية لهذه الخدمة
    const booking = await Booking.findById(serviceId);
    if (!booking) {
      return res.status(404).json({ message: 'Service not found' });
    }

    const isAuthorized = await AuthorizedPerson.exists({
      userId: authorizedPersonId,
      id_U_CL: booking.clientId,
      canTrack: true
    });

    if (!isAuthorized) {
      return res.status(403).json({ message: 'You are not authorized to track this service' });
    }

    // إرجاع معلومات التتبع
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
    console.error('Error fetching tracking info:', error);
    res.status(500).json({ message: error.message });
  }
};