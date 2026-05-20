const mongoose = require('mongoose');

const serviceCategorySchema = new mongoose.Schema({
  name: { type: String, required: true, unique: true },
  target_demographics: String,
  policies: String,
  icon: String
});

module.exports = mongoose.model('ServiceCategory', serviceCategorySchema);