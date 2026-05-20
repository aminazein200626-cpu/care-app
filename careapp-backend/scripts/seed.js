const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const User = require('../models/User');
const Category = require('../models/Category');
const Service = require('../models/Service');
const Booking = require('../models/Booking');

const seed = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/careapp');
    console.log('✅ Connected to MongoDB');

    // 1. حذف البيانات القديمة (اختياري)
    // await User.deleteMany({});
    // await Category.deleteMany({});
    // await Service.deleteMany({});
    // console.log('Old data cleared');

    // 2. إنشاء Admin (إذا لم يوجد)
    const existingAdmin = await User.findOne({ email: 'admin@careapp.com' });
    if (!existingAdmin) {
      const hashedPassword = await bcrypt.hash('admin123', 10);
      const admin = new User({
        fullName: 'System Admin',
        email: 'admin@careapp.com',
        passwordHash: hashedPassword,
        phoneNumber: '0555123456',
        role: 'Admin',
        isActive: true,
        isVerified: true
      });
      await admin.save();
      console.log('✅ Admin created');
    }

    // 3. إنشاء الفئات (Categories)
    const categories = [
      { name: 'Nursing Care', description: 'Professional nursing services at home' },
      { name: 'Babysitting', description: 'Child care and babysitting services' },
      { name: 'Elderly Care', description: 'Care and companionship for seniors' },
      { name: 'Physical Therapy', description: 'Rehabilitation and physiotherapy' },
      { name: 'Medical Assistance', description: 'Medical appointments and follow-ups' }
    ];

    for (const cat of categories) {
      const existing = await Category.findOne({ name: cat.name });
      if (!existing) {
        await Category.create(cat);
        console.log(`✅ Category created: ${cat.name}`);
      }
    }

    // 4. إنشاء الخدمات (Services)
    const services = [
      { name: 'Newborn Specialist', category: 'Babysitting', price: 3500, description: 'Expert care for newborns 0-3 months', isActive: true },
      { name: 'Night Nurse', category: 'Nursing Care', price: 5000, description: 'Overnight nursing care (8 hours)', isActive: true },
      { name: 'Elderly Companion', category: 'Elderly Care', price: 4000, description: 'Companionship and daily assistance', isActive: true },
      { name: 'Physical Therapy Session', category: 'Physical Therapy', price: 2500, description: '1-hour physiotherapy session', isActive: true },
      { name: 'Medical Appointment Assistant', category: 'Medical Assistance', price: 2000, description: 'Accompany to doctor appointments', isActive: true },
      { name: 'Babysitter (Daytime)', category: 'Babysitting', price: 1800, description: '4 hours of babysitting', isActive: true },
      { name: 'Post-Surgery Care', category: 'Nursing Care', price: 6000, description: 'Specialized care after surgery', isActive: true }
    ];

    for (const svc of services) {
      const existing = await Service.findOne({ name: svc.name });
      if (!existing) {
        await Service.create(svc);
        console.log(`✅ Service created: ${svc.name}`);
      }
    }

    // 5. إنشاء عميل تجريبي (Client)
    const existingClient = await User.findOne({ email: 'client@example.com' });
    if (!existingClient) {
      const hashedPassword = await bcrypt.hash('client123', 10);
      const client = new User({
        fullName: 'Ahmed Benali',
        email: 'client@example.com',
        passwordHash: hashedPassword,
        phoneNumber: '0555123457',
        address: '123 Rue Didouche Mourad',
        wilaya: 'Algiers',
        postalCode: '16000',
        role: 'Client',
        isActive: true,
        isVerified: true
      });
      await client.save();
      console.log('✅ Client created: client@example.com / client123');
    }

    // 6. إنشاء مقدم خدمة تجريبي (Provider)
    const existingProvider = await User.findOne({ email: 'provider@example.com' });
    if (!existingProvider) {
      const hashedPassword = await bcrypt.hash('provider123', 10);
      const provider = new User({
        fullName: 'Fatima Zahra',
        email: 'provider@example.com',
        passwordHash: hashedPassword,
        phoneNumber: '0555123458',
        address: '45 Rue Larbi Ben Mhidi',
        wilaya: 'Oran',
        postalCode: '31000',
        role: 'Provider',
        isActive: true,
        isVerified: true
      });
      await provider.save();

      // إضافة تفاصيل مقدم الخدمة
      const ServiceProvider = require('../models/ServiceProvider');
      const providerDetails = new ServiceProvider({
        providerId: provider._id,
        bio: 'Experienced nurse with 5 years of home care experience',
        hourlyRate: 2500,
        yearsOfExp: 5,
        workHours: '9 AM - 6 PM',
        averageRating: 4.8,
        totalServices: 42,
        completionRate: 98
      });
      await providerDetails.save();
      console.log('✅ Provider created: provider@example.com / provider123');
    }

    console.log('\n🎉 Seeding completed successfully!');
    console.log('\n📝 Login credentials:');
    console.log('Admin:    admin@careapp.com / admin123');
    console.log('Client:   client@example.com / client123');
    console.log('Provider: provider@example.com / provider123');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
};

seed();