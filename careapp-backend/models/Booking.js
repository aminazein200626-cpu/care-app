const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema({
  // ==================== Client and Provider Information ====================
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  client: { type: String },
  clientPhone: { type: String },

  providerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  provider: { type: String },
  providerPhone: { type: String },

  // ==================== Service Information ====================
  serviceId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Service'
  },
  service: { type: String },

  // ==================== Service Schedule ====================
  date: { type: Date, required: true },
  startTime: { type: String, required: true },
  endTime: { type: String },
  location: { type: String, default: '' },
  notes: { type: String, default: '' },

  // ==================== Dependent ====================
  dependentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Dependent'
  },

  // ==================== Booking Status ====================
  status: {
    type: String,
    enum: ['Pending', 'Confirmed', 'In Progress', 'Completed', 'Cancelled'],
    default: 'Pending'
  },

  // ==================== Payment Information ====================
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
    providerNote: { type: String, default: '' }
  }],
  clientTasksSubmittedAt: { type: Date },

  // ==================== Tracking ====================
  trackingStage: {
    type: String,
    enum: ['Pending', 'Accepted', 'OnWay', 'Arrived', 'Started', 'InProgress', 'AlmostDone', 'Completed'],
    default: 'Pending'
  },
  stageTimes: { type: Map, of: String },
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

  // ==================== GPS Location ====================
  providerLat: { type: Number },
  providerLng: { type: Number },
  eta: { type: String },

  // ==================== Client Rating for Provider ====================
  rating: { type: Number, min: 0, max: 5 },
  feedback: { type: String },
  feedbackReply: { type: String },

  // ==================== Provider Rating for Client ====================
  clientRating: { type: Number, min: 0, max: 5 },
  clientFeedback: { type: String },

  // ==================== Link to Task (new) ====================
  taskId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Task',
    default: null
  },

  // ==================== Timestamps ====================
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
  lastUpdate: { type: Date }

}, { timestamps: true });

// Prevent duplicate booking for same client, provider, date and startTime
bookingSchema.index(
  { clientId: 1, providerId: 1, date: 1, startTime: 1 },
  { unique: true }
);

module.exports = mongoose.model('Booking', bookingSchema);