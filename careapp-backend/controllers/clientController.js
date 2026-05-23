const User = require('../models/User');
const Client = require('../models/Client');
const ServiceProvider = require('../models/ServiceProvider');
const Dependent = require('../models/Dependent');
const Service = require('../models/Service');
const Booking = require('../models/Booking');
const BookingRequest = require('../models/BookingRequest');
const Notification = require('../models/Notification');
const Task = require('../models/Task');
const File = require('../models/File');
const Feedback = require('../models/Feedback');
const MedicalInfo = require('../models/MedicalInfo');
const DependentFile = require('../models/DependentFile');
const Account = require('../models/Account');
const AuthorizedPerson = require('../models/AuthorizedPerson');
const sendEmail = require('../utils/emailService');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');

// ==================== Register a new client ====================
const registerClient = async (req, res) => {
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

// ==================== Get client profile ====================
const getClientProfile = async (req, res) => {
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

    const enrichedDependents = [];
    for (const dep of client.dependents) {
      const files = await DependentFile.find({ dependentId: dep._id });
      const medicalInfo = dep.medicalInfoId ? await MedicalInfo.findById(dep.medicalInfoId) : null;
      enrichedDependents.push({
        ...dep.toObject(),
        files,
        medicalInfo
      });
    }

    res.json({
      success: true,
      data: {
        user,
        client: {
          ...client.toObject(),
          dependents: enrichedDependents
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ==================== Update client profile ====================
const updateClientProfile = async (req, res) => {
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

// ==================== Search providers ====================
const searchProviders = async (req, res) => {
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

// ==================== Search services ====================
const searchServices = async (req, res) => {
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

// ==================== Get provider details ====================
const getProviderDetails = async (req, res) => {
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

// ==================== Create direct booking (legacy) ====================
const createBooking = async (req, res) => {
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

    console.log('=== createBooking called ===');
    console.log('providerId:', providerId);
    console.log('startTime:', startTime);
    console.log('endTime:', endTime);

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

    console.log('provider.hourlyRate:', provider.hourlyRate);

    const [startHour, startMin] = startTime.split(':').map(Number);
    const [endHour, endMin] = endTime.split(':').map(Number);
    const hours = (endHour + endMin/60) - (startHour + startMin/60);
    const totalPrice = (provider.hourlyRate || 0) * hours;

    console.log('hours:', hours);
    console.log('totalPrice:', totalPrice);

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
      data: {
        ...booking.toObject(),
        totalPrice
      }
    });
  } catch (error) {
    console.error('Booking error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ==================== Get client bookings ====================
const getClientBookings = async (req, res) => {
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

// ==================== Rate a booking ====================
const rateBooking = async (req, res) => {
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

// ==================== Get provider availability ====================
const getProviderAvailability = async (req, res) => {
  try {
    const { providerId } = req.params;

    let provider = await ServiceProvider.findOne({ 
      $or: [
        { _id: providerId },
        { userid: providerId }
      ]
    });
    
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

// ==================== Pay remaining amount ====================
const payRemaining = async (req, res) => {
  try {
    const { id } = req.params;
    const clientId = req.user.userId;
    
    console.log(`Pay remaining request: bookingId=${id}, clientId=${clientId}`);
    
    let booking = await Booking.findOne({ _id: id, clientId });
    if (!booking) {
      console.log(`Booking not found: ${id}`);
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    
    if (booking.paymentStatus === 'Completed' && booking.remainingAmount > 0) {
      console.log('Inconsistent data: fixing paymentStatus to HalfPaid');
      booking.paymentStatus = 'HalfPaid';
      await booking.save();
    }
    
    console.log(`Booking status: ${booking.status}, paymentStatus: ${booking.paymentStatus}, remainingAmount: ${booking.remainingAmount}`);
    
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
    
    booking.paymentStatus = 'Completed';
    booking.paidAt = new Date();
    booking.remainingAmount = 0;
    await booking.save();
    
    console.log(`Payment successful for booking ${id}, amount: ${remainingAmount}`);
    
    await Notification.create({
      userId: booking.providerId,
      title: 'Remaining Payment Received',
      message: `Client completed payment of ${remainingAmount} DZD.`,
      type: 'payment',
      bookingId: booking._id
    });
    
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
    console.error('Pay remaining error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// ==================== Rate provider (client rates provider) ====================
const rateProvider = async (req, res) => {
  try {
    const { id } = req.params;
    const { rating, comment } = req.body;
    const clientId = req.user.userId;

    console.log('=== rateProvider called ===');
    console.log('bookingId:', id);
    console.log('rating:', rating);
    console.log('comment:', comment);
    console.log('clientId:', clientId);

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ message: 'Rating must be between 1 and 5' });
    }

    const booking = await Booking.findOne({ _id: id, clientId });
    if (!booking) {
      console.log('Booking not found');
      return res.status(404).json({ message: 'Booking not found' });
    }
    if (booking.status !== 'Completed') {
      console.log('Service not completed');
      return res.status(400).json({ message: 'Service not completed yet' });
    }

    const existingFeedback = await Feedback.findOne({ bookingId: booking._id, clientId });
    if (existingFeedback) {
      console.log('Already rated this booking');
      return res.status(400).json({ message: 'Already rated this booking' });
    }

    try {
      const feedback = new Feedback({
        overall_rating: rating,
        comment: comment || '',
        bookingId: booking._id,
        clientId: booking.clientId,
        providerId: booking.providerId
      });
      await feedback.save();
      console.log('✅ Feedback saved successfully:', feedback._id);
    } catch (err) {
      console.error('❌ Error saving Feedback:', err);
      return res.status(500).json({ message: 'Failed to save feedback: ' + err.message });
    }

    booking.rating = rating;
    booking.feedback = comment || '';
    await booking.save();

    const allFeedbacks = await Feedback.find({ providerId: booking.providerId });
    const avgRating = allFeedbacks.length > 0
      ? allFeedbacks.reduce((sum, f) => sum + f.overall_rating, 0) / allFeedbacks.length
      : rating;

    await ServiceProvider.findOneAndUpdate(
      { userid: booking.providerId },
      { averageRating: avgRating, totalReviews: allFeedbacks.length }
    );

    const negativeReviews = allFeedbacks.filter(f => f.overall_rating <= 2).length;
    if (negativeReviews >= 5) {
      const providerUser = await User.findById(booking.providerId);
      if (providerUser && providerUser.role === 'Provider') {
        providerUser.isActive = false;
        await providerUser.save();
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

    await Notification.create({
      userId: booking.providerId,
      title: 'You Have Been Rated',
      message: `Client rated you ${rating} stars.${comment ? ` Comment: ${comment}` : ''}`,
      type: 'review',
      bookingId: booking._id
    });

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
    console.error('Rate provider error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Create booking request with Task and Files ====================
const createBookingRequest = async (req, res) => {
  try {
    const {
      providerId,       // هذا هو ServiceProvider._id المرسل من العميل
      serviceName,
      date,
      startTime,
      endTime,
      startTimestamp,
      endTimestamp,
      location,
      notes,
      dependantId,
      tasks
    } = req.body;
    const clientId = req.user.userId;

    // ✅ تحويل providerId من ServiceProvider._id إلى User._id
    const providerDoc = await ServiceProvider.findById(providerId).select('userid');
    if (!providerDoc) {
      return res.status(404).json({ message: 'Provider not found' });
    }
    const realProviderId = providerDoc.userid; // هذا هو User._id الحقيقي

    let tasksArray = [];
    if (tasks) {
      try {
        tasksArray = typeof tasks === 'string' ? JSON.parse(tasks) : tasks;
        if (!Array.isArray(tasksArray)) tasksArray = [];
      } catch (e) {
        tasksArray = [];
      }
    }

    let startDateTime, endDateTime;
    if (startTimestamp && endTimestamp) {
      startDateTime = new Date(parseInt(startTimestamp));
      endDateTime = new Date(parseInt(endTimestamp));
    } else if (date && startTime && endTime) {
      startDateTime = new Date(`${date}T${startTime}`);
      endDateTime = new Date(`${date}T${endTime}`);
    } else {
      return res.status(400).json({ message: 'Invalid date/time: missing either timestamps or date+time fields' });
    }

    if (isNaN(startDateTime.getTime()) || isNaN(endDateTime.getTime())) {
      return res.status(400).json({ message: 'Invalid date or time format' });
    }
    if (startDateTime >= endDateTime) {
      return res.status(400).json({ message: 'Start time must be before end time' });
    }
    if (startDateTime < new Date()) {
      return res.status(400).json({ message: 'Cannot book a time in the past' });
    }

    const task = new Task({
      name: serviceName,
      start_time: startDateTime,
      end_time: endDateTime,
      status: 'pending',
      clientId,
      providerId: realProviderId   // ✅ نستخدم User._id هنا
    });
    await task.save();

    const uploadedFiles = [];
    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        let cleanPath = file.path.replace(/\\/g, '/');
        if (!cleanPath.startsWith('/')) cleanPath = '/' + cleanPath;
        const fileDoc = new File({
          name: file.originalname,
          url: cleanPath,
          type: file.mimetype,
          size: file.size,
          taskId: task._id
        });
        await fileDoc.save();
        uploadedFiles.push(fileDoc);
      }
    }

    const bookingRequest = new BookingRequest({
      clientId,
      providerId: realProviderId,   // ✅ نستخدم User._id هنا
      serviceName,
      date: startDateTime.toISOString().split('T')[0],
      startTime: startDateTime.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }),
      endTime: endDateTime.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }),
      location,
      notes,
      dependantId,
      tasks: tasksArray,
      taskId: task._id,
      status: 'pending'
    });
    await bookingRequest.save();

    await Notification.create({
      userId: realProviderId,   // ✅ إرسال الإشعار إلى User._id
      title: 'New Booking Request',
      message: `You have a new request for ${serviceName} on ${bookingRequest.date}`,
      type: 'booking',
      bookingId: bookingRequest._id
    });

    res.status(201).json({
      message: 'Booking request sent successfully',
      requestId: bookingRequest._id,
      taskId: task._id,
      filesCount: uploadedFiles.length
    });
  } catch (error) {
    console.error('Error creating booking request:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== DEPENDENT MANAGEMENT ====================

const addDependent = async (req, res) => {
  try {
    const clientId = req.user.userId;
    const {
      fullName,
      relationship,
      gender,
      dateOfBirth,
      nationalId,
      healthConditions,
      medications,
      allergies,
      healthNotes,
      emergencyContactName,
      emergencyContactPhone,
      emergencyContactRelationship,
      bloodType,
      medicalInfoAllergies,
      medicalInfoMedications,
      medicalInfoConditions
    } = req.body;

    if (!fullName || !relationship || !dateOfBirth) {
      return res.status(400).json({ message: 'Missing required fields: fullName, relationship, dateOfBirth' });
    }

    const dependent = new Dependent({
      clientId,
      fullName,
      relationship,
      gender: gender || null,
      dateOfBirth: new Date(dateOfBirth),
      nationalId: nationalId || '',
      healthConditions: healthConditions ? (typeof healthConditions === 'string' ? JSON.parse(healthConditions) : healthConditions) : [],
      medications: medications ? (typeof medications === 'string' ? JSON.parse(medications) : medications) : [],
      allergies: allergies ? (typeof allergies === 'string' ? JSON.parse(allergies) : allergies) : [],
      healthNotes: healthNotes || '',
      emergencyContact: {
        name: emergencyContactName || '',
        phone: emergencyContactPhone || '',
        relationship: emergencyContactRelationship || ''
      },
      age: new Date().getFullYear() - new Date(dateOfBirth).getFullYear()
    });
    await dependent.save();

    if (bloodType || medicalInfoAllergies || medicalInfoMedications || medicalInfoConditions) {
      const medicalInfo = new MedicalInfo({
        dependentId: dependent._id,
        bloodType: bloodType || '',
        allergies: medicalInfoAllergies || '',
        medications: medicalInfoMedications || '',
        conditions: medicalInfoConditions || ''
      });
      await medicalInfo.save();
      dependent.medicalInfoId = medicalInfo._id;
      await dependent.save();
    }

    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        let fileType = 'general';
        if (file.fieldname === 'medicalFiles') fileType = 'medical';
        else if (file.fieldname === 'idCard') fileType = 'id_card';
        else if (file.fieldname === 'prescription') fileType = 'prescription';
        else if (file.fieldname === 'testResult') fileType = 'test_result';
        else if (req.body[`fileType_${file.originalname}`]) {
          fileType = req.body[`fileType_${file.originalname}`];
        }

        const cleanPath = file.path.replace(/\\/g, '/');
        const fileUrl = cleanPath.startsWith('/') ? cleanPath : '/' + cleanPath;

        const dependentFile = new DependentFile({
          dependentId: dependent._id,
          fileName: file.originalname,
          fileUrl: fileUrl,
          fileType: fileType,
          mimeType: file.mimetype,
          size: file.size
        });
        await dependentFile.save();
      }
    }

    await Client.findOneAndUpdate(
      { userId: clientId },
      { $push: { dependents: dependent._id } }
    );

    res.status(201).json({
      message: 'Dependent added successfully',
      dependent: {
        ...dependent.toObject(),
        medicalInfo: dependent.medicalInfoId ? await MedicalInfo.findById(dependent.medicalInfoId) : null,
        files: await DependentFile.find({ dependentId: dependent._id })
      }
    });
  } catch (error) {
    console.error('Add dependent error:', error);
    res.status(500).json({ message: error.message });
  }
};

const updateDependent = async (req, res) => {
  try {
    const { id } = req.params;
    const clientId = req.user.userId;
    const {
      fullName,
      relationship,
      gender,
      dateOfBirth,
      nationalId,
      healthConditions,
      medications,
      allergies,
      healthNotes,
      emergencyContactName,
      emergencyContactPhone,
      emergencyContactRelationship,
      bloodType,
      medicalInfoAllergies,
      medicalInfoMedications,
      medicalInfoConditions
    } = req.body;

    const dependent = await Dependent.findOne({ _id: id, clientId });
    if (!dependent) {
      return res.status(404).json({ message: 'Dependent not found' });
    }

    if (fullName) dependent.fullName = fullName;
    if (relationship) dependent.relationship = relationship;
    if (gender) dependent.gender = gender;
    if (dateOfBirth) {
      dependent.dateOfBirth = new Date(dateOfBirth);
      dependent.age = new Date().getFullYear() - new Date(dateOfBirth).getFullYear();
    }
    if (nationalId !== undefined) dependent.nationalId = nationalId;
    if (healthConditions !== undefined) {
      dependent.healthConditions = typeof healthConditions === 'string' ? JSON.parse(healthConditions) : healthConditions;
    }
    if (medications !== undefined) {
      dependent.medications = typeof medications === 'string' ? JSON.parse(medications) : medications;
    }
    if (allergies !== undefined) {
      dependent.allergies = typeof allergies === 'string' ? JSON.parse(allergies) : allergies;
    }
    if (healthNotes !== undefined) dependent.healthNotes = healthNotes;
    if (emergencyContactName || emergencyContactPhone || emergencyContactRelationship) {
      dependent.emergencyContact = {
        name: emergencyContactName || dependent.emergencyContact?.name || '',
        phone: emergencyContactPhone || dependent.emergencyContact?.phone || '',
        relationship: emergencyContactRelationship || dependent.emergencyContact?.relationship || ''
      };
    }

    await dependent.save();

    let medicalInfo = await MedicalInfo.findOne({ dependentId: dependent._id });
    if (bloodType || medicalInfoAllergies || medicalInfoMedications || medicalInfoConditions) {
      if (!medicalInfo) {
        medicalInfo = new MedicalInfo({ dependentId: dependent._id });
      }
      if (bloodType !== undefined) medicalInfo.bloodType = bloodType;
      if (medicalInfoAllergies !== undefined) medicalInfo.allergies = medicalInfoAllergies;
      if (medicalInfoMedications !== undefined) medicalInfo.medications = medicalInfoMedications;
      if (medicalInfoConditions !== undefined) medicalInfo.conditions = medicalInfoConditions;
      await medicalInfo.save();
      dependent.medicalInfoId = medicalInfo._id;
      await dependent.save();
    } else if (medicalInfo && !bloodType && !medicalInfoAllergies && !medicalInfoMedications && !medicalInfoConditions) {
      await MedicalInfo.findByIdAndDelete(medicalInfo._id);
      dependent.medicalInfoId = null;
      await dependent.save();
    }

    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        let fileType = 'general';
        if (file.fieldname === 'medicalFiles') fileType = 'medical';
        else if (file.fieldname === 'idCard') fileType = 'id_card';
        else if (file.fieldname === 'prescription') fileType = 'prescription';
        else if (file.fieldname === 'testResult') fileType = 'test_result';
        else if (req.body[`fileType_${file.originalname}`]) {
          fileType = req.body[`fileType_${file.originalname}`];
        }

        const cleanPath = file.path.replace(/\\/g, '/');
        const fileUrl = cleanPath.startsWith('/') ? cleanPath : '/' + cleanPath;

        const dependentFile = new DependentFile({
          dependentId: dependent._id,
          fileName: file.originalname,
          fileUrl: fileUrl,
          fileType: fileType,
          mimeType: file.mimetype,
          size: file.size
        });
        await dependentFile.save();
      }
    }

    res.json({
      message: 'Dependent updated successfully',
      dependent: {
        ...dependent.toObject(),
        medicalInfo: dependent.medicalInfoId ? await MedicalInfo.findById(dependent.medicalInfoId) : null,
        files: await DependentFile.find({ dependentId: dependent._id })
      }
    });
  } catch (error) {
    console.error('Update dependent error:', error);
    res.status(500).json({ message: error.message });
  }
};

const deleteDependent = async (req, res) => {
  try {
    const { id } = req.params;
    const clientId = req.user.userId;

    const dependent = await Dependent.findOne({ _id: id, clientId });
    if (!dependent) {
      return res.status(404).json({ message: 'Dependent not found' });
    }

    await DependentFile.deleteMany({ dependentId: dependent._id });

    if (dependent.medicalInfoId) {
      await MedicalInfo.findByIdAndDelete(dependent.medicalInfoId);
    }

    await Client.findOneAndUpdate(
      { userId: clientId },
      { $pull: { dependents: dependent._id } }
    );

    await Dependent.findByIdAndDelete(dependent._id);

    res.json({ message: 'Dependent and all associated data deleted successfully' });
  } catch (error) {
    console.error('Delete dependent error:', error);
    res.status(500).json({ message: error.message });
  }
};

const getDependentById = async (req, res) => {
  try {
    const { id } = req.params;
    const dependent = await Dependent.findById(id);
    if (!dependent) {
      return res.status(404).json({ message: 'Dependent not found' });
    }

    const medicalInfo = dependent.medicalInfoId ? await MedicalInfo.findById(dependent.medicalInfoId) : null;
    const files = await DependentFile.find({ dependentId: dependent._id });

    res.json({
      ...dependent.toObject(),
      medicalInfo,
      files
    });
  } catch (error) {
    console.error('Get dependent by id error:', error);
    res.status(500).json({ message: error.message });
  }
};

const getDependentFiles = async (req, res) => {
  try {
    const { id } = req.params;
    const dependent = await Dependent.findOne({ _id: id, clientId: req.user.userId });
    if (!dependent) {
      return res.status(404).json({ message: 'Dependent not found or not owned by you' });
    }

    const files = await DependentFile.find({ dependentId: dependent._id }).sort({ uploadedAt: -1 });
    res.json(files);
  } catch (error) {
    console.error('Get dependent files error:', error);
    res.status(500).json({ message: error.message });
  }
};

const deleteDependentFile = async (req, res) => {
  try {
    const { dependentId, fileId } = req.params;
    const clientId = req.user.userId;

    const dependent = await Dependent.findOne({ _id: dependentId, clientId });
    if (!dependent) {
      return res.status(404).json({ message: 'Dependent not found' });
    }

    const file = await DependentFile.findOne({ _id: fileId, dependentId });
    if (!file) {
      return res.status(404).json({ message: 'File not found' });
    }

    await DependentFile.findByIdAndDelete(fileId);
    res.json({ message: 'File deleted successfully' });
  } catch (error) {
    console.error('Delete dependent file error:', error);
    res.status(500).json({ message: error.message });
  }
};

const saveMedicalInfo = async (req, res) => {
  try {
    const { dependentId } = req.params;
    const { bloodType, allergies, medications, conditions } = req.body;
    const clientId = req.user.userId;

    const dependent = await Dependent.findOne({ _id: dependentId, clientId });
    if (!dependent) {
      return res.status(404).json({ message: 'Dependent not found' });
    }

    let medicalInfo = await MedicalInfo.findOne({ dependentId: dependent._id });
    if (!medicalInfo) {
      medicalInfo = new MedicalInfo({ dependentId: dependent._id });
    }

    if (bloodType !== undefined) medicalInfo.bloodType = bloodType;
    if (allergies !== undefined) medicalInfo.allergies = allergies;
    if (medications !== undefined) medicalInfo.medications = medications;
    if (conditions !== undefined) medicalInfo.conditions = conditions;

    await medicalInfo.save();
    dependent.medicalInfoId = medicalInfo._id;
    await dependent.save();

    res.json({ message: 'Medical info saved successfully', medicalInfo });
  } catch (error) {
    console.error('Save medical info error:', error);
    res.status(500).json({ message: error.message });
  }
};

const getMedicalInfo = async (req, res) => {
  try {
    const { dependentId } = req.params;
    const medicalInfo = await MedicalInfo.findOne({ dependentId });
    res.json(medicalInfo || {});
  } catch (error) {
    console.error('Get medical info error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== AUTHORIZED PERSONS MANAGEMENT (CORRECTED) ====================

const getAuthorizedPersons = async (req, res) => {
  try {
    const persons = await AuthorizedPerson.find({ id_U_CL: req.user.userId })
      .populate('userId', 'fullName email phoneNumber');
    res.json(persons);
  } catch (error) {
    console.error('Error fetching authorized persons:', error);
    res.status(500).json({ message: error.message });
  }
};

const addAuthorizedPerson = async (req, res) => {
  try {
    const { email, fullName, phoneNumber, relationship, password, canTrack, canChat, canViewLocation } = req.body;

    let user = await User.findOne({ email });
    if (!user) {
      if (!password || password.length < 4) {
        return res.status(400).json({ message: 'Password must be at least 4 characters' });
      }
      const account = new Account({ email, psw: await bcrypt.hash(password, 10), status: 'active', nb_receiving: 0 });
      await account.save();
      user = new User({
        fullName: fullName || email.split('@')[0],
        email,
        passwordHash: await bcrypt.hash(password, 10),
        accountEmail: email,
        phoneNumber: phoneNumber || '',
        role: 'AuthorizedPerson',
        isActive: true,
        isVerified: true
      });
      await user.save();
    } else {
      if (password && password.length >= 4) {
        const hashedPassword = await bcrypt.hash(password, 10);
        user.passwordHash = hashedPassword;
        await user.save();
        await Account.findOneAndUpdate({ email }, { psw: hashedPassword });
      }
    }

    const authorized = new AuthorizedPerson({
      id_U_CL: req.user.userId,
      userId: user._id,
      name: fullName || user.fullName,
      email,
      phone_number: phoneNumber || '',
      relationship: relationship || '',
      canTrack: canTrack ?? true,
      canChat: canChat ?? true,
      canViewLocation: canViewLocation ?? true
    });
    await authorized.save();

    const client = await User.findById(req.user.userId);
    const clientName = client ? client.fullName : 'A client';

    if (password && password.length >= 4) {
      const emailSubject = 'You have been added as an Authorized Person on CareApp';
      const emailText = `Dear ${fullName || user.fullName},\n\n` +
        `You have been added as an authorized person by ${clientName}.\n\n` +
        `Your login credentials are:\n` +
        `Email: ${email}\n` +
        `Password: ${password}\n\n` +
        `Please login to the CareApp to track services, chat, and manage appointments.\n\n` +
        `Best regards,\nCareApp Team`;
      await sendEmail(email, emailSubject, emailText);
    }

    res.status(201).json({ message: 'Authorized person added successfully', authorized });
  } catch (error) {
    console.error('Error adding authorized person:', error);
    res.status(500).json({ message: error.message });
  }
};

const deleteAuthorizedPerson = async (req, res) => {
  try {
    const { id } = req.params;
    const authorized = await AuthorizedPerson.findOneAndDelete({ _id: id, id_U_CL: req.user.userId });
    if (!authorized) {
      return res.status(404).json({ message: 'Authorized person not found' });
    }
    res.json({ message: 'Authorized person removed successfully' });
  } catch (error) {
    console.error('Error deleting authorized person:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Exports ====================
module.exports = {
  registerClient,
  getClientProfile,
  updateClientProfile,
  searchProviders,
  searchServices,
  getProviderDetails,
  createBooking,
  getClientBookings,
  rateBooking,
  getProviderAvailability,
  payRemaining,
  rateProvider,
  createBookingRequest,
  addDependent,
  updateDependent,
  deleteDependent,
  getDependentById,
  getDependentFiles,
  deleteDependentFile,
  saveMedicalInfo,
  getMedicalInfo,
  getAuthorizedPersons,
  addAuthorizedPerson,
  deleteAuthorizedPerson
};