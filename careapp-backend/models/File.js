const mongoose = require('mongoose');

const fileSchema = new mongoose.Schema({
  url: { type: String, required: true },
  type: String,
  idT: { type: mongoose.Schema.Types.ObjectId, ref: 'Task' }
});

module.exports = mongoose.model('File', fileSchema);