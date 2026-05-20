const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  amount: { type: Number, required: true },
  currency: { type: String, default: 'DZD' },
  status: { type: String, default: 'unpaid' },
  payment_method: String,
  created_at: { type: Date, default: Date.now },
  
  
  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking'
  },
  

  idS: { type: mongoose.Schema.Types.ObjectId, ref: 'Service' },
  idU_SP: { type: mongoose.Schema.Types.ObjectId, ref: 'ServiceProvider' }
});

module.exports = mongoose.model('Payment', paymentSchema);