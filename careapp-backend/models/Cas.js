const mongoose = require('mongoose');

const casSchema = new mongoose.Schema({
  link: String,
  date: Date,
  time: String,
  address: String,
  mobile: String,
  work: String,
  status: String,
  review: String,
  client_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Client' },
  carrier_id: { type: mongoose.Schema.Types.ObjectId, ref: 'ServiceProvider' },
  service_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Service' }
});

module.exports = mongoose.model('Cas', casSchema);