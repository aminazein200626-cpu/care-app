import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/app_theme.dart';
import '../../services/authorized_api_service.dart';

class AuthorizedProviderProfileScreen extends StatefulWidget {
  final String providerId;
  final String providerName;

  const AuthorizedProviderProfileScreen({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<AuthorizedProviderProfileScreen> createState() => _AuthorizedProviderProfileScreenState();
}

class _AuthorizedProviderProfileScreenState extends State<AuthorizedProviderProfileScreen> {
  final AuthorizedApiService _api = AuthorizedApiService();
  bool _isLoading = true;
  Map<String, dynamic> _provider = {};

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    setState(() => _isLoading = true);
    try {
      final provider = await _api.getProviderProfile(widget.providerId);
      setState(() {
        _provider = provider;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading provider: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.providerName),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 20),
                  _buildProfessionalInfo(isDark),
                  const SizedBox(height: 20),
                  _buildStats(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final profilePicture = _provider['profilePicture'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            child: profilePicture != null && profilePicture.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: profilePicture,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.person,
                        size: 40,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : Icon(Icons.person, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _provider['fullName'] ?? widget.providerName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _provider['wilaya'] ?? 'Location not specified',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      _provider['providerDetails']?['averageRating']?.toString() ?? '4.5',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${_provider['providerDetails']?['totalServices'] ?? 0} services)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalInfo(bool isDark) {
    final details = _provider['providerDetails'] ?? {};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Professional Information',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Divider(height: 24),
          _infoRow('Bio', details['bio'] ?? 'No bio provided', isDark),
          const SizedBox(height: 12),
          _infoRow('Hourly Rate', '${details['hourlyRate'] ?? 0} DZD', isDark),
          const SizedBox(height: 12),
          _infoRow('Experience', '${details['yearsOfExp'] ?? 0} years', isDark),
          const SizedBox(height: 12),
          _infoRow('Work Hours', details['workHours'] ?? 'Flexible', isDark),
        ],
      ),
    );
  }

  Widget _buildStats(bool isDark) {
    final details = _provider['providerDetails'] ?? {};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _statItem('Services', '${details['totalServices'] ?? 0}', isDark),
          _statItem('Rating', details['averageRating']?.toString() ?? '0', isDark),
          _statItem('Completion', '${details['completionRate'] ?? 98}%', isDark),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}