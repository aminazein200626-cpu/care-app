import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../core/app_theme.dart';
import '../../core/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedRole = 'client';
  bool _isLoading = false;
  
  // Common fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Provider specific fields
  final _nationalIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _wilayaController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nationalIdController.dispose();
    _addressController.dispose();
    _wilayaController.dispose();
    _postalCodeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (_selectedRole == 'client') {
        await authService.registerClient({
          'fullName': _nameController.text,
          'email': _emailController.text,
          'phoneNumber': _phoneController.text,
          'password': _passwordController.text,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Please login.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      } else {
        await authService.registerProvider({
          'fullName': _nameController.text,
          'email': _emailController.text,
          'phoneNumber': _phoneController.text,
          'password': _passwordController.text,
          'nationalId': _nationalIdController.text,
          'address': _addressController.text,
          'wilaya': _wilayaController.text,
          'postalCode': _postalCodeController.text,
          'bio': _bioController.text,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration submitted for review!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role Selection
              Text(
                'I want to register as',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildRoleCard(
                      'client',
                      'Client',
                      'I need care services',
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRoleCard(
                      'provider',
                      'Service Provider',
                      'I provide care services',
                      Icons.medical_services_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Common Fields
              _buildTextField(
                _nameController,
                'Full Name',
                Icons.person_outline,
                'Enter your full name',
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                _emailController,
                'Email Address',
                Icons.email_outlined,
                'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                _phoneController,
                'Phone Number',
                Icons.phone_outlined,
                '+213 5XX XX XX XX',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                _passwordController,
                'Password',
                Icons.lock_outline,
                'At least 6 characters',
                isPassword: true,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                _confirmPasswordController,
                'Confirm Password',
                Icons.lock_outline,
                'Re-enter your password',
                isPassword: true,
              ),
              
              // Provider Specific Fields
              if (_selectedRole == 'provider') ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                Text(
                  'Professional Information',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  _nationalIdController,
                  'National ID Number',
                  Icons.badge_outlined,
                  'Enter your national ID',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  _wilayaController,
                  'Wilaya',
                  Icons.location_city_outlined,
                  'Select your wilaya',
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  _addressController,
                  'Address',
                  Icons.home_outlined,
                  'Your full address',
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  _postalCodeController,
                  'Postal Code',
                  Icons.local_post_office_outlined,
                  'Postal code',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  _bioController,
                  'Bio / Experience',
                  Icons.description_outlined,
                  'Tell us about your experience',
                  maxLines: 3,
                  isPassword: false,
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Register Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _selectedRole == 'client' ? 'CREATE ACCOUNT' : 'SUBMIT APPLICATION',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    },
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String value, String title, String subtitle, IconData icon) {
    final isSelected = _selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildTextField(
  TextEditingController controller,
  String label,
  IconData icon,
  String hint, {
  TextInputType keyboardType = TextInputType.text,
  bool isPassword = false,
  int maxLines = 1,
}) {
  // منع isPassword مع maxLines > 1
  final bool obscureText = isPassword && maxLines == 1;
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines > 1 ? 12 : 14,  // ✅ هذا صحيح
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          if (label == 'Password' && value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
      ),
    ],
  );
}
}