const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const User = require('../models/User');

const createAdmin = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/careapp');
    
    const existingAdmin = await User.findOne({ email: 'admin@careapp.com' });
    if (existingAdmin) {
      console.log('Admin already exists');
      process.exit();
    }
    
    const hashedPassword = await bcrypt.hash('admin123', 10);
    
    const admin = new User({
      fullName: 'System Administrator',
      email: 'admin@careapp.com',
      passwordHash: hashedPassword,
      phoneNumber: '0555123456',
      role: 'Admin',
      isActive: true,
      isVerified: true
    });
    
    await admin.save();
    console.log('✅ Admin created successfully!');
    console.log('Email: admin@careapp.com');
    console.log('Password: admin123');
    process.exit();
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
};

createAdmin();