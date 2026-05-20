const mongoose = require('mongoose');

const inscriptionRequestSchema = new mongoose.Schema({
  providerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ServiceProvider',
    required: true
  },
  adminId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Admin',
    default: null
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending'
  },
  submitted_at: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('InscriptionRequest', inscriptionRequestSchema);