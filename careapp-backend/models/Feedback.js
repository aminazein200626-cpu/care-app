const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema({
  // التقييم الأساسي (1-5)
  overall_rating: {
    type: Number,
    required: true,
    min: 1,
    max: 5
  },
  
  // التقييم الإضافي (اختياري)
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
  
  // معرف الحجز (Booking) – يجب أن يكون فريداً لمنع تكرار التقييم
  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking',
    required: true,
    unique: true   // ✅ يولد فهرساً فريداً تلقائياً
  },
  
  // تاريخ إنشاء التقييم
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// ✅ إضافة فهارس إضافية (لتحسين الأداء) – لا تعيد فهرسة bookingId
feedbackSchema.index({ clientId: 1 });
feedbackSchema.index({ providerId: 1 });
feedbackSchema.index({ createdAt: -1 });

module.exports = mongoose.model('Feedback', feedbackSchema);