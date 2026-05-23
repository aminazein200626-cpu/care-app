const mongoose = require('mongoose');
const User = require('../models/User');
const ServiceProvider = require('../models/ServiceProvider');
const Booking = require('../models/Booking');
const Notification = require('../models/Notification');
const Service = require('../models/Service');
const File = require('../models/File');
const Feedback = require('../models/Feedback');
const DependentFile = require('../models/DependentFile');   // ✅ Added
const MedicalInfo = require('../models/MedicalInfo');       // ✅ Added
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const BookingRequest = require('../models/BookingRequest');

function getTimeAgo(date) {
  const seconds = Math.floor((new Date() - new Date(date)) / 1000);
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return 'Yesterday';
  return `${days}d ago`;
}

// Helper: Save file to database with clean URL path
const saveFileToDatabase = async (filePath, originalName, mimeType, size, bookingId, taskId) => {
  try {
    let cleanPath = filePath.replace(/\\/g, '/');
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/' + cleanPath;
    }
    const fileDoc = new File({
      url: cleanPath,
      name: originalName,
      type: mimeType,
      size: size,
      bookingId: bookingId || null,
      taskId: taskId || null
    });
    await fileDoc.save();
    return fileDoc;
  } catch (error) {
    console.error('Error saving file to database:', error);
    return null;
  }
};

// ==================== PROVIDER REGISTRATION ====================
exports.registerProvider = async (req, res) => {
  try {
    const { fullName, email, password, phoneNumber, wilaya, municipality, address,
      nationalId, dateOfBirth, yearsOfExperience, bio, specialization, hourlyRate, services } = req.body;

    if (!fullName || !email || !password || !phoneNumber || !wilaya || !hourlyRate) {
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }
    if (password.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters' });
    }

    let existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ success: false, message: 'Email already registered' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = new User({
      fullName, email, passwordHash: hashedPassword, phoneNumber,
      role: 'Provider', isActive: true, isVerified: false, gender: 'M'
    });
    await user.save();

    const provider = new ServiceProvider({
      userid: user._id, fullName, email, phoneNumber, wilaya,
      municipality: municipality || '', address: address || '', nationalId,
      dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : null,
      yearsOfExperience: yearsOfExperience || 0, bio: bio || '',
      specialization: specialization || '', hourlyRate: parseFloat(hourlyRate),
      services: services || [], status: 'pending_verification', isVerified: false, documents: [],
      availability: '{}'
    });
    await provider.save();

    res.status(201).json({
      success: true, message: 'Registration submitted for review',
      data: { userId: user._id, providerId: provider._id, email, status: 'pending_verification' }
    });
  } catch (error) {
    console.error('Provider registration error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// ==================== PROFILE MANAGEMENT ====================
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select('-passwordHash');
    if (!user || user.role !== 'Provider') {
      return res.status(404).json({ message: 'Provider not found' });
    }
    const provider = await ServiceProvider.findOne({ userid: req.user.userId });
    if (!provider) {
      return res.json({ ...user.toObject(), providerDetails: {} });
    }
    res.json({ 
      ...user.toObject(), 
      providerDetails: {
        ...provider.toObject(),
        ccp: provider.ccp || '',
        bankAccount: provider.bankAccount || {}
      }
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.updateProfile = async (req, res) => {
  try {
    const { fullName, phoneNumber, address, wilaya, postalCode } = req.body;
    const user = await User.findById(req.user.userId);
    if (!user || user.role !== 'Provider') {
      return res.status(404).json({ message: 'Provider not found' });
    }
    if (fullName) user.fullName = fullName;
    if (phoneNumber) user.phoneNumber = phoneNumber;
    if (address) user.address = address;
    if (wilaya) user.wilaya = wilaya;
    if (postalCode) user.postalCode = postalCode;
    await user.save();
    res.json({ message: 'Profile updated successfully', user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.updateProfessionalInfo = async (req, res) => {
  try {
    const { 
      bio, hourlyRate, yearsOfExp, workHours, preferredTimeSlots, 
      travelDistance, travelCost, availableWilayas,
      ccp, bankAccount
    } = req.body;
    
    let provider = await ServiceProvider.findOne({ userid: req.user.userId });
    if (!provider) {
      provider = new ServiceProvider({ userid: req.user.userId });
    }
    
    if (bio !== undefined) provider.bio = bio;
    if (hourlyRate !== undefined) provider.hourlyRate = parseInt(hourlyRate);
    if (yearsOfExp !== undefined) provider.yearsOfExperience = parseInt(yearsOfExp);
    if (workHours !== undefined) provider.workHours = workHours;
    if (preferredTimeSlots !== undefined) provider.preferredTimeSlots = preferredTimeSlots;
    if (travelDistance !== undefined) provider.travelDistance = travelDistance;
    if (travelCost !== undefined) provider.travelCost = parseInt(travelCost);
    if (availableWilayas !== undefined) provider.availableWilayas = availableWilayas;
    
    if (ccp !== undefined) provider.ccp = ccp;
    if (bankAccount !== undefined) {
      provider.bankAccount = {
        bankName: bankAccount.bankName || '',
        accountNumber: bankAccount.accountNumber || '',
        accountHolder: bankAccount.accountHolder || '',
        rib: bankAccount.rib || ''
      };
    }
    
    await provider.save();
    res.json({ message: 'Professional info updated successfully', provider });
  } catch (error) {
    console.error('Update professional info error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== STATISTICS ====================
exports.getStats = async (req, res) => {
  try {
    const providerId = req.user.userId;
    const pendingRequests = await BookingRequest.countDocuments({ providerId, status: 'pending' });
    const completedServices = await Booking.countDocuments({ providerId, status: 'Completed' });
    const startOfMonth = new Date(); startOfMonth.setDate(1); startOfMonth.setHours(0,0,0,0);
    const monthlyEarningsResult = await Booking.aggregate([
      { $match: { providerId: new mongoose.Types.ObjectId(providerId), status: 'Completed', paidAt: { $gte: startOfMonth } } },
      { $group: { _id: null, total: { $sum: '$totalPrice' } } }
    ]);
    const monthlyEarnings = monthlyEarningsResult[0]?.total || 0;
    const avgRatingResult = await Feedback.aggregate([
      { $match: { providerId: new mongoose.Types.ObjectId(providerId) } },
      { $group: { _id: null, avg: { $avg: '$overall_rating' } } }
    ]);
    const rating = avgRatingResult[0]?.avg.toFixed(1) || 0;
    const last7Days = [];
    for (let i = 6; i >= 0; i--) {
      const date = new Date(); date.setDate(date.getDate() - i); date.setHours(0,0,0,0);
      last7Days.push(date);
    }
    const weeklyBookings = [];
    for (const date of last7Days) {
      const nextDate = new Date(date); nextDate.setDate(date.getDate() + 1);
      const count = await Booking.countDocuments({ providerId, createdAt: { $gte: date, $lt: nextDate } });
      weeklyBookings.push(count);
    }
    res.json({ pendingRequests, completedServices, monthlyEarnings, rating, weeklyBookings });
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== SERVICES ====================
exports.getServices = async (req, res) => {
  try {
    const services = await Service.find({ isActive: true }).select('_id name price');
    res.json(services);
  } catch (error) {
    console.error('Error fetching services:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== BOOKINGS ====================
exports.getBookings = async (req, res) => {
  try {
    const providerId = req.user.userId;
    const bookings = await Booking.find({ providerId })
      .populate('clientId', 'fullName email phoneNumber')
      .populate('serviceId', 'name price')
      .sort({ createdAt: -1 });
    const formattedBookings = bookings.map(booking => ({
      id: booking._id, client: booking.clientId?.fullName || 'Unknown',
      clientPhone: booking.clientId?.phoneNumber || '', service: booking.serviceId?.name || '',
      date: booking.date, time: booking.startTime, status: booking.status,
      price: booking.totalPrice, dependent: booking.dependentId, notes: booking.notes
    }));
    res.json(formattedBookings);
  } catch (error) {
    console.error('Get bookings error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.getBookingDetails = async (req, res) => {
  try {
    const { id } = req.params;
    const providerId = req.user.userId;
    if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ message: 'Invalid booking ID' });
    
    const booking = await Booking.findOne({ _id: id, providerId })
      .populate('clientId', 'fullName phoneNumber address wilaya latitude longitude')
      .populate('serviceId', 'name price')
      .populate('dependentId');
      
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    
    let dependentInfo = null;
    if (booking.dependentId) {
      const files = await DependentFile.find({ dependentId: booking.dependentId._id });
      const medicalInfo = booking.dependentId.medicalInfoId 
        ? await MedicalInfo.findById(booking.dependentId.medicalInfoId)
        : null;
      
      dependentInfo = {
        id: booking.dependentId._id,
        name: booking.dependentId.fullName,
        relationship: booking.dependentId.relationship,
        age: booking.dependentId.dateOfBirth ? new Date().getFullYear() - new Date(booking.dependentId.dateOfBirth).getFullYear() : 'N/A',
        healthNotes: booking.dependentId.healthNotes || 'No health notes',
        files: files || [],
        medicalInfo: medicalInfo || {}
      };
    }

    let clientLat = 36.7538;
    let clientLng = 3.0588;
    if (booking.clientId && booking.clientId.latitude && booking.clientId.longitude) {
      clientLat = booking.clientId.latitude;
      clientLng = booking.clientId.longitude;
    }

    // ✅ أضف clientId هنا
    res.json({
      id: booking._id,
      client: booking.clientId?.fullName || 'Unknown',
      clientId: booking.clientId?._id,           // ✅ هذا هو التعديل المطلوب
      clientPhone: booking.clientId?.phoneNumber || '',
      service: booking.serviceId?.name || booking.service,
      date: booking.date,
      time: booking.startTime,
      location: booking.location,
      status: booking.status,
      price: booking.totalPrice,
      notes: booking.notes,
      dependent: dependentInfo,
      clientTasks: booking.clientTasks || [],
      trackingStage: booking.trackingStage || 'Pending',
      stageTimes: booking.stageTimes || {},
      clientLat,
      clientLng,
      providerLat: booking.providerLat,
      providerLng: booking.providerLng,
      halfPaid: booking.halfPaid,
      halfAmount: booking.halfAmount,
      remainingAmount: booking.remainingAmount,
      paymentStatus: booking.paymentStatus
    });
  } catch (error) {
    console.error('Get booking details error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.acceptBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const booking = await Booking.findById(id);
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    booking.status = 'In Progress';
    await booking.save();
    if (booking.clientId) {
      await Notification.create({ userId: booking.clientId, title: 'Booking Confirmed', message: 'Your booking has been confirmed and is now in progress', type: 'booking' });
    }
    res.json({ message: `Booking ${id} accepted successfully`, booking });
  } catch (error) {
    console.error('Accept booking error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.rejectBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const booking = await Booking.findById(id);
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    booking.status = 'Cancelled';
    await booking.save();
    if (booking.clientId) {
      await Notification.create({ userId: booking.clientId, title: 'Booking Rejected', message: 'Your booking has been rejected', type: 'booking' });
    }
    res.json({ message: `Booking ${id} rejected successfully` });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ==================== AVAILABILITY ====================
exports.getAvailability = async (req, res) => {
  try {
    const user = await User.findById(req.user.userId);
    if (!user) return res.json({});

    let provider = await ServiceProvider.findOne({ userid: req.user.userId });
    if (!provider) {
      provider = await ServiceProvider.findOne({ email: user.email });
    }

    if (!provider) return res.json({});

    let availability = {};
    if (provider.availability) {
      if (typeof provider.availability === 'string') {
        try { availability = JSON.parse(provider.availability); } catch (e) { availability = {}; }
      } else {
        availability = provider.availability;
      }
    }

    res.json(availability);
  } catch (error) {
    console.error('getAvailability error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.addAvailability = async (req, res) => {
  try {
    const { date, startTime, endTime } = req.body;
    if (!date || !startTime || !endTime) {
      return res.status(400).json({ message: 'Date, startTime, endTime are required' });
    }

    const user = await User.findById(req.user.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    let provider = await ServiceProvider.findOne({ userid: req.user.userId });
    if (!provider) {
      provider = await ServiceProvider.findOne({ email: user.email });
    }

    if (!provider) {
      provider = new ServiceProvider({
        userid: req.user.userId, email: user.email, fullName: user.fullName || 'Provider',
        phoneNumber: user.phoneNumber || '', wilaya: user.wilaya || '',
        address: user.address || '', hourlyRate: 1000, availability: '{}',
        status: 'active', isVerified: true
      });
      await provider.save();
    }

    let availability = {};
    if (provider.availability) {
      if (typeof provider.availability === 'string') {
        try { availability = JSON.parse(provider.availability); } catch (e) { availability = {}; }
      } else {
        availability = provider.availability;
      }
    }

    if (!availability[date]) availability[date] = [];
    const exists = availability[date].some(slot => slot.startTime === startTime);
    if (exists) return res.status(400).json({ message: 'Time slot already exists' });

    availability[date].push({ startTime, endTime, isBooked: false });
    availability[date].sort((a, b) => a.startTime.localeCompare(b.startTime));

    provider.availability = JSON.stringify(availability);
    await provider.save();

    res.status(201).json({ message: 'Availability added successfully', slot: { date, startTime, endTime } });
  } catch (error) {
    console.error('addAvailability error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.deleteAvailability = async (req, res) => {
  try {
    const { date, startTime } = req.body;
    if (!date || !startTime) {
      return res.status(400).json({ message: 'Date and startTime are required' });
    }

    const user = await User.findById(req.user.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    let provider = await ServiceProvider.findOne({ userid: req.user.userId });
    if (!provider) provider = await ServiceProvider.findOne({ email: user.email });
    if (!provider) return res.status(404).json({ message: 'Provider not found' });

    let availability = {};
    if (provider.availability) {
      if (typeof provider.availability === 'string') {
        try { availability = JSON.parse(provider.availability); } catch (e) { availability = {}; }
      } else {
        availability = provider.availability;
      }
    }

    if (availability[date]) {
      availability[date] = availability[date].filter(slot => slot.startTime !== startTime);
      if (availability[date].length === 0) delete availability[date];
    }

    provider.availability = JSON.stringify(availability);
    await provider.save();
    res.json({ message: 'Slot deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ==================== TRACKING ====================
exports.getTrackingInfo = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const providerId = req.user.userId;
    if (!mongoose.Types.ObjectId.isValid(bookingId)) return res.status(400).json({ message: 'Invalid booking ID' });
    const booking = await Booking.findOne({ _id: bookingId, providerId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    res.json({
      stage: booking.trackingStage || 'Pending', status: booking.status,
      workSteps: booking.workSteps || [], attachments: booking.attachments || [],
      stageTimes: booking.stageTimes || {}, eta: booking.eta,
      locationLat: booking.providerLat, locationLng: booking.providerLng, lastUpdate: booking.updatedAt
    });
  } catch (error) {
    console.error('Get tracking info error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.updateTracking = async (req, res) => {
  try {
    const { bookingId, stage, locationLat, locationLng, workStep, attachment } = req.body;
    const providerId = req.user.userId;
    const booking = await Booking.findOne({ _id: bookingId, providerId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    
    if (stage && stage !== booking.trackingStage) {
      const stageTimes = booking.stageTimes || {};
      const now = new Date();
      stageTimes[stage] = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
      booking.stageTimes = stageTimes;
      booking.trackingStage = stage;
      
      await Notification.create({
        userId: booking.clientId,
        title: 'Service Update',
        message: `Service stage updated to: ${stage}`,
        type: 'tracking',
        bookingId: booking._id
      });
    }
    
    if (locationLat !== undefined) booking.providerLat = locationLat;
    if (locationLng !== undefined) booking.providerLng = locationLng;
    
    if (workStep && workStep.description) {
      const workSteps = booking.workSteps || [];
      workSteps.push({ 
        description: workStep.description, note: workStep.note || '',
        fileUrl: workStep.fileUrl || null,
        time: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
      });
      booking.workSteps = workSteps;
    }
    
    if (attachment && attachment.type) {
      const attachments = booking.attachments || [];
      attachments.push({ 
        type: attachment.type, url: attachment.url || '', caption: attachment.caption || '',
        time: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
      });
      booking.attachments = attachments;
    }
    
    if (stage === 'Completed') {
      booking.status = 'Completed';
      await Notification.create({
        userId: booking.clientId,
        title: 'Service Completed',
        message: `Your service has been completed. Please pay the remaining amount (${booking.remainingAmount} DZD) and rate the provider.`,
        type: 'payment',
        bookingId: booking._id
      });
      await Notification.create({
        userId: booking.providerId,
        title: 'Service Completed',
        message: `You have marked the service as completed. Waiting for client to pay remaining amount and rate you.`,
        type: 'tracking',
        bookingId: booking._id
      });
    }
    
    await booking.save();
    
    const io = req.app.get('io');
    if (io) {
      io.to(`tracking_${bookingId}`).emit('trackingUpdate', {
        bookingId, stage: booking.trackingStage,
        providerLat: booking.providerLat, providerLng: booking.providerLng,
        stageTimes: booking.stageTimes, workSteps: booking.workSteps,
        attachments: booking.attachments, clientTasks: booking.clientTasks
      });
    }
    
    res.json({ message: `Tracking updated` });
  } catch (error) {
    console.error('Update tracking error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== WORK STEPS & ATTACHMENTS ====================
exports.addWorkStep = async (req, res) => {
  try {
    const { bookingId, description, note } = req.body;
    const providerId = req.user.userId;
    if (!mongoose.Types.ObjectId.isValid(bookingId)) return res.status(400).json({ message: 'Invalid booking ID' });
    const booking = await Booking.findOne({ _id: bookingId, providerId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    const workSteps = booking.workSteps || [];
    const now = new Date();
    workSteps.push({ description, note: note || '', time: now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) });
    booking.workSteps = workSteps;
    await booking.save();
    res.json({ message: "Work step added successfully", workStep: workSteps[workSteps.length - 1] });
  } catch (error) {
    console.error('Add work step error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.addAttachment = async (req, res) => {
  try {
    const { bookingId, type, fileUrl, caption } = req.body;
    const providerId = req.user.userId;
    if (!mongoose.Types.ObjectId.isValid(bookingId)) return res.status(400).json({ message: 'Invalid booking ID' });
    const booking = await Booking.findOne({ _id: bookingId, providerId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    const attachments = booking.attachments || [];
    const now = new Date();
    attachments.push({ type, url: fileUrl, caption: caption || '', time: now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) });
    booking.attachments = attachments;
    await booking.save();
    res.json({ message: "Attachment added successfully", attachment: attachments[attachments.length - 1] });
  } catch (error) {
    console.error('Add attachment error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.addWorkStepWithFile = async (req, res) => {
  try {
    const { bookingId, description, note } = req.body;
    const providerId = req.user.userId;
    if (!mongoose.Types.ObjectId.isValid(bookingId)) return res.status(400).json({ message: 'Invalid booking ID' });
    const booking = await Booking.findOne({ _id: bookingId, providerId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    
    let fileUrl = null;
    let savedFile = null;
    if (req.file) {
      let cleanFileName = req.file.filename.replace(/\\/g, '/');
      fileUrl = `/uploads/worksteps/${cleanFileName}`;
      savedFile = await saveFileToDatabase(
        fileUrl,
        req.file.originalname,
        req.file.mimetype,
        req.file.size,
        bookingId,
        booking.taskId || null
      );
    }
    
    const workSteps = booking.workSteps || [];
    const now = new Date();
    const timeStr = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
    const newStep = { 
      description, 
      note: note || '', 
      time: timeStr, 
      timestamp: now.toISOString(), 
      fileUrl,
      fileId: savedFile?._id || null
    };
    workSteps.push(newStep);
    booking.workSteps = workSteps;
    await booking.save();
    
    const io = req.app.get('io');
    if (io) {
      io.to(`tracking_${bookingId}`).emit('newWorkStep', { 
        bookingId, description, note: note || '', fileUrl, timestamp: now.toISOString() 
      });
    }
    
    await Notification.create({ 
      userId: booking.clientId, 
      title: 'Work Progress Update', 
      message: description.length > 50 ? description.substring(0,50)+'...' : description, 
      type: 'tracking', 
      bookingId: booking._id 
    });
    
    res.json({ message: 'Work step added', workStep: newStep, file: savedFile });
  } catch (error) {
    console.error('Add work step with file error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.uploadAttachment = async (req, res) => {
  try {
    const { bookingId, caption } = req.body;
    const providerId = req.user.userId;
    if (!req.file) return res.status(400).json({ message: 'No file uploaded' });
    if (!mongoose.Types.ObjectId.isValid(bookingId)) return res.status(400).json({ message: 'Invalid booking ID' });
    
    const booking = await Booking.findOne({ _id: bookingId, providerId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    
    let cleanFileName = req.file.filename.replace(/\\/g, '/');
    const fileUrl = `/uploads/attachments/${cleanFileName}`;
    let fileType = 'file';
    if (req.file.mimetype.startsWith('image/')) fileType = 'image';
    else if (req.file.mimetype.startsWith('video/')) fileType = 'video';
    else if (req.file.mimetype.startsWith('audio/')) fileType = 'audio';
    
    const savedFile = await saveFileToDatabase(
      fileUrl,
      req.file.originalname,
      req.file.mimetype,
      req.file.size,
      bookingId,
      booking.taskId || null
    );
    
    const attachments = booking.attachments || [];
    const now = new Date();
    const newAtt = { 
      type: fileType, 
      url: fileUrl, 
      caption: caption || '', 
      time: now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }), 
      timestamp: now.toISOString(),
      fileId: savedFile?._id || null
    };
    attachments.push(newAtt);
    booking.attachments = attachments;
    await booking.save();
    
    const io = req.app.get('io');
    if (io) {
      io.to(`tracking_${bookingId}`).emit('newAttachment', { 
        bookingId, type: fileType, caption: caption || '', url: fileUrl, timestamp: now.toISOString() 
      });
    }
    
    await Notification.create({ 
      userId: booking.clientId, 
      title: 'New Attachment', 
      message: `Provider added a ${fileType}${caption ? ': ' + caption : ''}`, 
      type: 'tracking', 
      bookingId: booking._id 
    });
    
    res.json({ message: 'Attachment uploaded', attachment: newAtt, file: savedFile });
  } catch (error) {
    console.error('Upload attachment error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.updateLocation = async (req, res) => {
  try {
    const { bookingId, lat, lng } = req.body;
    const providerId = req.user.userId;
    if (!mongoose.Types.ObjectId.isValid(bookingId)) return res.status(400).json({ message: 'Invalid booking ID' });
    const booking = await Booking.findOne({ _id: bookingId, providerId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    booking.providerLat = lat;
    booking.providerLng = lng;
    booking.lastUpdate = new Date();
    await booking.save();
    
    const io = req.app.get('io');
    if (io) io.to(`tracking_${bookingId}`).emit('locationUpdate', { lat, lng });
    res.json({ message: 'Location updated', lat, lng });
  } catch (error) {
    console.error('Update location error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== CLIENT TASKS ====================
exports.updateClientTaskStatus = async (req, res) => {
  try {
    const { bookingId, taskIndex } = req.params;
    const { status, note } = req.body;
    const providerId = req.user.userId;
    if (!mongoose.Types.ObjectId.isValid(bookingId)) return res.status(400).json({ message: 'Invalid booking ID' });
    
    const booking = await Booking.findOne({ _id: bookingId, providerId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    
    const idx = parseInt(taskIndex);
    if (isNaN(idx) || !booking.clientTasks || !booking.clientTasks[idx]) return res.status(404).json({ message: 'Task not found' });
    
    booking.clientTasks[idx].status = status;
    if (note) booking.clientTasks[idx].providerNote = note;
    await booking.save();
    
    await Notification.create({ 
      userId: booking.clientId, 
      title: 'Task Update', 
      message: `Provider marked "${booking.clientTasks[idx].taskName}" as ${status}${note ? ': ' + note : ''}`, 
      type: 'tracking', 
      bookingId: booking._id 
    });
    
    const io = req.app.get('io');
    if (io) {
      io.to(`tracking_${bookingId}`).emit('taskUpdate', { 
        bookingId, taskIndex: idx, status, note: note || '', taskName: booking.clientTasks[idx].taskName 
      });
    }
    
    res.json({ message: 'Task status updated', task: booking.clientTasks[idx], taskIndex: idx });
  } catch (error) {
    console.error('Update client task error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.getClientTasks = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) return res.status(400).json({ message: 'Invalid booking ID' });
    const booking = await Booking.findOne({ _id: id, providerId: req.user.userId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    res.json({ halfPaid: booking.halfPaid || false, halfPaidAt: booking.halfPaidAt, halfAmount: booking.halfAmount || 0, remainingAmount: booking.remainingAmount || 0, clientTasks: booking.clientTasks || [], clientTasksSubmittedAt: booking.clientTasksSubmittedAt });
  } catch (error) {
    console.error('Get client tasks error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== EARNINGS & PAYMENTS ====================
exports.getEarnings = async (req, res) => {
  try {
    const providerId = req.user.userId;
    const objectIdProvider = new mongoose.Types.ObjectId(providerId);
    const halfPaymentsTotal = await Booking.aggregate([{ $match: { providerId: objectIdProvider, halfPaid: true } }, { $group: { _id: null, total: { $sum: '$halfAmount' } } }]);
    const completedTotal = await Booking.aggregate([{ $match: { providerId: objectIdProvider, status: 'Completed' } }, { $group: { _id: null, total: { $sum: '$totalPrice' } } }]);
    const total = (halfPaymentsTotal[0]?.total || 0) + (completedTotal[0]?.total || 0);
    const startOfMonth = new Date(); startOfMonth.setDate(1); startOfMonth.setHours(0,0,0,0);
    const halfMonthly = await Booking.aggregate([{ $match: { providerId: objectIdProvider, halfPaid: true, halfPaidAt: { $gte: startOfMonth } } }, { $group: { _id: null, total: { $sum: '$halfAmount' } } }]);
    const completedMonthly = await Booking.aggregate([{ $match: { providerId: objectIdProvider, status: 'Completed', paidAt: { $gte: startOfMonth } } }, { $group: { _id: null, total: { $sum: '$totalPrice' } } }]);
    const monthly = (halfMonthly[0]?.total || 0) + (completedMonthly[0]?.total || 0);
    const startOfWeek = new Date(); startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay()); startOfWeek.setHours(0,0,0,0);
    const halfWeekly = await Booking.aggregate([{ $match: { providerId: objectIdProvider, halfPaid: true, halfPaidAt: { $gte: startOfWeek } } }, { $group: { _id: null, total: { $sum: '$halfAmount' } } }]);
    const completedWeekly = await Booking.aggregate([{ $match: { providerId: objectIdProvider, status: 'Completed', paidAt: { $gte: startOfWeek } } }, { $group: { _id: null, total: { $sum: '$totalPrice' } } }]);
    const weekly = (halfWeekly[0]?.total || 0) + (completedWeekly[0]?.total || 0);
    const startOfDay = new Date(); startOfDay.setHours(0,0,0,0);
    const halfToday = await Booking.aggregate([{ $match: { providerId: objectIdProvider, halfPaid: true, halfPaidAt: { $gte: startOfDay } } }, { $group: { _id: null, total: { $sum: '$halfAmount' } } }]);
    const completedToday = await Booking.aggregate([{ $match: { providerId: objectIdProvider, status: 'Completed', paidAt: { $gte: startOfDay } } }, { $group: { _id: null, total: { $sum: '$totalPrice' } } }]);
    const today = (halfToday[0]?.total || 0) + (completedToday[0]?.total || 0);
    const pendingResult = await Booking.aggregate([{ $match: { providerId: objectIdProvider, paymentStatus: 'Pending' } }, { $group: { _id: null, total: { $sum: '$totalPrice' } } }]);
    const pending = pendingResult[0]?.total || 0;
    res.json({ total, monthly, weekly, today, pending });
  } catch (error) {
    console.error('Get earnings error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.getPaymentHistory = async (req, res) => {
  try {
    const providerId = req.user.userId;
    const payments = await Booking.find({ providerId, paymentStatus: 'Completed' }).populate('clientId', 'fullName').populate('serviceId', 'name').sort({ paidAt: -1 });
    const history = payments.map(p => ({ id: p._id, client: p.clientId?.fullName, service: p.serviceId?.name, amount: p.totalPrice, date: p.paidAt ? new Date(p.paidAt).toISOString().split('T')[0] : '', status: p.paymentStatus, paymentMethod: p.paymentMethod }));
    res.json(history);
  } catch (error) {
    console.error('Get payment history error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.getHalfPayments = async (req, res) => {
  try {
    const providerId = req.user.userId;
    const bookings = await Booking.find({ providerId, halfPaid: true, paymentStatus: 'HalfPaid' }).populate('clientId', 'fullName phoneNumber').populate('serviceId', 'name').sort({ createdAt: -1 });
    const halfPayments = bookings.map(booking => ({
      id: booking._id, clientId: booking.clientId?._id, clientName: booking.clientId?.fullName,
      clientPhone: booking.clientId?.phoneNumber, bookingId: booking._id, service: booking.serviceId?.name || booking.service,
      amount: booking.halfAmount, date: booking.halfPaidAt ? new Date(booking.halfPaidAt).toISOString().split('T')[0] : new Date(booking.createdAt).toISOString().split('T')[0],
      paymentMethod: booking.paymentMethod, status: booking.paymentStatus
    }));
    res.json(halfPayments);
  } catch (error) {
    console.error('Get half payments error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== WITHDRAWALS ====================
exports.requestWithdrawal = async (req, res) => {
  try {
    const { amount, method, accountDetails } = req.body;
    const validMethods = ['Edahabia', 'Bank Transfer', 'Cash'];
    if (!validMethods.includes(method)) return res.status(400).json({ message: 'Invalid payment method' });
    if (!amount || amount <= 0) return res.status(400).json({ message: 'Invalid amount' });
    res.status(201).json({ message: "Withdrawal request submitted", withdrawal: { amount, method, accountDetails, status: 'Pending', requestedAt: new Date() } });
  } catch (error) {
    console.error('Request withdrawal error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.getWithdrawals = async (req, res) => {
  try {
    res.json([]);
  } catch (error) {
    console.error('Get withdrawals error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== CALL HISTORY ====================
exports.getCallHistory = async (req, res) => {
  try {
    res.json([]);
  } catch (error) {
    console.error('Get call history error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== USER BLOCKING ====================
exports.blockUser = async (req, res) => {
  try {
    const { userId } = req.params;
    if (userId === req.user.userId) return res.status(400).json({ message: 'Cannot block yourself' });
    res.json({ message: 'User blocked successfully' });
  } catch (error) {
    console.error('Block user error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.unblockUser = async (req, res) => {
  try {
    res.json({ message: 'User unblocked successfully' });
  } catch (error) {
    console.error('Unblock user error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.getBlockedUsers = async (req, res) => {
  try {
    res.json([]);
  } catch (error) {
    console.error('Get blocked users error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== ACCOUNT DELETION ====================
exports.deleteAccount = async (req, res) => {
  try {
    const userId = req.user.userId;
    const user = await User.findByIdAndDelete(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    await ServiceProvider.findOneAndDelete({ userid: userId });
    res.json({ message: 'Account deleted successfully' });
  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== NOTIFICATIONS ====================
exports.createNotification = async (req, res) => {
  try {
    const { title, message, type } = req.body;
    if (!title || !message) return res.status(400).json({ message: 'Title and message are required' });
    const notification = new Notification({ userId: req.user.userId, title, message, type: type || 'system', isRead: false });
    await notification.save();
    res.status(201).json({ message: 'Notification created successfully', notification: { id: notification._id, title, message, time: getTimeAgo(notification.createdAt), isRead: false, type: notification.type } });
  } catch (error) {
    console.error('Error creating notification:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.getNotifications = async (req, res) => {
  try {
    const notifications = await Notification.find({ userId: req.user.userId }).sort({ createdAt: -1 });
    const formatted = notifications.map(n => ({ id: n._id, title: n.title, message: n.message, time: getTimeAgo(n.createdAt), isRead: n.isRead, type: n.type }));
    res.json(formatted);
  } catch (error) {
    console.error('Error in getNotifications:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.markNotificationRead = async (req, res) => {
  try {
    const { id } = req.params;
    await Notification.findByIdAndUpdate(id, { isRead: true });
    res.json({ message: 'Notification marked as read' });
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.deleteNotification = async (req, res) => {
  try {
    const { id } = req.params;
    await Notification.findByIdAndDelete(id);
    res.json({ message: 'Notification deleted' });
  } catch (error) {
    console.error('Error deleting notification:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== REVIEWS (using Feedback model) ====================
exports.getReviews = async (req, res) => {
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
      date: f.createdAt.toISOString().split('T')[0],
      service: f.bookingId?.service || 'Service',
      replied: !!f.reply
    }));

    res.json(formatted);
  } catch (error) {
    console.error('Get reviews error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.replyToReview = async (req, res) => {
  try {
    const { id } = req.params;
    const { reply } = req.body;
    const providerId = req.user.userId;

    if (!reply) {
      return res.status(400).json({ message: 'Reply message is required' });
    }

    const feedback = await Feedback.findById(id);
    if (!feedback) {
      return res.status(404).json({ message: 'Review not found' });
    }

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
};

// ==================== RATE CLIENT ====================
exports.rateClient = async (req, res) => {
  try {
    const { id } = req.params;
    const { rating, comment } = req.body;
    const providerId = req.user.userId;
    if (!rating || rating < 1 || rating > 5) return res.status(400).json({ message: 'Rating must be between 1 and 5' });
    const booking = await Booking.findOne({ _id: id, providerId });
    if (!booking) return res.status(404).json({ message: 'Booking not found' });
    if (booking.paymentStatus !== 'Completed') return res.status(400).json({ message: 'Payment must be completed first' });
    if (booking.clientRating) return res.status(400).json({ message: 'Already rated this client' });
    booking.clientRating = rating;
    booking.clientFeedback = comment || '';
    await booking.save();
    const allClientRatings = await Booking.find({ clientId: booking.clientId, clientRating: { $exists: true, $ne: null } });
    const negativeClientRatings = allClientRatings.filter(b => b.clientRating <= 2).length;
    if (negativeClientRatings >= 5) {
      const clientUser = await User.findById(booking.clientId);
      if (clientUser && clientUser.role === 'Client') {
        clientUser.isActive = false;
        await clientUser.save();
        await Notification.create({ userId: booking.clientId, title: 'Account Suspended', message: 'Your account has been suspended due to 5 negative reviews from providers.', type: 'system' });
        const admin = await User.findOne({ role: 'Admin' });
        if (admin) await Notification.create({ userId: admin._id, title: 'Client Auto-Blocked', message: `${clientUser.fullName} has been blocked due to 5 negative reviews.`, type: 'system' });
      }
    }
    await Notification.create({ userId: booking.clientId, title: 'You Have Been Rated', message: `${booking.provider} rated you ${rating} stars.`, type: 'review_request', bookingId: booking._id });
    res.json({ success: true, message: 'Client rating submitted' });
  } catch (error) {
    console.error('Rate client error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== PROFILE PICTURE ====================
exports.uploadProfilePicture = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'No file uploaded' });
    const profilePictureUrl = `/uploads/profiles/${req.file.filename.replace(/\\/g, '/')}`;
    await User.findByIdAndUpdate(req.user.userId, { profilePicture: profilePictureUrl });
    res.json({ message: 'Profile picture uploaded successfully', profilePicture: profilePictureUrl });
  } catch (error) {
    console.error('Upload profile picture error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== ADS ====================
exports.getMyAds = async (req, res) => {
  try {
    res.json([]);
  } catch (error) {
    console.error('Get my ads error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.createAd = async (req, res) => {
  try {
    const { title, serviceId, description, specialOffer, budget, duration } = req.body;
    if (!title || !serviceId || !budget) return res.status(400).json({ message: 'Title, serviceId, and budget are required' });
    res.status(201).json({ message: "Ad created successfully" });
  } catch (error) {
    console.error('Create ad error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.pauseAd = async (req, res) => {
  try {
    const { id } = req.params;
    res.json({ message: `Ad ${id} paused successfully` });
  } catch (error) {
    console.error('Pause ad error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== COMPLAINTS ====================
exports.fileComplaint = async (req, res) => {
  try {
    const { clientId, subject, description } = req.body;
    if (!clientId || !subject) return res.status(400).json({ message: 'Client ID and subject are required' });
    res.status(201).json({ message: "Complaint filed successfully" });
  } catch (error) {
    console.error('File complaint error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== EMIT FULL TRACKING UPDATE ====================
exports.emitFullTrackingUpdate = async (bookingId, req) => {
  try {
    const booking = await Booking.findById(bookingId);
    if (!booking) return;
    const io = req?.app?.get('io');
    if (io) {
      io.to(`tracking_${bookingId}`).emit('trackingUpdate', {
        bookingId, stage: booking.trackingStage, providerLat: booking.providerLat, providerLng: booking.providerLng,
        stageTimes: booking.stageTimes, workSteps: booking.workSteps, attachments: booking.attachments,
        clientTasks: booking.clientTasks, status: booking.status
      });
    }
  } catch (error) {
    console.error('Error emitting tracking update:', error);
  }
};

// ==================== EXPORTS ====================
module.exports = exports;