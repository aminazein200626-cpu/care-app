const User = require('../models/User');
const Account = require('../models/Account');
const ServiceProvider = require('../models/ServiceProvider');
const Client = require('../models/Client');
const Providing = require('../models/Providing');
const InscriptionRequest = require('../models/InscriptionRequest');
const Document = require('../models/Document');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const sendEmail = async (to, subject, text) => {
  if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
    console.error('EMAIL_USER or EMAIL_PASS not set in .env');
    return;
  }

  const transporter = nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });

  const mailOptions = {
    from: `"CareApp Support" <${process.env.EMAIL_USER}>`,
    to: to,
    subject: subject,
    text: text,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log(`Email sent to ${to} - Message ID: ${info.messageId}`);
  } catch (error) {
    console.error(`Error sending email to ${to}:`, error.message);
    console.error('Full error:', error);
  }
};

const generateToken = (userId, role, email) => {
  const adminEmails = ['admin@careapp.com', 'admin@example.com'];
  const finalRole = adminEmails.includes(email) ? 'Admin' : role;
  return jwt.sign(
    { userId, role: finalRole, email, isAdmin: finalRole === 'Admin' },
    process.env.JWT_SECRET || 'my_super_secret_key_12345',
    { expiresIn: '7d' }
  );
};

// ==================== Register a new client ====================
exports.register = async (req, res) => {
  try {
    const { 
      fullName, email, password, phoneNumber, role,
      nationalId, wilaya, postalCode, address 
    } = req.body;

    if (!fullName || !email || !password) {
      return res.status(400).json({ message: 'Full name, email and password are required' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const account = new Account({
      email: email,
      password: hashedPassword,
      status: 'active',
      nb_receiving: 0
    });
    await account.save();

    const user = new User({
      fullName,
      email,
      passwordHash: hashedPassword,
      accountEmail: email,
      phoneNumber: phoneNumber || '',
      address: address || '',
      wilaya: wilaya || '',
      postalCode: postalCode || '',
      nationalId: nationalId || '',
      role: role || 'Client',
      isActive: true,
      isVerified: true
    });
    await user.save();

    if (user.role === 'Client') {
      const newClient = new Client({
        userId: user._id,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber || '',
        address: address || '',
        wilaya: wilaya || '',
        postalCode: postalCode || '',
        nationalId: nationalId || '',
        isActive: true,
        isVerified: true,
        status: 'active'
      });
      await newClient.save();

      // Save ID card image to Document collection
      if (req.file) {
        const document = new Document({
          clientId: newClient._id,
          name: req.file.originalname,
          link: req.file.path,
          type: 'idCard',
          mimeType: req.file.mimetype,
          size: req.file.size
        });
        await document.save();
        console.log(`ID card saved for client ${newClient._id}`);
      }
    }

    res.status(201).json({ 
      message: 'User created successfully', 
      userId: user._id 
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ message: error.message });
  }
};

exports.login = async (req, res) => {
  try {
    let { email, password } = req.body;
    email = email.toLowerCase().trim();

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const account = await Account.findOne({ email });
    if (!account) {
      console.log(`❌ Account not found: ${email}`);
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    let isValid = false;
    if (account.password) {
      isValid = await bcrypt.compare(password, account.password);
    } else if (account.psw) {
      isValid = await bcrypt.compare(password, account.psw);
    }

    if (!isValid) {
      console.log(`❌ Invalid password for: ${email}`);
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    let user = await User.findOne({ email });
    if (!user) {
      // إنشاء مستخدم افتراضي إذا لم يكن موجوداً (لأغراض التوافق)
      user = new User({
        fullName: email.split('@')[0],
        email: email,
        passwordHash: account.password || account.psw,
        phoneNumber: '',
        role: 'AuthorizedPerson'
      });
      await user.save();
      console.log(`🆕 Created missing user for ${email}`);
    }

    if (user.role === 'Provider' && !user.isVerified) {
      return res.status(401).json({ message: 'Your account is pending admin approval.' });
    }

    const adminEmails = ['admin@careapp.com', 'admin@example.com'];
    const finalRole = adminEmails.includes(email) ? 'Admin' : user.role;
    const token = jwt.sign(
      { userId: user._id, role: finalRole, email: user.email, isAdmin: finalRole === 'Admin' },
      process.env.JWT_SECRET || 'my_super_secret_key_12345',
      { expiresIn: '7d' }
    );

    account.lastLogin = new Date();
    await account.save();

    console.log(`✅ Login successful: ${email} (${finalRole})`);

    res.json({
      token,
      userId: user._id,
      role: finalRole,
      name: user.fullName || user.username || email.split('@')[0],
      email: user.email,
      phoneNumber: user.phoneNumber || ''
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Register a new provider ====================
exports.registerProvider = async (req, res) => {
  try {
    const {
      fullName, email, password, phoneNumber, address, wilaya, postalCode,
      bio, hourlyRate, yearsOfExp, workHours, preferredTimeSlots,
      travelDistance, travelCost, availableWilayas, services, categoryId,
      gender, nationalId, dateOfBirth, motivation,
      travelEnabled, availabilitySlots
    } = req.body;
    
    console.log('Phone number received:', phoneNumber);
    const cleanEmail = email ? email.trim().toLowerCase() : '';
    
    if (!fullName || !cleanEmail || !password || !phoneNumber) {
      return res.status(400).json({ message: 'Missing required fields' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }

    const existingUser = await User.findOne({ email: cleanEmail });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    let parsedServices = [];
    if (services) {
      try {
        parsedServices = typeof services === 'string' ? JSON.parse(services) : services;
      } catch (e) {}
    }

    let availabilitySlotsParsed = [];
    if (availabilitySlots) {
      try {
        availabilitySlotsParsed = typeof availabilitySlots === 'string' 
          ? JSON.parse(availabilitySlots) : availabilitySlots;
      } catch(e) {}
    }

    const account = new Account({
      email: cleanEmail,
      password: hashedPassword,
      status: 'active',
      nb_receiving: 0
    });
    await account.save();

    const user = new User({
      fullName,
      email: cleanEmail,
      passwordHash: hashedPassword,
      accountEmail: cleanEmail,
      phoneNumber,
      address: address || '',
      wilaya: wilaya || '',
      postalCode: postalCode || '',
      role: 'Provider',
      isActive: true,
      isVerified: false,
      gender: gender || '',
      nationalId: nationalId || '',
      dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : null
    });
    await user.save();

    const travelEnabledValue = travelEnabled === true || travelEnabled === 'true';
    
    let travelDistanceValue = 0;
    if (travelDistance) {
      if (typeof travelDistance === 'string') {
        const match = travelDistance.match(/\d+/);
        travelDistanceValue = match ? parseInt(match[0]) : 0;
      } else {
        travelDistanceValue = parseInt(travelDistance) || 0;
      }
    }

    const provider = new ServiceProvider({
      userid: user._id,
      fullName: fullName,
      email: cleanEmail,
      phoneNumber: phoneNumber || '',
      address: address || '',
      wilaya: wilaya || '',
      postalCode: postalCode || '',
      gender: gender || '',
      nationalId: nationalId || '',
      dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : null,
      bio: bio || '',
      yearsOfExperience: parseInt(yearsOfExp) || 0,
      hourlyRate: parseInt(hourlyRate) || 0,
      workHours: workHours || '',
      travelDistance: travelDistanceValue,
      travelCost: parseInt(travelCost) || 0,
      workOutsideCity: travelEnabledValue,
      services: parsedServices,
      categoryId: categoryId || null,
      documents: [],   // Will be populated from Document table when needed
      certificates: [], // Will be populated from Document table when needed
      status: 'pending',
      motivation: motivation || '',
      averageRating: 0,
      totalServices: 0,
      completionRate: 0,
      availability: '{}',
      createdAt: new Date(),
      updatedAt: new Date()
    });
    await provider.save();
    console.log('Provider saved with ID:', provider._id); 
    
    if (!provider._id) {
      console.error('Provider _id is null!');
      return res.status(500).json({ message: 'Failed to create provider' });
    }

    // Save all uploaded files to Document collection
    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        let docType = '';
        if (file.fieldname === 'profilePicture') docType = 'profilePicture';
        else if (file.fieldname === 'idCard') docType = 'idCard';
        else if (file.fieldname === 'license') docType = 'license';
        else if (file.fieldname.startsWith('certificate')) docType = 'certificate';
        else continue;

        const document = new Document({
          providerId: provider._id,
          name: file.originalname,
          link: file.path,
          type: docType,
          mimeType: file.mimetype,
          size: file.size
        });
        await document.save();
        console.log(`Document saved: ${file.originalname} for provider ${provider._id}`);
      }
    }

    // Create InscriptionRequest
    const inscriptionRequest = new InscriptionRequest({
      providerId: provider._id,
      adminId: null,
      status: 'pending',
      submitted_at: new Date()
    });
    await inscriptionRequest.save();
    console.log('InscriptionRequest created with ID:', inscriptionRequest._id);

    if (availabilitySlotsParsed.length > 0) {
      for (const slot of availabilitySlotsParsed) {
        if (!slot.serviceId) continue;
        const providing = new Providing({
          serviceProviderId: provider._id,
          serviceId: slot.serviceId,
          day_of_week: slot.day,
          start_time: slot.startTime,
          end_time: slot.endTime,
          isBooked: false
        });
        await providing.save();
      }
    }

    const Notification = require('../models/Notification');
    const admin = await User.findOne({ role: 'Admin' });
    if (admin) {
      await Notification.create({
        userId: admin._id,
        title: 'New Provider Registration',
        message: `${fullName} has registered as a provider and is awaiting approval.`,
        type: 'system'
      });
    }

    // Send welcome email to provider
    try {
      const emailSubject = 'Provider Registration Received';
      const emailText = `Dear ${fullName},\n\nThank you for registering as a provider on CareApp.\n\nYour application has been submitted and is now pending review by our admin team. You will receive an email notification once your account is approved.\n\nBest regards,\nCareApp Team`;
      await sendEmail(cleanEmail, emailSubject, emailText);
    } catch (emailErr) {
      console.error('Error sending registration email:', emailErr.message);
    }

    res.status(201).json({ message: 'Provider registration submitted for review', userId: user._id });
  } catch (error) {
    console.error('Provider registration error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Change password ====================
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.userId;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: 'Current password and new password are required' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'New password must be at least 6 characters' });
    }
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    const isValid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isValid) {
      return res.status(401).json({ message: 'Current password is incorrect' });
    }
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    user.passwordHash = hashedPassword;
    await user.save();
    await Account.findOneAndUpdate({ email: user.email }, { psw: hashedPassword });
    res.json({ message: 'Password changed successfully' });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Request password reset ====================
exports.requestPasswordReset = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ message: 'Email is required' });
    }
    const user = await User.findOne({ email });
    if (!user) {
      return res.json({ message: 'If your email is registered, you will receive a reset link.' });
    }
    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetExpires = new Date(Date.now() + 3600000);
    user.resetToken = resetToken;
    user.resetExpires = resetExpires;
    await user.save();
    await Account.findOneAndUpdate({ email: email }, { resetToken: resetToken, resetExpires: resetExpires });
    const isDevelopment = process.env.NODE_ENV !== 'production';
    if (isDevelopment) {
      const resetLink = `${req.protocol}://${req.get('host')}/reset-password?token=${resetToken}`;
      console.log(`Reset link (dev only): ${resetLink}`);
      return res.json({ message: 'Password reset link has been sent to your email.', resetLink });
    }
    res.json({ message: 'If your email is registered, you will receive a reset link.' });
  } catch (error) {
    console.error('Password reset request error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Reset password ====================
exports.resetPassword = async (req, res) => {
  try {
    const { token, newPassword } = req.body;
    if (!token || !newPassword) {
      return res.status(400).json({ message: 'Token and new password are required' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }
    const user = await User.findOne({ resetToken: token, resetExpires: { $gt: new Date() } });
    if (!user) {
      return res.status(400).json({ message: 'Invalid or expired token' });
    }
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    user.passwordHash = hashedPassword;
    user.resetToken = null;
    user.resetExpires = null;
    await user.save();
    await Account.findOneAndUpdate({ email: user.email }, { psw: hashedPassword, resetToken: null, resetExpires: null });
    res.json({ message: 'Password reset successfully' });
  } catch (error) {
    console.error('Password reset error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Refresh token ====================
exports.refreshToken = async (req, res) => {
  try {
    const userId = req.user.userId;
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    const adminEmails = ['admin@careapp.com', 'admin@example.com'];
    const finalRole = adminEmails.includes(user.email) ? 'Admin' : (user.role || 'Client');
    const newToken = jwt.sign(
      { userId: user._id, role: finalRole, email: user.email, isAdmin: finalRole === 'Admin' },
      process.env.JWT_SECRET || 'my_super_secret_key_12345',
      { expiresIn: '7d' }
    );
    res.json({ token: newToken });
  } catch (error) {
    console.error('Refresh token error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Verify email ====================
exports.verifyEmail = async (req, res) => {
  try {
    const { token } = req.params;
    const user = await User.findOne({ verificationToken: token, verificationExpires: { $gt: new Date() } });
    if (!user) {
      return res.status(400).json({ message: 'Invalid or expired token' });
    }
    user.isVerified = true;
    user.verificationToken = null;
    user.verificationExpires = null;
    await user.save();
    await Account.findOneAndUpdate({ email: user.email }, { isVerified: true, verificationToken: null, verificationExpires: null });
    res.json({ message: 'Email verified successfully' });
  } catch (error) {
    console.error('Verify email error:', error);
    res.status(500).json({ message: error.message });
  }
};

// ==================== Resend verification email ====================
exports.resendVerification = async (req, res) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    if (user.isVerified) {
      return res.status(400).json({ message: 'Email already verified' });
    }
    const verificationToken = crypto.randomBytes(32).toString('hex');
    const verificationExpires = new Date(Date.now() + 86400000);
    user.verificationToken = verificationToken;
    user.verificationExpires = verificationExpires;
    await user.save();
    await Account.findOneAndUpdate({ email: email }, { verificationToken: verificationToken, verificationExpires: verificationExpires });
    res.json({ message: 'Verification email sent' });
  } catch (error) {
    console.error('Resend verification error:', error);
    res.status(500).json({ message: error.message });
  }
};