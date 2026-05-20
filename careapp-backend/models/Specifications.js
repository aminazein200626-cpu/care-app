const mongoose = require('mongoose');

const specificationsSchema = new mongoose.Schema({
  url: String,
  description: String,
  id_dep: { type: mongoose.Schema.Types.ObjectId, ref: 'Dependant' }
});

module.exports = mongoose.model('Specifications', specificationsSchema);