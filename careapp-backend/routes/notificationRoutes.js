const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const Notification = require('../models/Notification');

// ==================== الحصول على الإشعارات ====================
router.get('/notifications', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { unread = false, limit = 20, page = 1 } = req.query;

    let filter = { userId };
    if (unread === 'true') {
      filter.isRead = false;
    }

    const notifications = await Notification.find(filter)
      .populate('bookingId')
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .skip((parseInt(page) - 1) * parseInt(limit));

    const total = await Notification.countDocuments(filter);

    res.json({
      success: true,
      count: notifications.length,
      total,
      unreadCount: await Notification.countDocuments({ userId, isRead: false }),
      data: notifications
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== تحديد إشعار كمقروء ====================
router.put('/notifications/:notificationId/read', authMiddleware, async (req, res) => {
  try {
    const { notificationId } = req.params;

    const notification = await Notification.findByIdAndUpdate(
      notificationId,
      {
        isRead: true,
        readAt: new Date()
      },
      { new: true }
    );

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'الإشعار غير موجود'
      });
    }

    res.json({
      success: true,
      message: 'تم تحديد الإشعار كمقروء',
      data: notification
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== تحديد كل الإشعارات كمقروءة ====================
router.put('/notifications/mark-all-read', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.userId;

    await Notification.updateMany(
      { userId, isRead: false },
      {
        isRead: true,
        readAt: new Date()
      }
    );

    res.json({
      success: true,
      message: 'تم تحديد جميع الإشعارات كمقروءة'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== حذف إشعار ====================
router.delete('/notifications/:notificationId', authMiddleware, async (req, res) => {
  try {
    const { notificationId } = req.params;
    const userId = req.user.userId;

    const notification = await Notification.findOneAndDelete({
      _id: notificationId,
      userId
    });

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'الإشعار غير موجود'
      });
    }

    res.json({
      success: true,
      message: 'تم حذف الإشعار'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== حذف كل الإشعارات ====================
router.delete('/notifications', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.userId;

    await Notification.deleteMany({ userId });

    res.json({
      success: true,
      message: 'تم حذف جميع الإشعارات'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

module.exports = router;
