const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema({
  clientId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  providerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  bookingId: { type: mongoose.Schema.Types.ObjectId, ref: 'Booking', required: true, unique: true }, // ✅ unique فقط هنا
  overall_rating: { type: Number, required: true, min: 1, max: 5 },
  punctuality: { type: Number, min: 1, max: 5, default: null },
  comment: { type: String, default: '' },
  reply: { type: String, default: '' },
  replyAt: { type: Date, default: null },
  created_at: { type: Date, default: Date.now }
});

// ✅ تأكد من عدم وجود سطر إضافي يستخدم schema.index على bookingId
// إذا كان هناك سطر مثل هذا، احذفه:
// feedbackSchema.index({ bookingId: 1 }, { unique: true });

feedbackSchema.index({ clientId: 1, created_at: -1 });
feedbackSchema.index({ providerId: 1, created_at: -1 });

module.exports = mongoose.model('Feedback', feedbackSchema);