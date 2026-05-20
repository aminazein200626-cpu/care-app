const mongoose = require('mongoose');

const medicalInfoSchema = new mongoose.Schema({
  id_dep: { type: mongoose.Schema.Types.ObjectId, ref: 'Dependant', required: true, unique: true },
  bloodType: String,
  allergies: String,
  medications: String,
  conditions: String
});

module.exports = mongoose.model('MedicalInfo', medicalInfoSchema);