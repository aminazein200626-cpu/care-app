const Report = require('../models/Report');
const User = require('../models/User');
const Notification = require('../models/Notification');

 
exports.createReport = async (req, res) => {
  try {
    const { reportedId, reason, description } = req.body;
    const reporterId = req.user.userId;

    if (reporterId === reportedId) {
      return res.status(400).json({ message: 'You cannot report yourself' });
    }

    const existingReport = await Report.findOne({
      reporterId,
      reportedId,
      status: { $in: ['Pending', 'Review'] }
    });

    if (existingReport) {
      return res.status(400).json({ message: 'You have already reported this user' });
    }

    const report = new Report({
      reporterId,
      reportedId,
      reason,
      description,
      status: 'Pending'
    });

    await report.save();

    // إشعار للأدمن
    const admin = await User.findOne({ role: 'Admin' });
    if (admin) {
      await Notification.create({
        userId: admin._id,
        title: 'New Report',
        message: `User reported ${reportedId} for: ${reason}`,
        type: 'system'
      });
    }

    res.status(201).json({ message: 'Report submitted successfully', report });
  } catch (error) {
    console.error('Create report error:', error);
    res.status(500).json({ message: error.message });
  }
};


exports.getMyReports = async (req, res) => {
  try {
    const reports = await Report.find({ reporterId: req.user.userId })
      .populate('reportedId', 'fullName email')
      .sort({ createdAt: -1 });
    res.json(reports);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};