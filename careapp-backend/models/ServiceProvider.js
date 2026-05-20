const mongoose = require('mongoose');

const serviceProviderSchema = new mongoose.Schema({
  userid: { type: mongoose.Schema.Types.ObjectId, ref: 'User', unique: true, sparse: true },
  fullName: { type: String, default: '' },
  email: { type: String, sparse: true },
  phoneNumber: { type: String, default: '' },
  profilePicture: { type: String, default: '' },
  address: { type: String, default: '' },
  wilaya: { type: String, default: '' },
  municipality: { type: String, default: '' },
  postalCode: { type: String, default: '' },
  latitude: { type: Number },
  longitude: { type: Number },
  gender: { type: String, default: '' },
  dateOfBirth: { type: Date },
  nationalId: { type: String, sparse: true },
  services: [{ type: String }],
  serviceNames: [{ type: String }],
  categoryId: { type: mongoose.Schema.Types.ObjectId, ref: 'ServiceCategory' },
  yearsOfExperience: { type: Number, default: 0 },
  bio: { type: String, default: '' },
  specialization: { type: String, default: '' },
  hourlyRate: { type: Number, default: 0 },
  minimumServiceDuration: { type: Number, default: 1 },
  costPerKm: { type: Number, default: 0 },
  travelDistance: { type: String, default: 'Local Only' },
  travelCost: { type: Number, default: 0 },
  workOutsideCity: { type: Boolean, default: false },
  workHours: { type: String, default: '' },
  workLate: { type: Boolean, default: false },
  workWeekend: { type: Boolean, default: false },
  availability: { type: mongoose.Schema.Types.Mixed, default: '{}' },
  documents: [{
    name: String,
    url: String,
    documentType: String,
    uploadedAt: { type: Date, default: Date.now }
  }],
  certificates: [{
    name: String,
    url: String,
    uploadedAt: { type: Date, default: Date.now }
  }],
  averageRating: { type: Number, default: 0 },
  totalReviews: { type: Number, default: 0 },
  totalServices: { type: Number, default: 0 },
  completionRate: { type: Number, default: 0 },
  status: { type: String, default: 'pending' },
  isVerified: { type: Boolean, default: false },
  verificationDate: { type: Date },
  
  // ==================== معلومات الدفع للمزود ====================
  ccp: { type: String, default: '' },   // رقم CCP (البريد)
  bankAccount: {
    bankName: { type: String, default: '' },
    accountNumber: { type: String, default: '' },
    accountHolder: { type: String, default: '' },
    rib: { type: String, default: '' },
    // حقول قديمة للتوافق مع الإصدارات السابقة (يمكن الاحتفاظ بها)
    accountHolderOld: String,
    iban: String
  },
  
  totalEarnings: { type: Number, default: 0 },
  totalClients: { type: Number, default: 0 },
  motivation: { type: String, default: '' },
  rejectionReason: { type: String, default: '' },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
  lastLogin: { type: Date }
});

module.exports = mongoose.model('ServiceProvider', serviceProviderSchema);