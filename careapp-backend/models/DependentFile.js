const mongoose = require('mongoose');

const dependentFileSchema = new mongoose.Schema({
  dependentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Dependent',
    required: true,
    index: true
  },
  fileName: { type: String, required: true },
  fileUrl: { type: String, required: true },
  fileType: {
    type: String,
    enum: ['general', 'medical', 'id_card', 'prescription', 'test_result', 'other'],
    default: 'general'
  },
  mimeType: { type: String, required: true },
  size: { type: Number, default: 0 },
  uploadedAt: { type: Date, default: Date.now }
});

dependentFileSchema.index({ dependentId: 1, fileType: 1 });

module.exports = mongoose.model('DependentFile', dependentFileSchema);