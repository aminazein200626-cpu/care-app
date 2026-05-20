const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const ServiceProvider = require('../models/ServiceProvider');
const Service = require('../models/Service');
const Booking = require('../models/Booking');
const Dependent = require('../models/Dependent');

// ==================== البحث عن المزودين مع التصفية ====================
router.get('/providers', async (req, res) => {
  try {
    const { wilaya, municipality, serviceId, rating, hourlyRate, sortBy, page = 1, limit = 20 } = req.query;

    let filter = {
      status: 'active',
      isVerified: true
    };

    // التصفية حسب الموقع
    if (wilaya) filter.wilaya = wilaya;
    if (municipality) filter.municipality = municipality;

    // التصفية حسب الخدمة
    if (serviceId) {
      filter.services = serviceId;
    }

    let query = ServiceProvider.find(filter)
      .select('-documents')
      .limit(parseInt(limit))
      .skip((parseInt(page) - 1) * parseInt(limit));

    // التصفية حسب التقييم
    if (rating) {
      query = query.where('averageRating').gte(parseFloat(rating));
    }

    // التصفية حسب السعر
    if (hourlyRate) {
      const maxPrice = parseFloat(hourlyRate);
      query = query.where('hourlyRate').lte(maxPrice);
    }

    // الترتيب
    if (sortBy === 'rating') {
      query = query.sort({ averageRating: -1 });
    } else if (sortBy === 'price_low') {
      query = query.sort({ hourlyRate: 1 });
    } else if (sortBy === 'price_high') {
      query = query.sort({ hourlyRate: -1 });
    } else if (sortBy === 'experience') {
      query = query.sort({ yearsOfExperience: -1 });
    } else {
      query = query.sort({ createdAt: -1 });
    }

    const providers = await query;
    const total = await ServiceProvider.countDocuments(filter);

    res.json({
      success: true,
      count: providers.length,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / parseInt(limit)),
      data: providers
    });
  } catch (error) {
    console.error('Search providers error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== البحث عن الخدمات ====================
router.get('/services', async (req, res) => {
  try {
    const { search, categoryId, sortBy, page = 1, limit = 20 } = req.query;

    let filter = { isActive: true };

    // البحث بالاسم أو الوصف
    if (search) {
      filter.$or = [
        { name: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } }
      ];
    }

    // التصفية حسب الفئة
    if (categoryId) {
      filter.category = categoryId;
    }

    let query = Service.find(filter)
      .populate('category')
      .limit(parseInt(limit))
      .skip((parseInt(page) - 1) * parseInt(limit));

    // الترتيب
    if (sortBy === 'price_low') {
      query = query.sort({ basePrice: 1 });
    } else if (sortBy === 'price_high') {
      query = query.sort({ basePrice: -1 });
    } else if (sortBy === 'rating') {
      query = query.sort({ averageRating: -1 });
    } else {
      query = query.sort({ createdAt: -1 });
    }

    const services = await query;
    const total = await Service.countDocuments(filter);

    res.json({
      success: true,
      count: services.length,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / parseInt(limit)),
      data: services
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== الحصول على تفاصيل المزود ====================
router.get('/providers/:providerId', async (req, res) => {
  try {
    const { providerId } = req.params;

    const provider = await ServiceProvider.findById(providerId)
      .populate('services')
      .populate('categoryId');

    if (!provider) {
      return res.status(404).json({
        success: false,
        message: 'المزود غير موجود'
      });
    }

    // الحصول على آخر 5 تقييمات
    const reviews = await Booking.find({
      providerId,
      status: 'Completed',
      rating: { $exists: true }
    })
      .select('rating feedback clientId')
      .limit(5)
      .sort({ createdAt: -1 })
      .populate('clientId', 'fullName profilePicture');

    res.json({
      success: true,
      data: {
        provider,
        reviews
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== الحصول على التوفرية ====================
router.get('/providers/:providerId/availability', async (req, res) => {
  try {
    const { providerId } = req.params;

    const provider = await ServiceProvider.findById(providerId);
    if (!provider) {
      return res.status(404).json({
        success: false,
        message: 'المزود غير موجود'
      });
    }

    // تحويل availability من Map إلى Object
    const availability = Object.fromEntries(provider.availability || new Map());

    res.json({
      success: true,
      data: availability
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==================== الحصول على المعالين ====================
router.get('/dependents', authMiddleware, async (req, res) => {
  try {
    const clientId = req.user.userId;

    const dependents = await Dependent.find({ clientId })
      .select('-files'); // عدم إرجاع الملفات مباشرة

    res.json({
      success: true,
      count: dependents.length,
      data: dependents
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

module.exports = router;
