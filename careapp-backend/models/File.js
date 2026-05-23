const mongoose = require('mongoose');

const fileSchema = new mongoose.Schema({
  url: { type: String, required: true },            // File path or URL
  type: { type: String, required: true },           // MIME type (image/jpeg, application/pdf, etc.)
  name: { type: String, default: '' },              // Original file name
  size: { type: Number, default: 0 },               // File size in bytes
  
  // ✅ ربط الملف بالمهمة (اختياري) - للملفات التي رفعها العميل عند إنشاء الطلب
  taskId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Task',
    default: null
  },
  
  // ✅ ربط الملف بالحجز (اختياري) - للملفات التي يرفعها المزود أثناء التتبع
  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking',
    default: null
  },
  
  uploadedAt: { type: Date, default: Date.now }
});

// ✅ إضافة فهارس لتحسين الأداء
fileSchema.index({ taskId: 1 });
fileSchema.index({ bookingId: 1 });
fileSchema.index({ uploadedAt: -1 });

module.exports = mongoose.model('File', fileSchema);