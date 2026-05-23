const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const reportController = require('../controllers/reportController');

router.use(authMiddleware);

router.post('/', reportController.createReport);
router.get('/my-reports', reportController.getMyReports);

module.exports = router;