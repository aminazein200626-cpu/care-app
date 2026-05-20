const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  title: { type: String, required: true },
  message: { type: String, required: true },
  type: {
    type: String,
    enum: [
      'booking',
      'booking_request',
      'booking_confirmed',
      'booking_rejected',
      'booking_completed',
      'booking_update',
      'payment',
      'message',
      'system',
      'tracking',
      'review'           // ✅ تمت الإضافة
    ],
    default: 'system'
  },
  
  // ==================== الإشارات ====================
  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking'
  },
  providerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ServiceProvider'
  },
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Client'
  },
  
  // ==================== الحالة ====================
  isRead: { type: Boolean, default: false },
  readAt: { type: Date },
  
  // ==================== التواريخ ====================
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

NotificationSchema.index({ userId: 1, isRead: 1 });
NotificationSchema.index({ createdAt: -1 });
NotificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', NotificationSchema);