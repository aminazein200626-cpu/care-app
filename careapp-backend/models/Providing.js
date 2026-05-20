const mongoose = require('mongoose');

const providingSchema = new mongoose.Schema({
  serviceProviderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ServiceProvider',
    required: true
  },
  serviceId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Service',
    required: true
  },
  day_of_week: {
    type: String,
    required: true,
    enum: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
  },
  start_time: {
    type: String,
    required: true
  },
  end_time: {
    type: String,
    required: true
  },
  isBooked: {
    type: Boolean,
    default: false
  }
});

// منع تكرار نفس الفترة لنفس المزود في نفس اليوم
providingSchema.index({ serviceProviderId: 1, day_of_week: 1, start_time: 1, end_time: 1 }, { unique: true });

module.exports = mongoose.model('Providing', providingSchema);