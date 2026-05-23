const Feedback = require('../models/Feedback');
const Booking = require('../models/Booking');
const Notification = require('../models/Notification');
const User = require('../models/User');
const ServiceProvider = require('../models/ServiceProvider');

// ==================== إضافة تقييم جديد ====================
exports.createFeedback = async (req, res) => {
  try {
    const { bookingId, overall_rating, punctuality, comment } = req.body;
    const clientId = req.user.userId; // العميل الحالي

    // التحقق من صحة البيانات
    if (!bookingId || !overall_rating) {
      return res.status(400).json({ 
        success: false, 
        message: 'Booking ID and overall rating are required' 
      });
    }
    if (overall_rating < 1 || overall_rating > 5) {
      return res.status(400).json({ 
        success: false, 
        message: 'Overall rating must be between 1 and 5' 
      });
    }
    if (punctuality && (punctuality < 1 || punctuality > 5)) {
      return res.status(400).json({ 
        success: false, 
        message: 'Punctuality rating must be between 1 and 5' 
      });
    }

    // التحقق من وجود الحجز وأنه مكتمل
    const booking = await Booking.findOne({ 
      _id: bookingId, 
      clientId: clientId,
      status: 'Completed' 
    });
    if (!booking) {
      return res.status(404).json({ 
        success: false, 
        message: 'Completed booking not found' 
      });
    }

    // التحقق من عدم وجود تقييم مسبق لنفس الحجز
    const existingFeedback = await Feedback.findOne({ bookingId });
    if (existingFeedback) {
      return res.status(400).json({ 
        success: false, 
        message: 'You have already rated this booking' 
      });
    }

    // إنشاء التقييم الجديد
    const feedback = new Feedback({
      clientId: clientId,
      providerId: booking.providerId,
      bookingId: bookingId,
      overall_rating,
      punctuality: punctuality || null,
      comment: comment || '',
      created_at: new Date()
    });
    await feedback.save();

    // تحديث متوسط تقييم المزود في ServiceProvider
    const allFeedbacks = await Feedback.find({ providerId: booking.providerId });
    const avgRating = allFeedbacks.reduce((sum, f) => sum + f.overall_rating, 0) / allFeedbacks.length;
    await ServiceProvider.findOneAndUpdate(
      { userid: booking.providerId },
      { 
        averageRating: avgRating,
        totalReviews: allFeedbacks.length 
      }
    );

    // إشعار للمزود
    const client = await User.findById(clientId);
    await Notification.create({
      userId: booking.providerId,
      title: 'New Feedback Received',
      message: `${client.fullName} rated you ${overall_rating} stars. Comment: ${comment || 'No comment'}`,
      type: 'review',
      bookingId: booking._id
    });

    res.status(201).json({
      success: true,
      message: 'Feedback submitted successfully',
      data: feedback
    });
  } catch (error) {
    console.error('Create feedback error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
};

// ==================== الحصول على تقييمات مزود معين ====================
exports.getProviderFeedbacks = async (req, res) => {
  try {
    const { providerId } = req.params;
    const { page = 1, limit = 10 } = req.query;

    const feedbacks = await Feedback.find({ providerId })
      .populate('clientId', 'fullName profilePicture')
      .populate('bookingId', 'service date')
      .sort({ created_at: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    const total = await Feedback.countDocuments({ providerId });

    // حساب متوسط التقييم العام والالتزام بالمواعيد
    const stats = await Feedback.aggregate([
      { $match: { providerId: new mongoose.Types.ObjectId(providerId) } },
      { 
        $group: { 
          _id: null,
          avgOverall: { $avg: '$overall_rating' },
          avgPunctuality: { $avg: '$punctuality' },
          count: { $sum: 1 }
        }
      }
    ]);

    res.json({
      success: true,
      data: feedbacks,
      stats: stats[0] || { avgOverall: 0, avgPunctuality: 0, count: 0 },
      total,
      page: parseInt(page),
      pages: Math.ceil(total / limit)
    });
  } catch (error) {
    console.error('Get provider feedbacks error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
};

// ==================== الحصول على تقييمات العميل (التي كتبها) ====================
exports.getMyFeedbacks = async (req, res) => {
  try {
    const clientId = req.user.userId;
    const { page = 1, limit = 10 } = req.query;

    const feedbacks = await Feedback.find({ clientId })
      .populate('providerId', 'fullName profilePicture')
      .populate('bookingId', 'service date')
      .sort({ created_at: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    const total = await Feedback.countDocuments({ clientId });

    res.json({
      success: true,
      data: feedbacks,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / limit)
    });
  } catch (error) {
    console.error('Get my feedbacks error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
};

// ==================== رد المزود على التقييم ====================
exports.replyToFeedback = async (req, res) => {
  try {
    const { id } = req.params;
    const { reply } = req.body;
    const providerId = req.user.userId;

    if (!reply || reply.trim() === '') {
      return res.status(400).json({ 
        success: false, 
        message: 'Reply message is required' 
      });
    }

    const feedback = await Feedback.findById(id);
    if (!feedback) {
      return res.status(404).json({ 
        success: false, 
        message: 'Feedback not found' 
      });
    }

    if (feedback.providerId.toString() !== providerId) {
      return res.status(403).json({ 
        success: false, 
        message: 'You are not authorized to reply to this feedback' 
      });
    }

    feedback.reply = reply;
    feedback.replyAt = new Date();
    await feedback.save();

    // إشعار للعميل
    await Notification.create({
      userId: feedback.clientId,
      title: 'Provider Replied to Your Review',
      message: `Provider replied: ${reply}`,
      type: 'review',
      bookingId: feedback.bookingId
    });

    res.json({
      success: true,
      message: 'Reply added successfully',
      data: { reply, replyAt: feedback.replyAt }
    });
  } catch (error) {
    console.error('Reply to feedback error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
};

// ==================== حذف تقييم (للأدمن فقط) ====================
exports.deleteFeedback = async (req, res) => {
  try {
    const { id } = req.params;
    // يمكن إضافة صلاحية للأدمن فقط
    const feedback = await Feedback.findByIdAndDelete(id);
    if (!feedback) {
      return res.status(404).json({ 
        success: false, 
        message: 'Feedback not found' 
      });
    }
    res.json({ 
      success: true, 
      message: 'Feedback deleted successfully' 
    });
  } catch (error) {
    console.error('Delete feedback error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
};