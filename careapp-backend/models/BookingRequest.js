const mongoose = require('mongoose');

const bookingRequestSchema = new mongoose.Schema({
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
  serviceName: {
    type: String,
    required: true
  },
  date: {
    type: String,  // YYYY-MM-DD
    required: true
  },
  startTime: {
    type: String,
    required: true
  },
  endTime: String,
  location: String,
  notes: String,
  dependantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Dependant'
  },
  tasks: [{
    taskName: String
  }],
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected'],
    default: 'pending'
  },
  // Link to Task (new)
  taskId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Task',
    default: null
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  respondedAt: Date
});

module.exports = mongoose.model('BookingRequest', bookingRequestSchema);