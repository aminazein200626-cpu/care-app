const mongoose = require('mongoose');

const DefaultSchema = new mongoose.Schema({
  day: {
    type: String,
    required: true
  },
  RL: {
    type: String,
    default: ''
  },
  Name: {
    type: String,
    default: ''
  },
  value: {
    type: mongoose.Schema.Types.Mixed,
    default: null
  }
});

module.exports = mongoose.model('Default', DefaultSchema);