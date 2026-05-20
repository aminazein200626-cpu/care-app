const mongoose = require('mongoose');

const clientSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true
  },
  // ==================== معلومات العميل الأساسية ====================
  fullName: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  phoneNumber: { type: String, required: true },
  
  // ==================== الموقع ====================
  address: { type: String, default: '' },
  wilaya: { type: String, required: true }, // المحافظة
  municipality: { type: String, default: '' }, // البلدية
  postalCode: { type: String, default: '' },
  latitude: { type: Number },
  longitude: { type: Number },
  
  // ==================== المعلومات الشخصية ====================
  profilePicture: { type: String, default: '' },
  gender: { type: String, enum: ['M', 'F'], default: null },
  dateOfBirth: { type: Date },
  nationalId: { type: String },
  
  // ==================== المعالين (Dependents) ====================
  dependents: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Dependent'
  }],
  
  // ==================== التفضيلات ====================
  preferredServices: [{ type: String }], // أنواع الخدمات المفضلة
  preferredProviders: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ServiceProvider'
  }],
  
  // ==================== الحالة ====================
  isActive: { type: Boolean, default: true },
  isVerified: { type: Boolean, default: false },
  status: {
    type: String,
    enum: ['active', 'inactive', 'blocked', 'pending'],
    default: 'active'
  },
  
  // ==================== الإحصائيات ====================
  totalBookings: { type: Number, default: 0 },
  completedBookings: { type: Number, default: 0 },
  averageRating: { type: Number, default: 0, min: 0, max: 5 },
  
  // ==================== الوثائق ====================
  documents: [{
    name: String,
    url: String,
    uploadedAt: { type: Date, default: Date.now }
  }],
  
  // ==================== التواريخ ====================
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
  lastLogin: { type: Date }
});

module.exports = mongoose.model('Client', clientSchema);