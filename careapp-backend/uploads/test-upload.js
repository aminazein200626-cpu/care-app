const express = require('express');
const multer = require('multer');
const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname)
});

const upload = multer({ storage });

router.post('/test-upload', upload.array('certificates'), (req, res) => {
  console.log('Files received:', req.files);
  console.log('Body:', req.body);
  res.json({ message: 'Upload test successful', files: req.files });
});

module.exports = router;