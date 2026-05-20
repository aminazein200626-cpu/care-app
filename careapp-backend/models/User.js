const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  fullName: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  passwordHash: { type: String, required: true },
  phoneNumber: String,
  address: String,
  wilaya: String,
  postalCode: String,
  profilePicture: String,
  role: { type: String, enum: ['Client', 'Provider', 'AuthorizedPerson', 'Admin'], default: 'Client' },
  isActive: { type: Boolean, default: true },
  isVerified: { type: Boolean, default: false },
  gender: String,
  nationalId: String,
  dateOfBirth: Date,
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('User', userSchema);