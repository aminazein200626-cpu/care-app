const mongoose = require('mongoose');

const authorizedPersonSchema = new mongoose.Schema({
  name: { type: String, required: true },
  phone_number: String,
  national_id: String,
  idU_CL: { type: mongoose.Schema.Types.ObjectId, ref: 'Client', required: true }
});

module.exports = mongoose.model('AuthorizedPerson', authorizedPersonSchema);