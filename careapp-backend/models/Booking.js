const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema({
  // ==================== معلومات العميل والمقدم ====================
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  client: { type: String },  // اسم العميل (من أجل العرض السريع)
  clientPhone: { type: String },

  providerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  provider: { type: String },  // اسم المقدم
  providerPhone: { type: String },

  // ==================== معلومات الخدمة ====================
  serviceId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Service'
  },
  service: { type: String },  // اسم الخدمة (نسخة نصية للعرض)

  // ==================== موعد الخدمة ====================
  date: { type: Date, required: true },
  startTime: { type: String, required: true },  // مثل "10:00 AM"
  endTime: { type: String },
  location: { type: String, default: '' },
  notes: { type: String, default: '' },

  // ==================== المعال (Dependent) ====================
  dependentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Dependent'
  },

  // ==================== حالة الحجز ====================
  status: {
    type: String,
    enum: ['Pending', 'Confirmed', 'In Progress', 'Completed', 'Cancelled'],
    default: 'Pending'
  },

  // ==================== معلومات الدفع ====================
  totalPrice: { type: Number, default: 0 },
  paymentStatus: {
    type: String,
    enum: ['Pending', 'HalfPaid', 'Completed'],
    default: 'Pending'
  },
  halfPaid: { type: Boolean, default: false },
  halfAmount: { type: Number, default: 0 },
  remainingAmount: { type: Number, default: 0 },
  paymentMethod: { type: String, default: '' },
  paidAt: { type: Date },

  clientTasks: [{
    taskName: { type: String, required: true },
    status: { type: String, enum: ['pending', 'completed'], default: 'pending' },
    providerNote: { type: String, default: '' }  // ملاحظة المزود على المهمة
  }],
  clientTasksSubmittedAt: { type: Date },

  // ==================== التتبع (Tracking) ====================
  trackingStage: {
    type: String,
    enum: ['Pending', 'Accepted', 'OnWay', 'Arrived', 'Started', 'InProgress', 'AlmostDone', 'Completed'],
    default: 'Pending'
  },
  stageTimes: { type: Map, of: String },  // يسجل وقت كل مرحلة
  workSteps: [{
    description: { type: String },
    time: { type: String },
    completedAt: { type: Date }
  }],
  attachments: [{
    type: { type: String, enum: ['image', 'audio', 'video', 'file'] },
    url: { type: String },
    time: { type: String }
  }],
  // ==================== موقع GPS ====================
  providerLat: { type: Number },
  providerLng: { type: Number },
  eta: { type: String },  // الوقت المتوقع للوصول

  // ==================== تقييم المزود من قبل العميل ====================
  rating: { type: Number, min: 0, max: 5 },
  feedback: { type: String },
  feedbackReply: { type: String },

  // ==================== تقييم العميل من قبل المزود ====================
  clientRating: { type: Number, min: 0, max: 5 },
  clientFeedback: { type: String },

  // ==================== الطوابع الزمنية ====================
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
  lastUpdate: { type: Date }

}, { timestamps: true });

// منع تكرار نفس الحجز لنفس العميل ونفس المقدم في نفس اليوم والوقت
bookingSchema.index(
  { clientId: 1, providerId: 1, date: 1, startTime: 1 },
  { unique: true }
);

module.exports = mongoose.model('Booking', bookingSchema);