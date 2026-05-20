const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authMiddleware } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.post('/register', authController.register);
router.post('/login', authController.login);
router.post('/register-provider', upload.any(), authController.registerProvider);
router.post('/forgot-password', authController.requestPasswordReset);
router.post('/reset-password', authController.resetPassword);

router.use(authMiddleware);

router.put('/change-password', authController.changePassword);

router.post('/profile-picture', upload.single('profilePicture'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }
    
    const User = require('../models/User');
    const Account = require('../models/Account');
    const profilePictureUrl = `/uploads/profiles/${req.file.filename}`;
    
    const user = await User.findByIdAndUpdate(req.user.userId, { profilePicture: profilePictureUrl });
    
    if (user && user.email) {
      await Account.findOneAndUpdate(
        { email: user.email },
        { profilePicture: profilePictureUrl }
      );
    }
    
    res.json({ 
      message: 'Profile picture updated successfully',
      profilePicture: profilePictureUrl
    });
  } catch (error) {
    console.error('Upload profile picture error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.post('/logout-all', async (req, res) => {
  try {
    res.json({ message: 'Logged out from all devices successfully' });
  } catch (error) {
    console.error('Logout all error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.delete('/account', async (req, res) => {
  try {
    const User = require('../models/User');
    const Account = require('../models/Account');
    const ServiceProvider = require('../models/ServiceProvider');
    const Booking = require('../models/Booking');
    const Dependent = require('../models/Dependent');
    const AuthorizedPerson = require('../models/AuthorizedPerson');
    const Notification = require('../models/Notification');
    
    const userId = req.user.userId;
    const user = await User.findById(userId);
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userEmail = user.email;
    
    await Booking.deleteMany({ $or: [{ clientId: userId }, { providerId: userId }] });
    await ServiceProvider.deleteOne({ userId: userId });
    await Dependent.deleteMany({ clientId: userId });
    await AuthorizedPerson.deleteMany({ $or: [{ clientId: userId }, { userId: userId }] });
    await Notification.deleteMany({ userId: userId });
    await User.findByIdAndDelete(userId);
    
    if (userEmail) {
      await Account.findOneAndDelete({ email: userEmail });
    }
    
    res.json({ message: 'Account deleted successfully' });
  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({ message: error.message });
  }
});

router.get('/profile', async (req, res) => {
  try {
    const User = require('../models/User');
    const Account = require('../models/Account');
    
    const user = await User.findById(req.user.userId).select('-passwordHash');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const account = await Account.findOne({ email: user.email });
    
    res.json({
      ...user.toObject(),
      accountStatus: account?.status || 'active',
      nbReceiving: account?.nb_receiving || 0
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;