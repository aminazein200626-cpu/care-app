import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/client_api_service.dart';
import '../../services/report_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetName;
  final String? targetEmail;     // ✅ جديد: البريد الإلكتروني للمستخدم المستهدف (للتبليغ)
  final String? targetRole;

  const ProfileScreen({
    super.key,
    this.targetUserId,
    this.targetName,
    this.targetEmail,
    this.targetRole,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ClientApiService _api = ClientApiService();
  final ReportService _reportService = ReportService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = true;
  bool _isUploading = false;
  bool _notificationsEnabled = true;
  bool _emailAlertsEnabled = false;
  
  Map<String, String> _userInfo = {
    'name': '',
    'email': '',
    'phone': '',
    'nationalId': '',
    'address': '',
    'memberSince': '',
  };
  
  String? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final statusPhotos = await Permission.photos.status;
    final statusCamera = await Permission.camera.status;
    
    if (!statusPhotos.isGranted || !statusCamera.isGranted) {
      await [Permission.photos, Permission.camera].request();
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = widget.targetUserId != null
          ? await _api.getUserProfile(widget.targetUserId!)
          : await _api.getProfile();
      
      setState(() {
        _userInfo = {
          'name': profile['fullName'] ?? '',
          'email': profile['email'] ?? '',
          'phone': profile['phoneNumber'] ?? '',
          'nationalId': profile['nationalId'] ?? 'Not provided',
          'address': profile['address'] ?? '',
          'memberSince': _formatDate(profile['createdAt']),
        };
        _profileImage = profile['profilePicture'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load profile: $e');
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'January 2025';
    try {
      final date = DateTime.parse(dateString);
      final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                      'July', 'August', 'September', 'October', 'November', 'December'];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return 'January 2025';
    }
  }

  Future<bool> _requestGalleryPermission() async {
    final status = await Permission.photos.request();
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      _showError('Gallery permission denied. Please enable it in settings.');
      return false;
    } else if (status.isPermanentlyDenied) {
      _showError('Gallery permission permanently denied. Please enable it in app settings.');
      openAppSettings();
      return false;
    }
    return false;
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      _showError('Camera permission denied. Please enable it in settings.');
      return false;
    } else if (status.isPermanentlyDenied) {
      _showError('Camera permission permanently denied. Please enable it in app settings.');
      openAppSettings();
      return false;
    }
    return false;
  }

  Future<void> _updateProfileImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(ctx);
                final hasPermission = await _requestCameraPermission();
                if (hasPermission) {
                  await _pickImage(ImageSource.camera);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primary),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final hasPermission = await _requestGalleryPermission();
                if (hasPermission) {
                  await _pickImage(ImageSource.gallery);
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final result = await _api.updateProfilePicture(File(pickedFile.path));
      setState(() {
        _profileImage = result['profilePicture'];
        _isUploading = false;
      });
      _showSuccess('Profile picture updated!');
    } catch (e) {
      setState(() => _isUploading = false);
      _showError('Failed to upload image: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  // ✅ زر التبليغ باستخدام البريد الإلكتروني (email2)
  void _showReportDialog() {
    if (widget.targetUserId == null) return;

    // نستخدم البريد الإلكتروني للمستخدم المستهدف (إما من الـ widget أو من _userInfo)
    final targetEmail = widget.targetEmail ?? _userInfo['email'];
    if (targetEmail == null || targetEmail.isEmpty) {
      _showError('Cannot report: no email address for this user');
      return;
    }

    final reasonCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final targetName = widget.targetName ?? _userInfo['name'] ?? 'this user';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Report $targetName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'e.g., Unprofessional behavior...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                _showError('Please provide a reason');
                return;
              }
              Navigator.pop(ctx);
              try {
                await _reportService.createReport(
                  reportedEmail: targetEmail,   // ✅ نرسل البريد الإلكتروني (email2)
                  reason: reasonCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                _showSuccess('Report submitted. Admin will review it.');
              } catch (e) {
                _showError('Failed to submit report: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  void _showEditProfile() {
    if (widget.targetUserId != null) return;

    final nameCtrl = TextEditingController(text: _userInfo['name']);
    final emailCtrl = TextEditingController(text: _userInfo['email']);
    final phoneCtrl = TextEditingController(text: _userInfo['phone']);
    final addressCtrl = TextEditingController(text: _userInfo['address']);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Edit Profile', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 20),
                _sheetField('Full Name', nameCtrl, Icons.person_outline_rounded),
                const SizedBox(height: 14),
                _sheetField('Email', emailCtrl, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _sheetField('Phone', phoneCtrl, Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                _sheetField('Address', addressCtrl, Icons.home_outlined),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        await _api.updateProfile({
                          'fullName': nameCtrl.text,
                          'email': emailCtrl.text,
                          'phoneNumber': phoneCtrl.text,
                          'address': addressCtrl.text,
                        });
                        await _loadProfile();
                        _showSuccess('Profile updated!');
                      } catch (e) {
                        setState(() => _isLoading = false);
                        _showError('Failed to update profile');
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    if (widget.targetUserId != null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String title = widget.targetUserId != null
        ? (widget.targetRole == 'Provider' ? 'Provider Profile' : 'Client Profile')
        : 'My Profile';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (widget.targetUserId != null)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              onPressed: _showReportDialog,
            ),
          if (widget.targetUserId == null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _showEditProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary, width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: ClipOval(
                    child: _isUploading
                        ? const Center(child: CircularProgressIndicator())
                        : _profileImage != null && _profileImage!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _profileImage!,
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(Icons.person, size: 50, color: AppTheme.primary),
                              )
                            : Icon(Icons.person, size: 50, color: AppTheme.primary),
                  ),
                ),
                if (widget.targetUserId == null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _updateProfileImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _userInfo['name']!,
              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Member since ${_userInfo['memberSince']}',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildQuickAccessCard(),
            const SizedBox(height: 20),
            _buildPreferencesCard(),
            const SizedBox(height: 20),
            if (widget.targetUserId == null) _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _infoRow(Icons.person_outline, 'Full Name', _userInfo['name']!),
          _infoRow(Icons.email_outlined, 'Email', _userInfo['email']!),
          _infoRow(Icons.phone_outlined, 'Phone', _userInfo['phone']!),
          _infoRow(Icons.badge_outlined, 'National ID', _userInfo['nationalId']!),
          _infoRow(Icons.home_outlined, 'Address', _userInfo['address']!),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Access', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _quickAccessTile(Icons.family_restroom, 'Dependants', () => Navigator.pushNamed(context, AppRoutes.clientDependents)),
          _quickAccessTile(Icons.verified_user, 'Authorized Persons', () => Navigator.pushNamed(context, AppRoutes.clientAuthorized)),
          _quickAccessTile(Icons.calendar_month, 'My Bookings', () => Navigator.pushNamed(context, AppRoutes.clientBooking)),
          _quickAccessTile(Icons.history, 'Service History', () => Navigator.pushNamed(context, AppRoutes.clientHistory)),
        ],
      ),
    );
  }

  Widget _quickAccessTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildPreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preferences', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Push Notifications'),
            value: _notificationsEnabled,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
            activeColor: AppTheme.primary,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Email Alerts'),
            value: _emailAlertsEnabled,
            onChanged: (v) => setState(() => _emailAlertsEnabled = v),
            activeColor: AppTheme.primary,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout, color: AppTheme.error),
        label: const Text('Sign Out', style: TextStyle(color: AppTheme.error)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _sheetField(String label, TextEditingController ctrl, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }
}