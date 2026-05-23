const mongoose = require('mongoose');

const dependentSchema = new mongoose.Schema({
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Client',
    required: true
  },
  
  // ==================== Basic Information ====================
  fullName: { type: String, required: true },
  relationship: {
    type: String,
    required: true
  },
  gender: { type: String, enum: ['M', 'F'] },
  dateOfBirth: { type: Date, required: true },
  
  // ==================== Identifiers ====================
  nationalId: { type: String },
  age: { type: Number }, // calculated from dateOfBirth
  
  // ==================== Medical Information (text) ====================
  healthConditions: [{ type: String }],
  medications: [{ type: String }],
  allergies: [{ type: String }],
  healthNotes: { type: String },
  emergencyContact: {
    name: String,
    phone: String,
    relationship: String
  },
  
  // ==================== Link to separate MedicalInfo document (optional) ====================
  medicalInfoId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'MedicalInfo',
    default: null
  },
  
  // ==================== Status ====================
  isActive: { type: Boolean, default: true },
  status: {
    type: String,
    enum: ['active', 'inactive'],
    default: 'active'
  },
  
  // ==================== Timestamps ====================
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Dependent', dependentSchema);