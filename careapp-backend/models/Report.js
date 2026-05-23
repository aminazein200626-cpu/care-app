const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  
  email1: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
    index: true
  },
  
 
  email2: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
    index: true
  },
  
 
  reason: {
    type: String,
    required: true
  },
  
 
  description: {
    type: String,
    default: ''
  },
  
 
  created_at: {
    type: Date,
    default: Date.now
  }
});


reportSchema.index({ email1: 1, email2: 1 }, { unique: true });

module.exports = mongoose.model('Report', reportSchema);