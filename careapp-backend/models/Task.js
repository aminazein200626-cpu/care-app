const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema({
  name: String,
  start_time: Date,
  end_time: Date,
  duration: Number,
  status: { type: String, default: 'not_started' },
  idU_cl: { type: mongoose.Schema.Types.ObjectId, ref: 'Client' },
  idU_SP: { type: mongoose.Schema.Types.ObjectId, ref: 'ServiceProvider' }
});

module.exports = mongoose.model('Task', taskSchema);