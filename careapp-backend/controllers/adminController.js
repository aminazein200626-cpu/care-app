const mongoose = require('mongoose');
const User = require('../models/User');
const Category = require('../models/Category');
const Service = require('../models/Service');
const Booking = require('../models/Booking');
const ServiceProvider = require('../models/ServiceProvider');
const Report = require('../models/Report');
const Account = require('../models/Account');
const InscriptionRequest = require('../models/InscriptionRequest');
const Notification = require('../models/Notification');
const nodemailer = require('nodemailer');

// ==================== Helper: Send Email ====================
const sendEmail = async (to, subject, text) => {
  const transporter = nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 587,
    secure: false,
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });

  const mailOptions = {
    from: `"CareApp Support" <${process.env.EMAIL_USER}>`,
    to: to,
    subject: subject,
    text: text,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`✅ Email sent to ${to}`);
  } catch (error) {
    console.error(`❌ Error sending email to ${to}:`, error.message);
  }
};

// ==================== User Management ====================
const getAllUsers = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const users = await User.find()
      .select('-passwordHash')
      .skip(skip)
      .limit(limit)
      .sort({ createdAt: -1 });

    const total = await User.countDocuments();

    res.json({
      users,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const getUserById = async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-passwordHash');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const toggleBlockUser = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (user.role === 'Admin') {
      return res.status(403).json({ message: 'Cannot block an admin user' });
    }

    const newStatus = !user.isActive;
    user.isActive = newStatus;
    await user.save();

    res.json({
      message: `User ${newStatus ? 'activated' : 'blocked'} successfully`,
      isActive: newStatus,
    });
  } catch (error) {
    console.error('Toggle block error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Provider Requests ====================
const getPendingRequests = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const pendingProviders = await User.find({
      role: 'Provider',
      isVerified: false,
    })
      .select('-passwordHash')
      .skip(skip)
      .limit(limit)
      .sort({ createdAt: -1 });

    const results = [];
    for (const provider of pendingProviders) {
      let providerDetails = await ServiceProvider.findOne({ userid: provider._id });
      results.push({
        ...provider.toObject(),
        providerDetails: providerDetails ? providerDetails.toObject() : {},
      });
    }

    const total = await User.countDocuments({
      role: 'Provider',
      isVerified: false,
    });

    res.json({
      requests: results,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (error) {
    console.error('Error in getPendingRequests:', error);
    res.status(500).json({ message: error.message });
  }
};

const verifyProvider = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, rejectionReason } = req.body;

    const user = await User.findById(id);
    if (!user || user.role !== 'Provider') {
      return res.status(404).json({ message: 'Provider not found' });
    }

    const isApproved = status === 'approved';

    // 1. Update User
    user.isVerified = isApproved;
    user.verifiedAt = new Date();
    await user.save();

    // 2. Update ServiceProvider
    const provider = await ServiceProvider.findOne({ userid: id });
    if (provider) {
      provider.isVerified = isApproved;
      provider.status = isApproved ? 'active' : 'rejected';
      if (!isApproved && rejectionReason) {
        provider.rejectionReason = rejectionReason;
      }
      await provider.save();
    }

    // 3. Update InscriptionRequest
    if (provider) {
      const existingRequest = await InscriptionRequest.findOne({ providerId: provider._id });
      if (existingRequest) {
        existingRequest.status = isApproved ? 'approved' : 'rejected';
        existingRequest.adminId = req.user.userId;
        await existingRequest.save();
      } else {
        const newRequest = new InscriptionRequest({
          providerId: provider._id,
          adminId: req.user.userId,
          status: isApproved ? 'approved' : 'rejected',
          submitted_at: new Date(),
        });
        await newRequest.save();
      }
    }

    // 4. Send in-app notification
    await Notification.create({
      userId: id,
      title: isApproved ? '✅ Provider Application Approved' : '❌ Provider Application Rejected',
      message: isApproved
        ? 'Congratulations! Your provider application has been approved. You can now log in and start receiving bookings.'
        : `Your provider application has been rejected. Reason: ${rejectionReason || 'Please contact support for more information.'}`,
      type: 'system',
    });

    // 5. Send email
    try {
      const emailSubject = isApproved ? '🎉 Provider Application Approved!' : '❌ Provider Application Rejected';
      const emailText = isApproved
        ? `Congratulations ${user.fullName},\n\nYour provider application has been approved. You can now log in to your CareApp provider account and start receiving bookings.\n\nBest regards,\nCareApp Team`
        : `Dear ${user.fullName},\n\nYour provider application has been rejected.\nReason: ${rejectionReason || 'Please contact support for more information.'}\n\nBest regards,\nCareApp Team`;
      await sendEmail(user.email, emailSubject, emailText);
    } catch (emailErr) {
      console.error('Email sending error:', emailErr.message);
    }

    res.json({
      message: `Provider ${status} successfully`,
      isVerified: user.isVerified,
    });
  } catch (error) {
    console.error('Verify provider error:', error);
    res.status(500).json({ message: error.message });
  }
};

const updateProviderDocuments = async (req, res) => {
  try {
    const { id } = req.params;
    const { documents } = req.body;

    const user = await User.findById(id);
    if (!user || user.role !== 'Provider') {
      return res.status(404).json({ message: 'Provider not found' });
    }

    const provider = await ServiceProvider.findOne({ userid: id });
    if (provider) {
      provider.documents = documents;
      await provider.save();
    }

    res.json({ message: 'Documents updated successfully', documents });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ==================== Reports Management ====================
const getReports = async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const query = {};
    if (status && status !== 'All') query.status = status;

    const reports = await Report.find(query)
      .populate('reporterId', 'fullName email')
      .populate('reportedId', 'fullName email')
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .sort({ createdAt: -1 });

    const total = await Report.countDocuments(query);

    // Format for frontend
    const formattedReports = reports.map((r) => ({
      id: r._id,
      sender: r.reporterId?.fullName || 'Unknown',
      senderEmail: r.reporterId?.email,
      target: r.reportedId?.fullName || 'Unknown',
      targetEmail: r.reportedId?.email,
      reason: r.reason,
      description: r.description,
      date: r.createdAt.toISOString().split('T')[0],
      status: r.status,
      action: r.action,
      adminResponse: r.adminResponse,
    }));

    res.json({
      reports: formattedReports,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / limit),
    });
  } catch (error) {
    console.error('Get reports error:', error);
    res.status(500).json({ message: error.message });
  }
};

const resolveReport = async (req, res) => {
  try {
    const { id } = req.params;
    const { action, message } = req.body;

    const report = await Report.findById(id);
    if (!report) {
      return res.status(404).json({ message: 'Report not found' });
    }

    report.status = 'Resolved';
    report.action = action;
    report.adminResponse = message || '';
    report.resolvedAt = new Date();
    await report.save();

    // Update reportsCount for the reported user
    const reportedUser = await User.findById(report.reportedId);
    if (reportedUser) {
      reportedUser.reportsCount = (reportedUser.reportsCount || 0) + 1;
      await reportedUser.save();

      // Auto-block if 5 or more reports
      if (reportedUser.reportsCount >= 5 && reportedUser.role !== 'Admin') {
        reportedUser.isActive = false;
        await reportedUser.save();

        await Notification.create({
          userId: reportedUser._id,
          title: 'Account Suspended',
          message: 'Your account has been suspended due to multiple reports.',
          type: 'system',
        });

        // Notify admin about auto-block
        const admin = await User.findOne({ role: 'Admin' });
        if (admin) {
          await Notification.create({
            userId: admin._id,
            title: 'Auto-Blocked User',
            message: `${reportedUser.fullName} has been blocked automatically due to 5 reports.`,
            type: 'system',
          });
        }
      }
    }

    // Send warning notification if action is warning
    if (action === 'warning' && message) {
      await Notification.create({
        userId: report.reportedId,
        title: 'Warning from Admin',
        message: `You have received a warning: ${message}`,
        type: 'system',
      });
    }

    // If ban action, also block the user (already handled by reportsCount >=5, but if admin manually bans before 5 reports)
    if (action === 'ban') {
      const userToBan = await User.findById(report.reportedId);
      if (userToBan && userToBan.role !== 'Admin') {
        userToBan.isActive = false;
        await userToBan.save();
        await Notification.create({
          userId: userToBan._id,
          title: 'Account Banned',
          message: 'Your account has been banned by an administrator.',
          type: 'system',
        });
      }
    }

    res.json({ message: `Report resolved with action: ${action}` });
  } catch (error) {
    console.error('Resolve report error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Categories ====================
const getCategories = async (req, res) => {
  try {
    const categories = await Category.find().sort({ createdAt: -1 });
    res.json(categories);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const addCategory = async (req, res) => {
  try {
    const { name, description } = req.body;

    if (!name) {
      return res.status(400).json({ message: 'Category name is required' });
    }

    const existingCategory = await Category.findOne({
      name: { $regex: new RegExp(`^${name}$`, 'i') },
    });
    if (existingCategory) {
      return res.status(400).json({ message: 'Category with this name already exists' });
    }

    const category = new Category({ name, description });
    await category.save();
    res.status(201).json({ message: 'Category created', category });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const updateCategory = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description } = req.body;

    const existingCategory = await Category.findOne({
      name: { $regex: new RegExp(`^${name}$`, 'i') },
      _id: { $ne: id },
    });
    if (existingCategory) {
      return res.status(400).json({ message: 'Category with this name already exists' });
    }

    const category = await Category.findByIdAndUpdate(
      id,
      { name, description },
      { new: true, runValidators: true }
    );
    if (!category) {
      return res.status(404).json({ message: 'Category not found' });
    }
    res.json({ message: 'Category updated', category });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const deleteCategory = async (req, res) => {
  try {
    const { id } = req.params;
    const category = await Category.findByIdAndDelete(id);
    if (!category) {
      return res.status(404).json({ message: 'Category not found' });
    }
    res.json({ message: 'Category deleted' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ==================== Services ====================
const getServices = async (req, res) => {
  try {
    const services = await Service.find().sort({ createdAt: -1 });
    res.json(services);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const addService = async (req, res) => {
  try {
    const { name, categoryId, category, price, description, slots } = req.body;

    if (!name || !price) {
      return res.status(400).json({ message: 'Name and price are required' });
    }

    const existingService = await Service.findOne({
      name: { $regex: new RegExp(`^${name}$`, 'i') },
    });
    if (existingService) {
      return res.status(400).json({ message: 'Service with this name already exists' });
    }

    const service = new Service({
      name: name,
      base_price: parseInt(price),
      price: parseInt(price),
      description: description || '',
      id_C: categoryId,
      categoryId: categoryId,
      category: category || '',
      slots: slots || '',
      isActive: true,
    });

    await service.save();
    res.status(201).json({ message: 'Service created', service });
  } catch (error) {
    console.error('Add service error:', error);
    res.status(500).json({ message: error.message });
  }
};

const updateService = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, price, description, isActive, slots } = req.body;

    const existingService = await Service.findOne({
      name: { $regex: new RegExp(`^${name}$`, 'i') },
      _id: { $ne: id },
    });
    if (existingService) {
      return res.status(400).json({ message: 'Service with this name already exists' });
    }

    const service = await Service.findByIdAndUpdate(
      id,
      {
        name,
        price: price ? parseInt(price) : undefined,
        description,
        isActive,
        slots,
      },
      { new: true, runValidators: true }
    );
    if (!service) {
      return res.status(404).json({ message: 'Service not found' });
    }
    res.json({ message: 'Service updated', service });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const deleteService = async (req, res) => {
  try {
    const { id } = req.params;
    const service = await Service.findByIdAndDelete(id);
    if (!service) {
      return res.status(404).json({ message: 'Service not found' });
    }
    res.json({ message: 'Service deleted' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ==================== Bookings ====================
const getBookings = async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const query = {};
    if (status && status !== 'All') query.status = status;

    const bookings = await Booking.find(query)
      .populate('clientId', 'fullName phoneNumber')
      .populate('providerId', 'fullName phoneNumber')
      .populate('serviceId', 'name price')
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .sort({ createdAt: -1 });

    const total = await Booking.countDocuments(query);

    res.json({
      bookings,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / limit),
    });
  } catch (error) {
    console.error('Get bookings error:', error);
    res.status(500).json({ message: error.message });
  }
};

const updateBookingStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const validStatuses = ['Pending', 'Confirmed', 'In Progress', 'Completed', 'Cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }

    const booking = await Booking.findByIdAndUpdate(id, { status }, { new: true });
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    res.json({ message: `Booking ${id} status updated to ${status}`, booking });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ==================== Statistics ====================
const getStats = async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const totalProviders = await User.countDocuments({ role: 'Provider' });
    const totalClients = await User.countDocuments({ role: 'Client' });
    const pendingProviders = await User.countDocuments({
      role: 'Provider',
      isVerified: false,
    });
    const activeUsers = await User.countDocuments({ isActive: true });
    const totalCategories = await Category.countDocuments();
    const totalServices = await Service.countDocuments();
    const totalBookings = await Booking.countDocuments();
    const completedBookings = await Booking.countDocuments({ status: 'Completed' });
    const inProgressBookings = await Booking.countDocuments({ status: 'In Progress' });

    const totalRevenueResult = await Booking.aggregate([
      { $match: { status: 'Completed', paymentStatus: 'Completed' } },
      { $group: { _id: null, total: { $sum: '$totalPrice' } } },
    ]);
    const totalRevenue = totalRevenueResult[0]?.total || 0;

    const avgRatingResult = await Booking.aggregate([
      { $match: { rating: { $exists: true, $ne: null } } },
      { $group: { _id: null, avg: { $avg: '$rating' } } },
    ]);
    const avgRating = avgRatingResult[0]?.avg.toFixed(1) || 4.5;

    res.json({
      totalUsers,
      totalProviders,
      totalClients,
      pendingProviders,
      activeUsers,
      totalCategories,
      totalServices,
      totalBookings,
      completedBookings,
      inProgressBookings,
      totalRevenue,
      avgRating,
    });
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ message: error.message });
  }
};

const getServiceReports = async (req, res) => {
  try {
    const services = await Service.find();

    if (!services || services.length === 0) {
      return res.json([]);
    }

    const reports = await Promise.all(
      services.map(async (service) => {
        const bookings = await Booking.countDocuments({ serviceId: service._id });
        const revenue = (service.price || 0) * bookings;

        const bookingsWithRating = await Booking.find({
          serviceId: service._id,
          rating: { $exists: true, $ne: null },
        });

        const avgRating =
          bookingsWithRating.length > 0
            ? (
                bookingsWithRating.reduce((sum, b) => sum + (b.rating || 0), 0) /
                bookingsWithRating.length
              ).toFixed(1)
            : '4.5';

        const lastMonth = new Date();
        lastMonth.setMonth(lastMonth.getMonth() - 1);
        const lastMonthBookings = await Booking.countDocuments({
          serviceId: service._id,
          createdAt: { $lt: new Date(), $gte: lastMonth },
        });

        const growth =
          bookings > 0 && lastMonthBookings > 0
            ? `+${Math.round(((bookings - lastMonthBookings) / lastMonthBookings) * 100)}%`
            : '+0%';

        return {
          id: service._id,
          name: service.name || 'Unnamed',
          category: service.category || 'General',
          bookings: bookings,
          revenue: revenue,
          rating: parseFloat(avgRating),
          growth: growth,
          incidents: 0,
          icon: '🛠️',
        };
      })
    );

    res.json(reports);
  } catch (error) {
    console.error('Error in getServiceReports:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Exports ====================
module.exports = {
  getAllUsers,
  getUserById,
  toggleBlockUser,
  getPendingRequests,
  verifyProvider,
  updateProviderDocuments,
  getReports,
  resolveReport,
  getCategories,
  addCategory,
  updateCategory,
  deleteCategory,
  getServices,
  addService,
  updateService,
  deleteService,
  getBookings,
  updateBookingStatus,
  getStats,
  getServiceReports,
};