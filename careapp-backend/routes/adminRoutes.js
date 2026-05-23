const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const reportController = require('../controllers/reportController');
const { authMiddleware, adminOnly } = require('../middleware/auth');

router.use(authMiddleware);
router.use(adminOnly);

// Users
router.get('/users', adminController.getAllUsers);
router.get('/users/:id', adminController.getUserById);
router.put('/users/:id/block', adminController.toggleBlockUser);

// Provider Requests
router.get('/requests', adminController.getPendingRequests);
router.put('/requests/:id/verify', adminController.verifyProvider);
router.put('/providers/:id/documents', adminController.updateProviderDocuments);

// Reports
router.get('/reports', reportController.getAllReports);

// Categories
router.get('/categories', adminController.getCategories);
router.post('/categories', adminController.addCategory);
router.put('/categories/:id', adminController.updateCategory);
router.delete('/categories/:id', adminController.deleteCategory);

// Services
router.get('/services', adminController.getServices);
router.post('/services', adminController.addService);
router.put('/services/:id', adminController.updateService);
router.delete('/services/:id', adminController.deleteService);

// Bookings
router.get('/bookings', adminController.getBookings);
router.put('/bookings/:id/status', adminController.updateBookingStatus);

// Stats & Reports
router.get('/stats', adminController.getStats);
router.get('/service-reports', adminController.getServiceReports);

router.get('/stats/chart', async (req, res) => {
  try {
    const { period } = req.query;
    let data = [];
    if (period === 'week') {
      data = [28, 32, 35, 42, 48, 52, 45];
    } else if (period === 'month') {
      data = [120, 145, 168, 190, 210, 198, 185, 172, 168, 156, 142, 138, 125, 118, 110, 105, 98, 95, 92, 88, 85, 82, 78, 75, 72, 70, 68, 65, 62, 60];
    } else if (period === 'year') {
      data = [1450, 1680, 1820, 1950, 2100, 2250, 2400, 2350, 2280, 2150, 1980, 1820];
    }
    res.json({ data });
  } catch (error) {
    console.error('Get chart data error:', error);
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;