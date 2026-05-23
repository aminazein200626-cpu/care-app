const Report = require('../models/Report');
const User = require('../models/User');
const Account = require('../models/Account');
const Notification = require('../models/Notification');

// ==================== إنشاء تقرير جديد ====================
exports.createReport = async (req, res) => {
  try {
    const { email2, reason, description } = req.body;
    const reporterId = req.user.userId;

    if (!email2 || !reason) {
      return res.status(400).json({ message: 'Email of reported person and reason are required' });
    }

    const reporterUser = await User.findById(reporterId).select('email');
    if (!reporterUser) {
      return res.status(404).json({ message: 'Reporter user not found' });
    }
    const email1 = reporterUser.email.toLowerCase().trim();

    if (email1 === email2.toLowerCase().trim()) {
      return res.status(400).json({ message: 'You cannot report yourself' });
    }

    const existingReport = await Report.findOne({
      email1: email1,
      email2: email2.toLowerCase().trim()
    });

    if (existingReport) {
      return res.status(400).json({ message: 'You have already reported this person' });
    }

    const report = new Report({
      email1: email1,
      email2: email2.toLowerCase().trim(),
      reason: reason,
      description: description || '',
      created_at: new Date()
    });

    await report.save();

    try {
      const admin = await User.findOne({ role: 'Admin' }).select('_id');
      if (admin) {
        await Notification.create({
          userId: admin._id,
          title: 'New Report',
          message: `User ${email1} reported ${email2} for: ${reason}`,
          type: 'system'
        });
      }
    } catch (notifErr) {
      console.error('Error sending admin notification:', notifErr.message);
    }

    res.status(201).json({
      success: true,
      message: 'Report submitted successfully',
      report: {
        id: report._id,
        email1: report.email1,
        email2: report.email2,
        reason: report.reason,
        description: report.description,
        created_at: report.created_at
      }
    });
  } catch (error) {
    console.error('Create report error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== الحصول على تقاريري ====================
exports.getMyReports = async (req, res) => {
  try {
    const reporterId = req.user.userId;
    const reporterUser = await User.findById(reporterId).select('email');
    if (!reporterUser) {
      return res.status(404).json({ message: 'User not found' });
    }
    const email1 = reporterUser.email.toLowerCase().trim();

    const reports = await Report.find({ email1: email1 })
      .sort({ created_at: -1 });

    res.json({
      success: true,
      count: reports.length,
      reports: reports.map(r => ({
        id: r._id,
        email1: r.email1,
        email2: r.email2,
        reason: r.reason,
        description: r.description,
        created_at: r.created_at
      }))
    });
  } catch (error) {
    console.error('Get my reports error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== تقارير وردت إلى بريد معين ====================
exports.getReportsByEmail = async (req, res) => {
  try {
    const { email } = req.params;
    if (!email) {
      return res.status(400).json({ message: 'Email parameter is required' });
    }

    const reports = await Report.find({ email2: email.toLowerCase().trim() })
      .sort({ created_at: -1 });

    res.json({
      success: true,
      count: reports.length,
      reports: reports.map(r => ({
        id: r._id,
        email1: r.email1,
        email2: r.email2,
        reason: r.reason,
        description: r.description,
        created_at: r.created_at
      }))
    });
  } catch (error) {
    console.error('Get reports by email error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== جلب جميع التقارير (للمسؤول) ====================
exports.getAllReports = async (req, res) => {
  try {
    const reports = await Report.find().sort({ created_at: -1 });

    res.json({
      success: true,
      reports: reports.map(r => ({
        id: r._id,
        email1: r.email1,
        email2: r.email2,
        reason: r.reason,
        description: r.description,
        created_at: r.created_at
      }))
    });
  } catch (error) {
    console.error('Get all reports error:', error);
    res.status(500).json({ message: error.message });
  }
};