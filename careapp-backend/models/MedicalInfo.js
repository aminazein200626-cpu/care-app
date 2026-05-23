const mongoose = require('mongoose');

const medicalInfoSchema = new mongoose.Schema({
  dependentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Dependent',
    required: true,
    unique: true
  },
  bloodType: { type: String, default: '' },
  allergies: { type: String, default: '' },    
  medications: { type: String, default: '' },    
  conditions: { type: String, default: '' },     
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('MedicalInfo', medicalInfoSchema);