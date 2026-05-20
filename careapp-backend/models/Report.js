const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  id_reporter: { type: String, ref: 'Account', required: true },
  id_reported: { type: String, ref: 'Account', required: true },
  reason: String,
  description: String,
  created_at: { type: Date, default: Date.now }
});
reportSchema.index({ id_reporter: 1, id_reported: 1, created_at: 1 }, { unique: true });

module.exports = mongoose.model('Report', reportSchema);