const mongoose = require('mongoose');

const serviceSchema = new mongoose.Schema({
  // ==================== معلومات الخدمة الأساسية ====================
  name: {
    type: String,
    required: true,
    unique: true
  },
  description: { type: String, default: '' },
  category: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ServiceCategory'
  },
  
  // ==================== التسعير ====================
  basePrice: { type: Number, required: true },
  minPrice: { type: Number },
  maxPrice: { type: Number },
  priceType: {
    type: String,
    enum: ['per_hour', 'per_visit', 'per_package'],
    default: 'per_hour'
  },
  
  // ==================== الدعم والإمكانيات ====================
  requiredQualifications: [{ type: String }], // المؤهلات المطلوبة
  maxConcurrentBookings: { type: Number, default: 1 },
  minimumDuration: { type: Number, default: 1 }, // بالساعات
  maximumDuration: { type: Number, default: 8 },
  
  // ==================== الحالة ====================
  isActive: { type: Boolean, default: true },
  status: {
    type: String,
    enum: ['active', 'inactive', 'archived'],
    default: 'active'
  },
  
  // ==================== الإحصائيات ====================
  demandLevel: {
    type: String,
    enum: ['low', 'medium', 'high'],
    default: 'medium'
  },
  totalBookings: { type: Number, default: 0 },
  averageRating: { type: Number, default: 0, min: 0, max: 5 },
  
  // ==================== التواريخ ====================
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Service', serviceSchema);