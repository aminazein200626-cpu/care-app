const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const feedbackController = require('../controllers/feedbackController');

// جميع المسارات تحتاج إلى توثيق
router.use(authMiddleware);

// إنشاء تقييم جديد (العميل)
router.post('/', feedbackController.createFeedback);

// الحصول على تقييماتي (التي كتبتها أنا)
router.get('/my-feedbacks', feedbackController.getMyFeedbacks);

// الحصول على تقييمات مزود معين (للجميع)
router.get('/provider/:providerId', feedbackController.getProviderFeedbacks);

// رد المزود على تقييم
router.put('/:id/reply', feedbackController.replyToFeedback);

// حذف تقييم (للأدمن فقط – يمكن إضافة middleware)
router.delete('/:id', feedbackController.deleteFeedback);

module.exports = router;