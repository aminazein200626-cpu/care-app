process.env.JWT_SECRET = 'my_super_secret_key_12345';

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const dotenv = require('dotenv');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const path = require('path');
const fs = require('fs');
const multer = require('multer');

dotenv.config();

process.env.JWT_SECRET = 'my_super_secret_key_12345';

console.log('JWT_SECRET is set to:', process.env.JWT_SECRET ? 'YES' : 'NO');

const app = express();
const server = http.createServer(app);

const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});
app.set('io', io);

const allowedOrigins = [
  'http://localhost:5173',
  'http://localhost:3000',
  'http://10.0.2.2:5173',
  'http://192.168.1.3:5001',
  'http://10.0.2.2:5001',
  'capacitor://localhost',
  'ionic://localhost',
  '*'
];
app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    if (allowedOrigins.some(allowed => origin.startsWith(allowed.replace('*', '')))) {
      callback(null, true);
    } else {
      console.log(`CORS blocked: ${origin}`);
      callback(null, true);
    }
  },
  credentials: true
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

const uploadsDir = path.join(__dirname, 'uploads');
const profilesDir = path.join(uploadsDir, 'profiles');
const documentsDir = path.join(uploadsDir, 'documents');

[uploadsDir, profilesDir, documentsDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

app.use('/uploads', express.static(uploadsDir));

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname)
});
const upload = multer({ storage });

app.post('/api/test/upload', upload.array('certificates'), (req, res) => {
  console.log('📁 Test upload - Files received:', req.files?.length || 0);
  console.log('📄 Test upload - Files:', req.files);
  console.log('📋 Test upload - Body:', req.body);
  res.json({ message: 'Upload test successful', files: req.files, body: req.body });
});

app.get('/', (req, res) => {
  res.json({ message: 'CareApp API is running' });
});

app.get('/api/public/categories', async (req, res) => {
  try {
    const Category = require('./models/Category');
    const categories = await Category.find().select('_id name');
    res.json(categories);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/api/public/services', async (req, res) => {
  try {
    const Service = require('./models/Service');
    const services = await Service.find({ isActive: true }).select('_id name category categoryId price');
    res.json(services);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

const authRoutes = require('./routes/authRoutes');
app.use('/api/auth', authRoutes);

const adminRoutes = require('./routes/adminRoutes');
app.use('/api/admin', adminRoutes);

const providerRoutes = require('./routes/providerRoutes');
app.use('/api/provider', providerRoutes);

const clientRoutes = require('./routes/clientRoutes');
app.use('/api/client', clientRoutes);

const authorizedRoutes = require('./routes/authorizedRoutes');
app.use('/api/authorized', authorizedRoutes);

const clientSearchRoutes = require('./routes/clientSearchRoutes');
app.use('/api/search', clientSearchRoutes);

const bookingRoutes = require('./routes/bookingRoutes');
app.use('/api', bookingRoutes);

const notificationRoutes = require('./routes/notificationRoutes');
app.use('/api', notificationRoutes);

// ✅ إضافة مسار التقارير
const reportRoutes = require('./routes/reportRoutes');
app.use('/api/reports', reportRoutes);

// ✅ إضافة مسار التقييمات (Feedback)
const feedbackRoutes = require('./routes/feedbackRoutes');
app.use('/api/feedback', feedbackRoutes);

const connectDB = require('./config/db');
connectDB();

const Notification = require('./models/Notification');
const Booking = require('./models/Booking');

io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) {
    return next(new Error('Authentication required'));
  }
  jwt.verify(token, process.env.JWT_SECRET, (err, decoded) => {
    if (err) return next(new Error('Invalid token'));
    socket.userId = decoded.userId;
    socket.userRole = decoded.role;
    next();
  });
});

const onlineUsers = new Map();

io.on('connection', (socket) => {
  console.log(`✅ Client connected: ${socket.id} (User: ${socket.userId})`);
  
  if (socket.userId) {
    onlineUsers.set(socket.userId, socket.id);
    io.emit('userOnline', { userId: socket.userId, online: true });
  }
  
  socket.on('join', (userId) => {
    if (userId === socket.userId) {
      socket.join(userId);
    }
  });
  
  socket.on('updateLocation', async (data) => {
    const { bookingId, lat, lng } = data;
    try {
      const booking = await Booking.findOne({ _id: bookingId, providerId: socket.userId });
      if (booking) {
        booking.providerLat = lat;
        booking.providerLng = lng;
        await booking.save();
        io.to(`tracking_${bookingId}`).emit('locationUpdate', { lat, lng });
      }
    } catch (err) {
      console.error('Location update error:', err);
    }
  });
  
  socket.on('joinTracking', async (data) => {
    const { bookingId } = data;
    try {
      const booking = await Booking.findById(bookingId);
      if (booking && (booking.providerId?.toString() === socket.userId || 
          booking.clientId?.toString() === socket.userId || 
          booking.authorizedPersonId?.toString() === socket.userId)) {
        socket.join(`tracking_${bookingId}`);
      }
    } catch (err) {}
  });
  
  socket.on('trackingUpdate', async (data) => {
    const { bookingId, stage, providerLat, providerLng, workStep, attachment } = data;
    try {
      const booking = await Booking.findOne({ _id: bookingId, providerId: socket.userId });
      if (!booking) return;
      
      if (stage && stage !== booking.trackingStage) {
        const stageTimes = booking.stageTimes || {};
        const now = new Date();
        stageTimes[stage] = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
        booking.stageTimes = stageTimes;
        booking.trackingStage = stage;
      }
      if (providerLat && providerLng) {
        booking.providerLat = providerLat;
        booking.providerLng = providerLng;
      }
      if (workStep?.description) {
        const workSteps = booking.workSteps || [];
        workSteps.push({
          description: workStep.description,
          note: workStep.note || '',
          fileUrl: workStep.fileUrl || null,
          time: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }),
          timestamp: new Date().toISOString()
        });
        booking.workSteps = workSteps;
      }
      if (attachment?.type) {
        const attachments = booking.attachments || [];
        attachments.push({
          type: attachment.type,
          url: attachment.url || '',
          caption: attachment.caption || '',
          time: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }),
          timestamp: new Date().toISOString()
        });
        booking.attachments = attachments;
      }
      booking.lastUpdate = new Date();
      if (stage === 'Completed') booking.status = 'Completed';
      await booking.save();
      
      io.to(`tracking_${bookingId}`).emit('trackingUpdate', {
        bookingId,
        stage: booking.trackingStage,
        providerLat: booking.providerLat,
        providerLng: booking.providerLng,
        stageTimes: booking.stageTimes,
        workSteps: booking.workSteps,
        attachments: booking.attachments,
        clientTasks: booking.clientTasks
      });
    } catch (err) {}
  });
  
  socket.on('disconnect', () => {
    if (socket.userId) {
      onlineUsers.delete(socket.userId);
      io.emit('userOffline', { userId: socket.userId });
    }
  });
});

app.use((err, req, res, next) => {
  console.error('Error:', err.message);
  res.status(err.status || 500).json({ message: err.message || 'Internal server error' });
});

const PORT = process.env.PORT || 5001; 
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📡 Test upload endpoint: http://localhost:${PORT}/api/test/upload`);
});