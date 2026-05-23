
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import 'service_history_page.dart';
import 'edit_profile_page.dart';
import 'provider_dashboard.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isActive = true;
  bool _isLoading = true;
  bool _isLoadingServices = false;
  bool _isUploadingImage = false;
  String? _profileImage;
  
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic> _providerData = {
    'name': '',
    'email': '',
    'phone': '',
    'location': '',
    'bio': '',
    'hourlyRate': 0,
    'rating': 0,
    'totalServices': 0,
    'completionRate': 0,
    'responseTime': '',
    'certificates': [],
    'services': [],
    'ccp': '',
    'bankAccount': {
      'bankName': '',
      'accountNumber': '',
      'accountHolder': '',
      'rib': '',
    },
  };

  final String baseUrl = ApiConfig.baseUrl;

  // ==================== دوال مساعدة آمنة ====================
  String _safeString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    if (value is Map) {
      if (value.containsKey('fullName')) return value['fullName'].toString();
      if (value.containsKey('name')) return value['name'].toString();
      return defaultValue;
    }
    return value.toString();
  }

  double _safeDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  int _safeInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  List<dynamic> _safeList(dynamic data) {
    if (data is List) return data;
    return [];
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchServices();
  }

  // ==================== جلب البيانات ====================
  Future<void> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final providerDetails = data['providerDetails'] ?? {};
        final bankAccount = providerDetails['bankAccount'] ?? {};

        if (mounted) {
          setState(() {
            _providerData = {
              'name': _safeString(data['fullName']),
              'email': _safeString(data['email']),
              'phone': _safeString(data['phoneNumber']),
              'location': '${_safeString(data['wilaya'])}, ${_safeString(data['address'])}',
              'bio': _safeString(providerDetails['bio']),
              'hourlyRate': _safeDouble(providerDetails['hourlyRate']),
              'rating': _safeDouble(providerDetails['averageRating']),
              'totalServices': _safeInt(providerDetails['totalServices']),
              'completionRate': _safeInt(providerDetails['completionRate']),
              'responseTime': _safeString(providerDetails['responseTime'], defaultValue: '5 min'),
              'certificates': _safeList(providerDetails['certificates']),
              'services': _providerData['services'],
              'ccp': _safeString(providerDetails['ccp']),
              'bankAccount': {
                'bankName': _safeString(bankAccount['bankName']),
                'accountNumber': _safeString(bankAccount['accountNumber']),
                'accountHolder': _safeString(bankAccount['accountHolder']),
                'rib': _safeString(bankAccount['rib']),
              },
            };
            _profileImage = data['profilePicture'];
            _isActive = data['isActive'] ?? true;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (error) {
      print('Error fetching profile: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoadingServices = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) setState(() => _isLoadingServices = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/services'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _providerData['services'] = data.map((s) => {
              'name': _safeString(s['name']),
              'price': _safeDouble(s['price']),
              'active': s['isActive'] ?? true,
            }).toList();
            _isLoadingServices = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _providerData['services'] = [];
            _isLoadingServices = false;
          });
        }
      }
    } catch (error) {
      print('Error fetching services: $error');
      if (mounted) {
        setState(() {
          _providerData['services'] = [];
          _isLoadingServices = false;
        });
      }
    }
  }

  // ==================== رفع صورة البروفايل ====================
  Future<void> _requestPermissions() async {
    final statusPhotos = await Permission.photos.status;
    final statusCamera = await Permission.camera.status;
    if (!statusPhotos.isGranted || !statusCamera.isGranted) {
      await [Permission.photos, Permission.camera].request();
    }
  }

  Future<void> _updateProfileImage() async {
    await _requestPermissions();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primary),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() => _isUploadingImage = false);
      _showError('No authentication token');
      return;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/provider/profile/picture'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('profilePicture', pickedFile.path));

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      if (response.statusCode == 200) {
        setState(() {
          _profileImage = data['profilePicture'];
          _isUploadingImage = false;
        });
        _showSuccess('Profile picture updated!');
      } else {
        setState(() => _isUploadingImage = false);
        _showError(data['message'] ?? 'Failed to upload');
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      _showError('Upload error: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  // ==================== واجهة المستخدم ====================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ProviderDashboard(providerName: _providerData['name'] ?? 'Provider'),
              ),
            );
          },
        ),
        title: Text("My Profile", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              );
              if (result == true) {
                _fetchProfile();
                _fetchServices();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchProfile();
          await _fetchServices();
        },
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 24),
              _buildStatsGrid(isDark),
              const SizedBox(height: 24),
              _buildProfessionalInfo(isDark),
              const SizedBox(height: 24),
              _buildPaymentInfo(isDark),
              const SizedBox(height: 24),
              _buildServicesSection(isDark),
              const SizedBox(height: 24),
              _buildCertificatesSection(isDark),
              const SizedBox(height: 24),
              _buildActionsSection(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: _isUploadingImage
                    ? const CircularProgressIndicator()
                    : (_profileImage != null && _profileImage!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              _profileImage!,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.person, size: 50, color: AppTheme.primary),
                            ),
                          )
                        : Icon(Icons.person, color: AppTheme.primary, size: 50)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _updateProfileImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _isActive ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(Icons.check, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _providerData['name'],
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(_providerData['email'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(_providerData['rating'].toStringAsFixed(1), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.attach_money, color: AppTheme.primary, size: 14),
                    const SizedBox(width: 4),
                    Text("${_providerData['hourlyRate'].toInt()} DZD/h", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        _statCard(isDark, "Services", "${_providerData['totalServices']}", Icons.work, Colors.blue),
        const SizedBox(width: 12),
        _statCard(isDark, "Completion", "${_providerData['completionRate']}%", Icons.check_circle, Colors.green),
        const SizedBox(width: 12),
        _statCard(isDark, "Response", _providerData['responseTime'], Icons.timer, Colors.orange),
      ],
    );
  }

  Widget _statCard(bool isDark, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Professional Info", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const Divider(height: 24),
          _infoRow(Icons.description, "Bio", _providerData['bio'], isDark),
          const SizedBox(height: 16),
          _infoRow(Icons.location_on, "Location", _providerData['location'], isDark),
          const SizedBox(height: 16),
          _infoRow(Icons.phone, "Phone", _providerData['phone'], isDark),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo(bool isDark) {
    final bankAccount = _providerData['bankAccount'] as Map<String, dynamic>;
    final ccp = _providerData['ccp'] ?? '';
    final hasPaymentInfo = ccp.isNotEmpty ||
        bankAccount['bankName'].isNotEmpty ||
        bankAccount['accountNumber'].isNotEmpty ||
        bankAccount['rib'].isNotEmpty;

    if (!hasPaymentInfo) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Payment Information", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const Divider(height: 24),
          if (ccp.isNotEmpty) _infoRow(Icons.credit_card, "CCP", ccp, isDark),
          if (bankAccount['bankName'].isNotEmpty) _infoRow(Icons.account_balance, "Bank Name", bankAccount['bankName'], isDark),
          if (bankAccount['accountNumber'].isNotEmpty) _infoRow(Icons.numbers, "Account Number", bankAccount['accountNumber'], isDark),
          if (bankAccount['accountHolder'].isNotEmpty) _infoRow(Icons.person, "Account Holder", bankAccount['accountHolder'], isDark),
          if (bankAccount['rib'].isNotEmpty) _infoRow(Icons.receipt, "RIB", bankAccount['rib'], isDark),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                Text(value.isEmpty ? '—' : value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(bool isDark) {
    final services = _providerData['services'] as List;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("My Services", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              if (_isLoadingServices)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                TextButton(onPressed: _fetchServices, child: const Text("Refresh", style: TextStyle(color: AppTheme.primary))),
            ],
          ),
          const Divider(height: 24),
          if (_isLoadingServices)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))
          else if (services.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("No services found")))
          else
            ...services.map<Widget>((service) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: service['active'] ? Colors.green : Colors.grey, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(service['name'], style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
                  Text("${(service['price'] as double).toInt()} DZD", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildCertificatesSection(bool isDark) {
    final certificates = _providerData['certificates'] as List;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Certificates", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const Divider(height: 24),
          if (certificates.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("No certificates found")))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: certificates.map<Widget>((cert) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: AppTheme.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(cert.toString(), style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                  ],
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          _actionButton(
            icon: Icons.history,
            label: "Service History",
            color: Colors.blue,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceHistoryPage()));
            },
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _actionButton(
            icon: Icons.visibility,
            label: _isActive ? "Deactivate Profile" : "Activate Profile",
            color: _isActive ? Colors.red : Colors.green,
            onTap: () {
              setState(() => _isActive = !_isActive);
              // يمكن إضافة API call لتحديث الحالة هنا
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 14),
          ],
        ),
      ),
    );
  }
}