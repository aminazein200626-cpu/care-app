const User = require('../models/User');
const Client = require('../models/Client');
const ServiceProvider = require('../models/ServiceProvider');
const Dependent = require('../models/Dependent');
const Service = require('../models/Service');
const Booking = require('../models/Booking');
const Notification = require('../models/Notification');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');

exports.registerClient = async (req, res) => {
  try {
    const { fullName, email, password, phoneNumber, wilaya, address } = req.body;

    if (!fullName || !email || !password || !phoneNumber || !wilaya) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: fullName, email, password, phoneNumber, wilaya'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters'
      });
    }

    let existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email already registered'
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = new User({
      fullName,
      email,
      passwordHash: hashedPassword,
      phoneNumber,
      role: 'Client',
      isActive: true,
      isVerified: true
    });
    await user.save();

    const client = new Client({
      userId: user._id,
      fullName,
      email,
      phoneNumber,
      wilaya,
      address: address || '',
      isActive: true,
      isVerified: true,
      status: 'active'
    });
    await client.save();

    const token = jwt.sign(
      {
        userId: user._id,
        role: 'Client',
        email: user.email,
        clientId: client._id
      },
      process.env.JWT_SECRET || 'my_super_secret_key_12345',
      { expiresIn: '30d' }
    );

    res.status(201).json({
      success: true,
      message: 'Registration successful',
      token,
      user: {
        userId: user._id,
        clientId: client._id,
        fullName: user.fullName,
        email: user.email,
        phoneNumber: user.phoneNumber,
        wilaya: client.wilaya,
        role: 'Client'
      }
    });
  } catch (error) {
    console.error('Client registration error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getClientProfile = async (req, res) => {
  try {
    const userId = req.user.userId;

    const user = await User.findById(userId).select('-passwordHash');
    const client = await Client.findOne({ userId }).populate('dependents');

    if (!client) {
      return res.status(404).json({
        success: false,
        message: 'Client not found'
      });
    }

    res.json({
      success: true,
      data: {
        user,
        client
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.updateClientProfile = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { fullName, phoneNumber, address, wilaya, gender, dateOfBirth } = req.body;

    const user = await User.findByIdAndUpdate(
      userId,
      {
        fullName: fullName || undefined,
        phoneNumber: phoneNumber || undefined,
        gender: gender || undefined,
        dateOfBirth: dateOfBirth || undefined
      },
      { new: true }
    ).select('-passwordHash');

    const client = await Client.findOneAndUpdate(
      { userId },
      {
        fullName: fullName || undefined,
        phoneNumber: phoneNumber || undefined,
        address: address || undefined,
        wilaya: wilaya || undefined,
        gender: gender || undefined,
        dateOfBirth: dateOfBirth || undefined,
        updatedAt: new Date()
      },
      { new: true }
    ).populate('dependents');

    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: { user, client }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.searchProviders = async (req, res) => {
  try {
    const { wilaya, municipality, serviceId, rating, sortBy } = req.query;

    let filter = {
      status: 'active',
      isVerified: true
    };

    if (wilaya) filter.wilaya = wilaya;
    if (municipality) filter.municipality = municipality;
    if (serviceId) {
      filter.services = serviceId;
    }

    let query = ServiceProvider.find(filter).select('-documents');

    if (rating) {
      query = query.where('averageRating').gte(parseFloat(rating));
    }

    if (sortBy === 'rating') {
      query = query.sort({ averageRating: -1 });
    } else if (sortBy === 'price') {
      query = query.sort({ hourlyRate: 1 });
    } else if (sortBy === 'experience') {
      query = query.sort({ yearsOfExperience: -1 });
    }

    const providers = await query.limit(20);
    
    const formattedProviders = providers.map(provider => {
      let serviceName = '';
      if (provider.services && provider.services.length > 0) {
        if (provider.services[0] && typeof provider.services[0] === 'object' && provider.services[0].name) {
          serviceName = provider.services[0].name;
        } else if (typeof provider.services[0] === 'string') {
          serviceName = provider.services[0];
        } else {
          serviceName = 'Care Service';
        }
      } else if (provider.serviceNames && provider.serviceNames.length > 0) {
        serviceName = provider.serviceNames[0];
      } else {
        serviceName = 'Care Service';
      }
      
      return {
        ...provider.toObject(),
        service: serviceName,
        serviceType: serviceName
      };
    });

    res.json({
      success: true,
      count: formattedProviders.length,
      data: formattedProviders
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.searchServices = async (req, res) => {
  try {
    const { search, categoryId } = req.query;

    let filter = { isActive: true };

    if (search) {
      filter.name = { $regex: search, $options: 'i' };
    }

    if (categoryId) {
      filter.category = categoryId;
    }

    const services = await Service.find(filter)
      .populate('category')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: services.length,
      data: services
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getProviderDetails = async (req, res) => {
  try {
    const { providerId } = req.params;

    const provider = await ServiceProvider.findById(providerId)
      .populate('services')
      .populate('categoryId');

    if (!provider) {
      return res.status(404).json({
        success: false,
        message: 'Provider not found'
      });
    }

    const completedBookings = await Booking.find({
      providerId,
      status: 'Completed',
      rating: { $exists: true }
    }).select('rating feedback');

    res.json({
      success: true,
      data: {
        provider,
        reviews: completedBookings
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.createBooking = async (req, res) => {
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

    if (!providerId || !serviceId || !date || !startTime) {
      return res.status(400).json({
        success: false,
        message: 'Provider, service, date and startTime are required'
      });
    }

    const provider = await ServiceProvider.findById(providerId);
    const service = await Service.findById(serviceId);

    if (!provider || !service) {
      return res.status(404).json({
        success: false,
        message: 'Provider or service not found'
      });
    }

    const pricePerHour = provider.hourlyRate;
    const [startHour, startMin] = startTime.split(':').map(Number);
    const [endHour, endMin] = endTime.split(':').map(Number);
    const hours = (endHour + endMin / 60) - (startHour + startMin / 60);
    const totalPrice = pricePerHour * hours;

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
      paymentStatus: 'Pending'
    });

    await booking.save();

    const notification = new Notification({
      userId: providerId,
      type: 'booking_request',
      title: 'New Booking Request',
      message: `Client requested ${service.name}`,
      bookingId: booking._id,
      isRead: false
    });
    await notification.save();

    res.status(201).json({
      success: true,
      message: 'Booking created successfully',
      data: booking
    });
  } catch (error) {
    console.error('Booking error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getClientBookings = async (req, res) => {
  try {
    const clientId = req.user.userId;
    const { status } = req.query;

    let filter = { clientId };
    if (status) filter.status = status;

    const bookings = await Booking.find(filter)
      .populate('providerId', 'fullName phoneNumber profilePicture')
      .populate('serviceId', 'name price')
      .populate('dependentId', 'fullName')
      .sort({ createdAt: -1 });

    const formatted = bookings.map(booking => ({
      _id: booking._id,
      id: booking._id,
      service: booking.serviceId?.name || booking.service,
      provider: booking.providerId?.fullName,
      providerAvatar: booking.providerId?.profilePicture,
      date: booking.date,
      time: booking.startTime,
      status: booking.status,
      location: booking.location,
      price: booking.totalPrice,
      halfPaid: booking.halfPaid || false,
      remainingAmount: booking.remainingAmount || 0,
      paymentStatus: booking.paymentStatus,
      trackingStage: booking.trackingStage
    }));

    res.json(formatted);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.rateBooking = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { rating, feedback } = req.body;

    if (!rating || rating < 0 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be between 0 and 5'
      });
    }

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    booking.rating = rating;
    booking.feedback = feedback || '';
    await booking.save();

    const allBookings = await Booking.find({
      providerId: booking.providerId,
      rating: { $exists: true }
    });

    const avgRating = allBookings.reduce((sum, b) => sum + b.rating, 0) / allBookings.length;
    await ServiceProvider.findByIdAndUpdate(
      booking.providerId,
      { averageRating: avgRating }
    );

    res.json({
      success: true,
      message: 'Rating saved successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getProviderAvailability = async (req, res) => {
  try {
    const { providerId } = req.params;

    let provider = await ServiceProvider.findOne({ userid: providerId });
    if (!provider) {
      const user = await User.findById(providerId);
      if (user && user.email) {
        provider = await ServiceProvider.findOne({ email: user.email });
      }
    }

    if (!provider) {
      return res.json({});
    }

    let availability = {};
    if (provider.availability) {
      if (typeof provider.availability === 'string') {
        try {
          availability = JSON.parse(provider.availability);
        } catch (e) {
          availability = {};
        }
      } else {
        availability = provider.availability;
      }
    }

    res.json(availability);
  } catch (error) {
    console.error('getProviderAvailability error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== دفع الرصيد المتبقي ====================
exports.payRemaining = async (req, res) => {
  try {
    const { id } = req.params;
    const clientId = req.user.userId;
    
    console.log(`💰 Pay remaining request: bookingId=${id}, clientId=${clientId}`);
    
    let booking = await Booking.findOne({ _id: id, clientId });
    if (!booking) {
      console.log(`❌ Booking not found: ${id}`);
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    
    // ✅ تصحيح تلقائي للبيانات غير المتناسقة
    if (booking.paymentStatus === 'Completed' && booking.remainingAmount > 0) {
      console.log('⚠️ Inconsistent data: fixing paymentStatus to HalfPaid');
      booking.paymentStatus = 'HalfPaid';
      await booking.save();
    }
    
    console.log(`📊 Booking status: ${booking.status}, paymentStatus: ${booking.paymentStatus}, remainingAmount: ${booking.remainingAmount}`);
    
    if (booking.status !== 'Completed') {
      return res.status(400).json({ success: false, message: 'Service not yet completed' });
    }
    
    if (booking.paymentStatus === 'Completed') {
      return res.status(400).json({ success: false, message: 'Already fully paid' });
    }
    
    const remainingAmount = booking.remainingAmount || 0;
    if (remainingAmount <= 0) {
      return res.status(400).json({ success: false, message: 'No remaining amount to pay' });
    }
    
    // تسجيل الدفع
    booking.paymentStatus = 'Completed';
    booking.paidAt = new Date();
    booking.remainingAmount = 0;
    await booking.save();
    
    console.log(`✅ Payment successful for booking ${id}, amount: ${remainingAmount}`);
    
    // إرسال إشعار للمزود
    await Notification.create({
      userId: booking.providerId,
      title: 'Remaining Payment Received',
      message: `Client completed payment of ${remainingAmount} DZD.`,
      type: 'payment',
      bookingId: booking._id
    });
    
    // إرسال تحديث عبر Socket.IO للمزود
    const io = req.app.get('io');
    if (io) {
      io.to(`tracking_${booking._id}`).emit('trackingUpdate', {
        bookingId: booking._id,
        paymentStatus: 'Completed',
        remainingAmount: 0
      });
    }
    
    res.json({ success: true, message: 'Payment successful', remainingAmount });
  } catch (error) {
    console.error('❌ Pay remaining error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// ==================== تقييم المزود من قبل العميل (مصحح: يسمح بإعادة التقييم) ====================
exports.rateProvider = async (req, res) => {
  try {
    const { id } = req.params;
    const { rating, comment } = req.body;
    const clientId = req.user.userId;
    
    console.log('📡 rateProvider called:', { id, rating, comment, clientId });
    
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ message: 'Rating must be between 1 and 5' });
    }
    
    const booking = await Booking.findOne({ _id: id, clientId });
    if (!booking) {
      console.log('❌ Booking not found');
      return res.status(404).json({ message: 'Booking not found' });
    }
    
    // ✅ السماح بالتقييم إذا كانت الخدمة مكتملة فقط
    if (booking.status !== 'Completed') {
      console.log('❌ Service not completed');
      return res.status(400).json({ message: 'Service not completed yet' });
    }
    
    // ✅ إزالة الشرط الذي يمنع التقييم إذا كان موجوداً (يمكن تحديث التقييم)
    // if (booking.rating) {
    //   return res.status(400).json({ message: 'Already rated' });
    // }
    
    // حفظ التقييم (تحديث إذا كان موجوداً)
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
    
    // تحديث ServiceProvider
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
    
    // إشعار للمزود
    await Notification.create({
      userId: booking.providerId,
      title: 'You Have Been Rated',
      message: `Client rated you ${rating} stars.${comment ? ` Comment: ${comment}` : ''}`,
      type: 'review',
      bookingId: booking._id
    });
    
    // إشعار للأدمن
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
};