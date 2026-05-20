const mongoose = require('mongoose');

const documentSchema = new mongoose.Schema({
  name: String,
  link: String,
  type: String,
  width: Number,
  idU_SP: { type: mongoose.Schema.Types.ObjectId, ref: 'ServiceProvider' },
  idU_cl: { type: mongoose.Schema.Types.ObjectId, ref: 'Client' }
});

module.exports = mongoose.model('Document', documentSchema);