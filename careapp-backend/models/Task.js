const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema({
  name: { type: String, required: true },
  start_time: { type: Date, required: true },
  end_time: { type: Date, required: true },
  duration: { type: Number, default: 0 },
  status: {
    type: String,
    enum: ['pending', 'confirmed', 'in_progress', 'completed', 'cancelled'],
    default: 'pending'
  },
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  providerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking',
    default: null
  },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// ✅ إزالة next() تماماً - استخدام async/async
taskSchema.pre('save', async function() {
  if (this.start_time && this.end_time) {
    const diffMs = this.end_time - this.start_time;
    this.duration = Math.floor(diffMs / (1000 * 60));
  }
});

module.exports = mongoose.model('Task', taskSchema);