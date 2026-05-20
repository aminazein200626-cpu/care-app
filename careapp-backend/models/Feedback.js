const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema({
  overall_rating: Number,
  punctuality: Number,
  comment: String,
  created_at: { type: Date, default: Date.now },
  idU_cl: { type: mongoose.Schema.Types.ObjectId, ref: 'Client' },
  idU_SP: { type: mongoose.Schema.Types.ObjectId, ref: 'ServiceProvider' },
  bookingId: { type: mongoose.Schema.Types.ObjectId, ref: 'Booking' }
});

module.exports = mongoose.model('Feedback', feedbackSchema);