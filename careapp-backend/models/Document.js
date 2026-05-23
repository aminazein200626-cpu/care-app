// backend/models/Document.js
const mongoose = require('mongoose');

const documentSchema = new mongoose.Schema({
  
  clientId: { type: mongoose.Schema.Types.ObjectId, ref: 'Client', sparse: true },
  providerId: { type: mongoose.Schema.Types.ObjectId, ref: 'ServiceProvider', sparse: true },
  
 
  name: { type: String, required: true },       
  link: { type: String, required: true },     
  type: { type: String, required: true },       
  mimeType: { type: String },                   
  size: { type: Number },
  
  uploadedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Document', documentSchema);