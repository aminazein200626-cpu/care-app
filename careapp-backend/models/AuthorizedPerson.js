const mongoose = require('mongoose');

const authorizedPersonSchema = new mongoose.Schema({
  id_AP: { type: mongoose.Schema.Types.ObjectId, auto: true },
  name: { type: String, required: true },
  phone_number: { type: String, default: '' },
  national_id: { type: String, default: '' },
  id_U_CL: { type: mongoose.Schema.Types.ObjectId, ref: 'Client', required: true },
  email: { type: String, required: true, unique: true, lowercase: true },
  relationship: { type: String, default: '' },
  canTrack: { type: Boolean, default: true },
  canChat: { type: Boolean, default: true },
  canViewLocation: { type: Boolean, default: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('AuthorizedPerson', authorizedPersonSchema);