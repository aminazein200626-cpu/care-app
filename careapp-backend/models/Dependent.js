const mongoose = require('mongoose');

const dependentSchema = new mongoose.Schema({
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Client',
    required: true
  },
  
  // ==================== المعلومات الأساسية ====================
  fullName: { type: String, required: true },
 relationship: {
    type: String,
    required: true
    
  },
  gender: { type: String, enum: ['M', 'F'] },
  dateOfBirth: { type: Date, required: true },
  
  // ==================== المعرفات ====================
  nationalId: { type: String },
  age: { type: Number }, // يُحسب من التاريخ
  
  // ==================== المعلومات الطبية ====================
  healthConditions: [{ type: String }], // الحالات الطبية
  medications: [{ type: String }], // الأدوية
  allergies: [{ type: String }], // الحساسيات
  healthNotes: { type: String }, // ملاحظات عامة
  emergencyContact: {
    name: String,
    phone: String,
    relationship: String
  },
  
  // ==================== الملفات والوثائق ====================
  files: [{
    filename: String,
    url: { type: String },
    fileType: String, // 'medical_record', 'prescription', 'test', 'image', etc.
    uploadedAt: { type: Date, default: Date.now }
  }],
  
  // ==================== الحالة ====================
  isActive: { type: Boolean, default: true },
  status: {
    type: String,
    enum: ['active', 'inactive'],
    default: 'active'
  },
  
  // ==================== التواريخ ====================
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Dependent', dependentSchema);