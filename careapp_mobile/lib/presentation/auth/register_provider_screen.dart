import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../../core/app_routes.dart';

class RegisterProviderScreen extends StatefulWidget {
  const RegisterProviderScreen({super.key});

  @override
  State<RegisterProviderScreen> createState() => _RegisterProviderScreenState();
}

class _RegisterProviderScreenState extends State<RegisterProviderScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isLoadingServices = false;
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final TextEditingController _confirmPasswordController = TextEditingController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _selectedGender;
  final List<String> _genders = ['Male', 'Female'];

  // ✅ حقول جديدة للسعر والخبرة
  final TextEditingController _hourlyRateController = TextEditingController();
  final TextEditingController _yearsOfExpController = TextEditingController();

  final TextEditingController _postalController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _selectedWilaya;
  final List<String> _wilayas = [
    '01 Adrar', '02 Chlef', '03 Laghouat', '04 Oum El Bouaghi', '05 Batna',
    '06 Bejaia', '07 Biskra', '08 Bechar', '09 Blida', '10 Bouira',
    '11 Tamanrasset', '12 Tebessa', '13 Tlemcen', '14 Tiaret', '15 Tizi Ouzou',
    '16 Algiers', '17 Djelfa', '18 Jijel', '19 Setif', '20 Saida',
    '21 Skikda', '22 Sidi Bel Abbes', '23 Annaba', '24 Guelma', '25 Constantine',
    '26 Medea', '27 Mostaganem', '28 M\'Sila', '29 Mascara', '30 Ouargla',
    '31 Oran', '32 El Bayadh', '33 Illizi', '34 Bordj Bou Arreridj',
    '35 Boumerdes', '36 El Tarf', '37 Tindouf', '38 Tissemsilt', '39 El Oued',
    '40 Khenchela', '41 Souk Ahras', '42 Tipaza', '43 Mila', '44 Ain Defla',
    '45 Naama', '46 Ain Temouchent', '47 Ghardaia', '48 Relizane'
  ];

  final TextEditingController _travelDistanceKmController = TextEditingController();
  final TextEditingController _travelCostController = TextEditingController(text: "0");
  bool _travelEnabled = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _services = [];
  String? _selectedCategoryId;
  List<String> _selectedServicesIds = [];

  List<String> _selectedDays = [];
  String _selectedTimeFrom = '08:00 AM';
  String _selectedTimeTo = '06:00 PM';

  final TextEditingController _motivationController = TextEditingController();

  XFile? _profileImage;
  XFile? _idCardImage;
  XFile? _licenseImage;
  final List<XFile> _certificateImages = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> _availableTimes = [
    '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
    '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM',
    '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM'
  ];

  final List<String> _daysList = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchServices();
  }

  String _formatPhoneNumber(String rawPhone) {
    String cleaned = rawPhone.trim();
    if (cleaned.startsWith('+213')) return cleaned;
    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
    return '+213$cleaned';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    _dateOfBirthController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _hourlyRateController.dispose();
    _yearsOfExpController.dispose();
    _postalController.dispose();
    _addressController.dispose();
    _travelDistanceKmController.dispose();
    _travelCostController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.publicCategories}'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _categories = data.map((c) => ({
            'id': c['_id'].toString(),
            'name': c['name'].toString(),
          })).toList();
        });
      }
    } catch (error) {
      print('Error: $error');
    }
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoadingServices = true);
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.publicServices}'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _services = data.map((s) => ({
            'id': s['_id'].toString(),
            'name': s['name'].toString(),
            'categoryId': s['categoryId']?.toString(),
          })).toList();
          _isLoadingServices = false;
        });
      } else {
        setState(() => _isLoadingServices = false);
      }
    } catch (error) {
      setState(() => _isLoadingServices = false);
    }
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_selectedCategoryId == null) return [];
    return _services.where((s) => s['categoryId'] == _selectedCategoryId).toList();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        if (type == 'profile') _profileImage = picked;
        if (type == 'id') _idCardImage = picked;
        if (type == 'license') _licenseImage = picked;
      });
    }
  }

  Future<void> _pickCertificate() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _certificateImages.add(picked);
      });
    }
  }

  void _removeCertificate(int index) {
    setState(() {
      _certificateImages.removeAt(index);
    });
  }

  void _toggleService(String serviceId) {
    setState(() {
      if (_selectedServicesIds.contains(serviceId)) {
        _selectedServicesIds.remove(serviceId);
      } else {
        _selectedServicesIds.add(serviceId);
      }
    });
  }

  bool _validateStep() {
    if (_currentStep == 0) {
      if (_nameController.text.isEmpty ||
          _nationalIdController.text.isEmpty ||
          _phoneController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _passwordController.text.isEmpty ||
          _selectedGender == null) {
        _showError("Please fill all fields");
        return false;
      }
      if (!_emailController.text.contains('@')) {
        _showError("Please enter a valid email");
        return false;
      }
      if (_passwordController.text.length < 6) {
        _showError("Password must be at least 6 characters");
        return false;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError("Passwords do not match");
        return false;
      }
      String phone = _phoneController.text.trim();
      String formattedPhone = _formatPhoneNumber(phone);
      if (formattedPhone.length < 12 || formattedPhone.length > 14) {
        _showError("Phone number must start with +213 and have 12-14 digits");
        return false;
      }
    }
    if (_currentStep == 1) {
      if (_selectedWilaya == null || _addressController.text.isEmpty || _postalController.text.isEmpty) {
        _showError("Please fill all location fields");
        return false;
      }
      if (_selectedCategoryId == null) {
        _showError("Please select a service category");
        return false;
      }
      if (_selectedServicesIds.isEmpty) {
        _showError("Please select at least one service");
        return false;
      }
      if (_selectedDays.isEmpty) {
        _showError("Please select at least one available day");
        return false;
      }
    }
    if (_currentStep == 2) {
      if (_profileImage == null || _idCardImage == null || _licenseImage == null) {
        _showError("Please upload all required documents");
        return false;
      }
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _submitRegistration() async {
    if (!_validateStep()) return;
    setState(() => _isSubmitting = true);

    try {
      final selectedServicesNames = _selectedServicesIds
          .map((id) => _services.firstWhere((s) => s['id'] == id)['name'])
          .toList();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerProvider}'),
      );

      String formattedPhone = _formatPhoneNumber(_phoneController.text);

      request.fields['fullName'] = _nameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['password'] = _passwordController.text;
      request.fields['phoneNumber'] = formattedPhone;
      request.fields['address'] = _addressController.text;
      request.fields['wilaya'] = _selectedWilaya ?? '';
      request.fields['postalCode'] = _postalController.text;
      request.fields['bio'] = _motivationController.text.isNotEmpty ? _motivationController.text : 'Professional healthcare provider';
      
      // ✅ إرسال السعر والخبرة من الحقول الجديدة
      request.fields['hourlyRate'] = _hourlyRateController.text.trim().isEmpty ? '0' : _hourlyRateController.text;
      request.fields['yearsOfExp'] = _yearsOfExpController.text.trim().isEmpty ? '0' : _yearsOfExpController.text;
      
      request.fields['workHours'] = '$_selectedTimeFrom - $_selectedTimeTo';
      request.fields['preferredTimeSlots'] = _selectedDays.join(',');
      request.fields['travelDistance'] = _travelEnabled ? _travelDistanceKmController.text.trim() : '0';
      request.fields['travelCost'] = _travelCostController.text;
      request.fields['services'] = jsonEncode(selectedServicesNames);
      request.fields['categoryId'] = _selectedCategoryId ?? '';
      request.fields['role'] = 'Provider';
      request.fields['gender'] = _selectedGender ?? '';
      request.fields['nationalId'] = _nationalIdController.text.trim();
      request.fields['dateOfBirth'] = _dateOfBirthController.text.trim();
      request.fields['motivation'] = _motivationController.text.trim();
      request.fields['travelEnabled'] = _travelEnabled.toString();

      if (_profileImage != null) {
        request.files.add(await http.MultipartFile.fromPath('profilePicture', _profileImage!.path));
      }
      if (_idCardImage != null) {
        request.files.add(await http.MultipartFile.fromPath('idCard', _idCardImage!.path));
      }
      if (_licenseImage != null) {
        request.files.add(await http.MultipartFile.fromPath('license', _licenseImage!.path));
      }
      
      for (int i = 0; i < _certificateImages.length; i++) {
        request.files.add(await http.MultipartFile.fromPath('certificate_$i', _certificateImages[i].path));
      }
      print('Sending ${_certificateImages.length} certificates');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 201) {
        _showSuccessDialog();
      } else {
        _showError(data['message'] ?? 'Registration failed');
      }
    } catch (error) {
      print('Error: $error');
      _showError('Connection error. Please try again.');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Registration Submitted"),
        content: const Text("Your application has been submitted for review."),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text("Go to Login"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Provider Registration", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStepper(isDark),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildStepContent(isDark),
                  ),
                ),
                _buildNavigationButtons(isDark),
              ],
            ),
    );
  }

  Widget _buildStepper(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _stepIndicator(0, "Personal", _currentStep >= 0, isDark),
          _stepLine(_currentStep > 0, isDark),
          _stepIndicator(1, "Services", _currentStep >= 1, isDark),
          _stepLine(_currentStep > 1, isDark),
          _stepIndicator(2, "Documents", _currentStep >= 2, isDark),
        ],
      ),
    );
  }

  Widget _stepIndicator(int step, String label, bool isActive, bool isDark) {
    bool isCompleted = _currentStep > step;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? Colors.green : (isActive ? AppTheme.primary : Colors.grey[300]),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text("${step + 1}", style: TextStyle(color: isActive ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: isActive ? (isDark ? Colors.white : Colors.black87) : Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _stepLine(bool isActive, bool isDark) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isActive ? AppTheme.primary : Colors.grey[300],
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfo(isDark);
      case 1:
        return _buildServicesLocation(isDark);
      case 2:
        return _buildDocuments(isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildPersonalInfo(bool isDark) {
    return Column(
      children: [
        _buildSection("Personal Information", isDark, [
          _buildTextField(_nameController, "Full Name", Icons.person_outline, isDark),
          const SizedBox(height: 16),
          _buildTextField(_nationalIdController, "National ID Number", Icons.badge_outlined, isDark, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _buildDropdown("Gender", _genders, _selectedGender, (v) => setState(() => _selectedGender = v), Icons.wc_outlined, isDark),
          const SizedBox(height: 16),
          _buildDatePickerField(isDark),
          const SizedBox(height: 16),
          _buildPhoneField(isDark),
          const SizedBox(height: 16),
          _buildTextField(_emailController, "Email Address", Icons.email_outlined, isDark, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          // ✅ حقول السعر والخبرة
          _buildTextField(_hourlyRateController, "Hourly Rate (DZD)", Icons.attach_money, isDark, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _buildTextField(_yearsOfExpController, "Years of Experience", Icons.work_outline, isDark, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _buildPasswordField(isDark),
          const SizedBox(height: 16),
          _buildConfirmPasswordField(isDark),
        ]),
      ],
    );
  }

  Widget _buildDatePickerField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Date of Birth", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _dateOfBirthController.text.isEmpty ? "Select Date of Birth" : _dateOfBirthController.text,
                    style: TextStyle(color: _dateOfBirthController.text.isEmpty ? Colors.grey : (isDark ? Colors.white : Colors.black87)),
                  ),
                ),
                Icon(Icons.calendar_today, color: AppTheme.primary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Phone Number", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: InputDecoration(
            hintText: "5XXXXXXXX (9 digits after +213)",
            prefixIcon: Icon(Icons.phone_android, color: AppTheme.primary),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return "Required";
            if (v.length < 9) return "Invalid phone number";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Password", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: "At least 6 characters",
            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) => v == null || v.isEmpty ? "Required" : null,
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Confirm Password", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: "Re-enter your password",
            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) => v == null || v.isEmpty ? "Required" : null,
        ),
      ],
    );
  }

  Widget _buildServicesLocation(bool isDark) {
    return Column(
      children: [
        _buildSection("Location", isDark, [
          _buildDropdown("Select Wilaya", _wilayas, _selectedWilaya, (v) => setState(() => _selectedWilaya = v), Icons.map_outlined, isDark),
          const SizedBox(height: 16),
          _buildTextField(_postalController, "Postal Code", Icons.local_post_office_outlined, isDark, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _buildTextField(_addressController, "Full Address", Icons.home_work_outlined, isDark),
        ]),
        const SizedBox(height: 20),
        _buildSection("Select Service Category", isDark, [
          if (_categories.isEmpty)
            const Center(child: Text("Loading categories..."))
          else
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              hint: const Text("Select Category"),
              decoration: InputDecoration(
                labelText: "Category",
                prefixIcon: Icon(Icons.category_outlined, color: AppTheme.primary),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              items: _categories.map<DropdownMenuItem<String>>((c) {
                return DropdownMenuItem<String>(
                  value: c['id'].toString(),
                  child: Text(c['name'].toString()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                  _selectedServicesIds.clear();
                });
              },
            ),
        ]),
        if (_selectedCategoryId != null) ...[
          const SizedBox(height: 20),
          _buildSection("Select Services", isDark, [
            if (_isLoadingServices)
              const Center(child: CircularProgressIndicator())
            else if (_filteredServices.isEmpty)
              const Center(child: Text("No services available"))
            else
              ..._filteredServices.map((service) => CheckboxListTile(
                value: _selectedServicesIds.contains(service['id']),
                onChanged: (v) => _toggleService(service['id']),
                title: Text(service['name'], style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              )),
          ]),
        ],
        const SizedBox(height: 20),
        _buildSection("Availability", isDark, [
          Text("Preferred Days", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _daysList.map((day) {
              bool isSelected = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(day);
                    } else {
                      _selectedDays.add(day);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : (isDark ? const Color(0xFF0F172A) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey[400]!),
                  ),
                  child: Text(day.substring(0, 3), style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
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
        ]),
        const SizedBox(height: 20),
        _buildTravelSection(isDark),
      ],
    );
  }

  Widget _buildTravelSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            TextField(
              controller: _travelDistanceKmController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Travel Distance (km)",
                hintText: "e.g., 50",
                prefixIcon: Icon(Icons.straighten, color: AppTheme.primary),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
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

  Widget _buildDocuments(bool isDark) {
    return Column(
      children: [
        _buildUploadCard("Profile Picture", Icons.person, _profileImage, () => _pickImage(ImageSource.gallery, 'profile'), isDark),
        const SizedBox(height: 16),
        _buildUploadCard("National ID Card", Icons.credit_card, _idCardImage, () => _pickImage(ImageSource.gallery, 'id'), isDark),
        const SizedBox(height: 16),
        _buildUploadCard("Professional License", Icons.verified, _licenseImage, () => _pickImage(ImageSource.gallery, 'license'), isDark),
        const SizedBox(height: 16),
        _buildSection("Certificates (Optional)", isDark, [
          ..._certificateImages.asMap().entries.map((entry) {
            int idx = entry.key;
            XFile cert = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(cert.name, style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
                  IconButton(onPressed: () => _removeCertificate(idx), icon: const Icon(Icons.close, color: Colors.red)),
                ],
              ),
            );
          }),
          TextButton.icon(onPressed: _pickCertificate, icon: const Icon(Icons.add), label: const Text("Add Certificate"), style: TextButton.styleFrom(foregroundColor: AppTheme.primary)),
        ]),
        const SizedBox(height: 16),
        _buildSection("Why do you want to join?", isDark, [
          _buildTextField(_motivationController, "Tell us why you want to become a provider", Icons.description_outlined, isDark, maxLines: 3),
        ]),
      ],
    );
  }

  Widget _buildUploadCard(String title, IconData icon, XFile? image, VoidCallback onTap, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: image != null ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(image.path), fit: BoxFit.cover)) : Icon(icon, color: AppTheme.primary, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                Text(image != null ? image.name : "No file selected", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: Text(image != null ? "Change" : "Upload", style: TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
  }

  Widget _buildSection(String title, bool isDark, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, bool isDark, {TextInputType keyboardType = TextInputType.text, bool obscureText = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.primary),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) => v == null || v.isEmpty ? "Required" : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(String hint, List<String> items, String? value, Function(String?) onChanged, IconData icon, bool isDark) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primary),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      items: items.map<DropdownMenuItem<String>>((e) {
        return DropdownMenuItem<String>(
          value: e,
          child: Text(e),
        );
      }).toList(),
      onChanged: onChanged,
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
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              items: _availableTimes.map<DropdownMenuItem<String>>((t) {
                return DropdownMenuItem<String>(
                  value: t,
                  child: Text(t),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  side: BorderSide(color: AppTheme.primary),
                ),
                child: const Text("BACK", style: TextStyle(color: AppTheme.primary)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () {
                if (_validateStep()) {
                  if (_currentStep < 2) {
                    setState(() => _currentStep++);
                  } else {
                    _submitRegistration();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_currentStep == 2 ? "SUBMIT" : "CONTINUE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}