const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema({
  // معرف العميل (من جدول User)
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // معرف المزود (من جدول User)
  providerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // معرف الحجز (Booking) – إجباري وفريد لمنع تكرار التقييم
  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking',
    required: true,
    unique: true
  },
  
  // التقييم العام (1-5)
  overall_rating: {
    type: Number,
    required: true,
    min: 1,
    max: 5
  },
  
  // الالتزام بالمواعيد (1-5) – اختياري
  punctuality: {
    type: Number,
    min: 1,
    max: 5,
    default: null
  },
  
  // تعليق العميل
  comment: {
    type: String,
    default: ''
  },
  
  // رد المزود على التقييم (يضاف لاحقاً)
  reply: {
    type: String,
    default: ''
  },
  
  // وقت رد المزود
  replyAt: {
    type: Date,
    default: null
  },
  
  // تاريخ إنشاء التقييم
  created_at: {
    type: Date,
    default: Date.now
  }
});

// فهارس لتحسين الأداء
feedbackSchema.index({ clientId: 1, created_at: -1 });
feedbackSchema.index({ providerId: 1, created_at: -1 });
feedbackSchema.index({ bookingId: 1 }, { unique: true }); // منع تكرار التقييم لنفس الحجز

module.exports = mongoose.model('Feedback', feedbackSchema);