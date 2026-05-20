import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import 'provider_dashboard.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isUploading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController();
  final TextEditingController _newCertController = TextEditingController();

  // Payment fields
  final TextEditingController _ccpController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountHolderController = TextEditingController();
  final TextEditingController _ribController = TextEditingController();

  XFile? _profileImage;
  String? _profilePictureUrl;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _services = [];
  List<String> _certificates = [];
  List<String> _selectedDays = [];
  String _selectedTimeFrom = '08:00 AM';
  String _selectedTimeTo = '06:00 PM';
  bool _travelEnabled = false;
  String _travelDistance = 'Local Only';
  final TextEditingController _travelCostController = TextEditingController(text: "0");

  final List<String> _availableTimes = [
    '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
    '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM',
    '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM'
  ];

  final List<String> _daysList = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  final String baseUrl = ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchServices();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() => _isLoading = false);
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

        setState(() {
          _nameController.text = data['fullName'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _locationController.text = '${data['wilaya'] ?? ''}, ${data['address'] ?? ''}';
          _bioController.text = providerDetails['bio'] ?? '';
          _hourlyRateController.text = (providerDetails['hourlyRate'] ?? 0).toString();
          _profilePictureUrl = data['profilePicture'];
          _selectedDays = providerDetails['workDays'] != null
              ? List<String>.from(providerDetails['workDays'])
              : [];
          _selectedTimeFrom = providerDetails['workStartTime'] ?? '08:00 AM';
          _selectedTimeTo = providerDetails['workEndTime'] ?? '06:00 PM';
          _travelEnabled = providerDetails['travelEnabled'] ?? false;
          _travelDistance = providerDetails['travelDistance'] ?? 'Local Only';
          _travelCostController.text = (providerDetails['travelCost'] ?? 0).toString();
          _certificates = providerDetails['certificates'] != null
              ? List<String>.from(providerDetails['certificates'])
              : [];
          _ccpController.text = providerDetails['ccp'] ?? '';
          _bankNameController.text = bankAccount['bankName'] ?? '';
          _accountNumberController.text = bankAccount['accountNumber'] ?? '';
          _accountHolderController.text = bankAccount['accountHolder'] ?? '';
          _ribController.text = bankAccount['rib'] ?? '';
        });
      }
    } catch (error) {
      print('Error fetching profile: $error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchServices() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/services'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _services = data.map((s) => ({
            'id': s['_id'] ?? s['id'],
            'name': s['name'],
            'price': s['price'].toString(),
            'active': true,
          })).toList();
        });
      } else {
        print('Failed to load services: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching services: $error');
    }
  }

  Future<void> _uploadProfileImage(XFile? imageFile) async {
    if (imageFile == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    setState(() => _isUploading = true);
    try {
      File file = File(imageFile.path);
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/provider/profile/picture'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('profilePicture', file.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = jsonDecode(responseData);
        setState(() {
          _profileImage = imageFile;
          _profilePictureUrl = jsonData['profilePicture'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated"), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload image: $error"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) await _uploadProfileImage(picked);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final profileResponse = await http.put(
        Uri.parse('$baseUrl/api/provider/profile'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': _nameController.text,
          'phoneNumber': _phoneController.text,
          'address': _locationController.text.split(',').last.trim(),
          'wilaya': _locationController.text.split(',').first.trim(),
          'postalCode': '',
        }),
      );
      if (profileResponse.statusCode != 200) throw Exception('Failed to update profile');

      final professionalResponse = await http.put(
        Uri.parse('$baseUrl/api/provider/profile/professional'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'bio': _bioController.text,
          'hourlyRate': int.tryParse(_hourlyRateController.text) ?? 0,
          'workDays': _selectedDays,
          'workStartTime': _selectedTimeFrom,
          'workEndTime': _selectedTimeTo,
          'travelEnabled': _travelEnabled,
          'travelDistance': _travelDistance,
          'travelCost': int.tryParse(_travelCostController.text) ?? 0,
          'certificates': _certificates,
          'ccp': _ccpController.text,
          'bankAccount': {
            'bankName': _bankNameController.text,
            'accountNumber': _accountNumberController.text,
            'accountHolder': _accountHolderController.text,
            'rib': _ribController.text,
          }
        }),
      );
      if (professionalResponse.statusCode != 200) throw Exception('Failed to update professional info');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProviderDashboard(providerName: "Provider")),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $error"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addCertificate() {
    if (_newCertController.text.trim().isNotEmpty) {
      setState(() {
        _certificates.add(_newCertController.text.trim());
        _newCertController.clear();
      });
    }
  }

  void _removeCertificate(int index) {
    setState(() => _certificates.removeAt(index));
  }

  void _toggleService(int index) {
    setState(() => _services[index]['active'] = !_services[index]['active']);
  }

  void _updateServicePrice(int index, String price) {
    setState(() => _services[index]['price'] = price);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _hourlyRateController.dispose();
    _newCertController.dispose();
    _travelCostController.dispose();
    _ccpController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _ribController.dispose();
    super.dispose();
  }

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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Edit Profile", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _saveProfile,
            child: Text("Save", style: TextStyle(color: _isUploading ? Colors.white70 : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfileImage(isDark),
              const SizedBox(height: 24),
              _buildPersonalInfo(isDark),
              const SizedBox(height: 24),
              _buildProfessionalInfo(isDark),
              const SizedBox(height: 24),
              _buildPaymentInfo(isDark),
              const SizedBox(height: 24),
              _buildServicesSection(isDark),
              const SizedBox(height: 24),
              _buildCertificatesSection(isDark),
              const SizedBox(height: 24),
              _buildAvailabilitySection(isDark),
              const SizedBox(height: 24),
              _buildTravelSection(isDark),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: _isUploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(bool isDark) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primary, width: 3)),
            child: ClipOval(
              child: _profileImage != null
                  ? Image.file(File(_profileImage!.path), fit: BoxFit.cover, width: 120, height: 120)
                  : (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty)
                      ? Image.network('$baseUrl$_profilePictureUrl!', fit: BoxFit.cover, width: 120, height: 120,
                          errorBuilder: (_, __, ___) => Container(color: AppTheme.primary.withOpacity(0.1), child: Icon(Icons.person, size: 60, color: AppTheme.primary)))
                      : Container(color: AppTheme.primary.withOpacity(0.1), child: Icon(Icons.person, size: 60, color: AppTheme.primary)),
            ),
          ),
          Positioned(
            bottom: 0, right: 0,
            child: GestureDetector(
              onTap: _isUploading ? null : _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF0F172A) : Colors.white, width: 2)),
                child: _isUploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text("Personal Information", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          _buildTextField(controller: _nameController, label: "Full Name", icon: Icons.person_outline, isDark: isDark),
          const SizedBox(height: 16),
          _buildTextField(controller: _emailController, label: "Email Address", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, isDark: isDark, enabled: false),
          const SizedBox(height: 16),
          _buildTextField(controller: _phoneController, label: "Phone Number", icon: Icons.phone_android, keyboardType: TextInputType.phone, isDark: isDark),
          const SizedBox(height: 16),
          _buildTextField(controller: _locationController, label: "Location (Wilaya, Address)", icon: Icons.location_on_outlined, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildProfessionalInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text("Professional Information", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          _buildTextField(controller: _bioController, label: "Bio", icon: Icons.description_outlined, maxLines: 3, isDark: isDark),
          const SizedBox(height: 16),
          _buildTextField(controller: _hourlyRateController, label: "Hourly Rate (DZD)", icon: Icons.attach_money, keyboardType: TextInputType.number, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text("Payment Information (for receiving money)", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          _buildTextField(controller: _ccpController, label: "CCP Number", icon: Icons.credit_card, isDark: isDark),
          const SizedBox(height: 16),
          _buildTextField(controller: _bankNameController, label: "Bank Name", icon: Icons.account_balance, isDark: isDark),
          const SizedBox(height: 16),
          _buildTextField(controller: _accountNumberController, label: "Account Number", icon: Icons.numbers, isDark: isDark),
          const SizedBox(height: 16),
          _buildTextField(controller: _accountHolderController, label: "Account Holder Name", icon: Icons.person, isDark: isDark),
          const SizedBox(height: 16),
          _buildTextField(controller: _ribController, label: "RIB", icon: Icons.receipt, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildServicesSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text("Services Offered", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          ..._services.asMap().entries.map((entry) {
            int idx = entry.key;
            var service = entry.value;
            return _serviceTile(idx, service['name'], service['price'], service['active'], isDark);
          }),
          if (_services.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("No services available"))),
        ],
      ),
    );
  }

  Widget _serviceTile(int index, String name, String price, bool isActive, bool isDark) {
    TextEditingController priceController = TextEditingController(text: price);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? AppTheme.primary.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: priceController,
              onChanged: (value) => _updateServicePrice(index, value),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                prefixText: "DZD ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ),
          Switch(value: isActive, onChanged: (_) => _toggleService(index), activeColor: AppTheme.primary),
        ],
      ),
    );
  }

  Widget _buildCertificatesSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text("Certificates", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCertController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Add new certificate...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                child: IconButton(onPressed: _addCertificate, icon: const Icon(Icons.add, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _certificates.asMap().entries.map((entry) {
              int idx = entry.key;
              String cert = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: AppTheme.primary, size: 14),
                    const SizedBox(width: 6),
                    Text(cert, style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                    const SizedBox(width: 6),
                    GestureDetector(onTap: () => _removeCertificate(idx), child: Icon(Icons.close, size: 14, color: Colors.grey[500])),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilitySection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text("Availability", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          Text("Preferred Days", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _daysList.map((day) {
              bool isSelected = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () => setState(() => isSelected ? _selectedDays.remove(day) : _selectedDays.add(day)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : (isDark ? const Color(0xFF0F172A) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey[400]!),
                  ),
                  child: Text(day.substring(0, 3), style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTimeDropdown("From", _selectedTimeFrom, (v) => setState(() => _selectedTimeFrom = v!), isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildTimeDropdown("To", _selectedTimeTo, (v) => setState(() => _selectedTimeTo = v!), isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTravelSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Travel Options", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
              Switch(value: _travelEnabled, onChanged: (v) => setState(() => _travelEnabled = v), activeColor: AppTheme.primary),
            ],
          ),
          if (_travelEnabled) ...[
            const SizedBox(height: 16),
            Text("Travel Distance", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                _travelChip("Local Only", _travelDistance, isDark),
                const SizedBox(width: 12),
                _travelChip("Regional", _travelDistance, isDark),
                const SizedBox(width: 12),
                _travelChip("Nationwide", _travelDistance, isDark),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _travelCostController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Additional Travel Cost (DZD)",
                prefixIcon: Icon(Icons.local_taxi, color: AppTheme.primary),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _travelChip(String label, String selected, bool isDark) {
    bool isSelected = _travelDistance == label;
    return GestureDetector(
      onTap: () => setState(() => _travelDistance = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : (isDark ? const Color(0xFF0F172A) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey[400]!),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isDark = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: (value) => (value == null || value.isEmpty) ? "This field is required" : null,
    );
  }

  Widget _buildTimeDropdown(String label, String value, Function(String?) onChanged, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: AppTheme.primary),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
              items: _availableTimes.map((time) => DropdownMenuItem(value: time, child: Text(time))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
