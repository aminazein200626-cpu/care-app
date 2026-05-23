const express = require('express');
const router = express.Router();
const { authMiddleware, adminOnly } = require('../middleware/auth');
const reportController = require('../controllers/reportController');

router.use(authMiddleware);


router.post('/', reportController.createReport);


router.get('/my-reports', reportController.getMyReports);


router.get('/by-email/:email', adminOnly, reportController.getReportsByEmail);

module.exports = router;