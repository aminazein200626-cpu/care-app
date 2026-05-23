import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../services/client_api_service.dart';
import '../../services/report_service.dart'; // ✅ إضافة خدمة الإبلاغ

class ServiceProvider {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String serviceName;
  final String location;
  final double rating;
  final int reviewCount;
  final double pricePerHour;
  final int yearsOfExperience;
  final String avatar;
  final String bio;
  final bool isAvailable;
  final List<String> specialties;

  ServiceProvider({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.serviceName,
    required this.location,
    required this.rating,
    required this.reviewCount,
    required this.pricePerHour,
    required this.yearsOfExperience,
    required this.avatar,
    required this.bio,
    required this.isAvailable,
    required this.specialties,
  });

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    String extractedServiceName = 'Care Service';
    if (json['services'] != null && json['services'] is List && json['services'].isNotEmpty) {
      final firstService = json['services'][0];
      if (firstService is String && firstService.isNotEmpty) {
        extractedServiceName = firstService;
      } else if (firstService is Map && firstService['name'] != null) {
        extractedServiceName = firstService['name'];
      }
    } else if (json['serviceNames'] != null && json['serviceNames'] is List && json['serviceNames'].isNotEmpty) {
      extractedServiceName = json['serviceNames'][0].toString();
    } else if (json['service'] != null && json['service'].toString().isNotEmpty) {
      extractedServiceName = json['service'].toString();
    }

    double hourlyRate = (json['hourlyRate'] ?? 0).toDouble();
    if (hourlyRate == 0) hourlyRate = 3000;

    return ServiceProvider(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['fullName'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phoneNumber'] ?? '',
      serviceName: extractedServiceName,
      location: json['wilaya'] ?? json['location'] ?? '',
      rating: (json['averageRating'] ?? 0).toDouble(),
      reviewCount: json['totalReviews'] ?? 0,
      pricePerHour: hourlyRate,
      yearsOfExperience: json['yearsOfExperience'] ?? 0,
      avatar: json['profilePicture'] ?? '',
      bio: json['bio'] ?? '',
      isAvailable: json['status'] == 'active',
      specialties: List<String>.from(json['specialties'] ?? []),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final ClientApiService _api = ClientApiService();
  final ReportService _reportService = ReportService(); // ✅ خدمة الإبلاغ
  final TextEditingController _searchCtrl = TextEditingController();

  List<String> _wilayas = ['All'];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _services = [];

  String _selectedWilaya = 'All';
  String _selectedCategoryId = 'All';
  String _selectedServiceId = 'All';
  double _maxPrice = 5000;
  double _minRating = 0;

  String _searchQuery = '';
  bool _isLoading = true;
  List<ServiceProvider> _allProviders = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _loadInitialData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final wilayas = await _api.getUniqueWilayas();
      setState(() {
        _wilayas = ['All', ...wilayas];
      });

      final categories = await _api.getCategories();
      setState(() {
        _categories = categories.map((c) => {
          'id': c['_id'].toString(),
          'name': c['name'].toString(),
        }).toList();
      });

      final services = await _api.getServices();
      setState(() {
        _services = services.map((s) => ({
          'id': s['_id'].toString(),
          'name': s['name'].toString(),
          'categoryId': s['categoryId']?.toString(),
        })).toList();
      });

      await _loadProviders();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load data: $e');
    }
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    try {
      final providersData = await _api.searchProviders(
        wilaya: _selectedWilaya == 'All' ? null : _selectedWilaya,
        categoryId: _selectedCategoryId == 'All' ? null : _selectedCategoryId,
        serviceId: _selectedServiceId == 'All' ? null : _selectedServiceId,
        rating: _minRating > 0 ? _minRating : null,
        hourlyRate: _maxPrice < 5000 ? _maxPrice : null,
      );
      setState(() {
        _allProviders = providersData.map((p) => ServiceProvider.fromJson(p)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load providers: $e');
    }
  }

  List<ServiceProvider> get _filteredProviders {
    return _allProviders.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.serviceName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.location.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_selectedCategoryId == 'All') return _services;
    return _services.where((s) => s['categoryId'] == _selectedCategoryId).toList();
  }

  // ✅ نافذة الإبلاغ عن المزود
  void _showReportDialog(ServiceProvider provider) {
    final reasonCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Report ${provider.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'e.g., Unprofessional behavior, Late arrival...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Provide more details...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _reportService.createReport(
                  reportedId: provider.id,
                  reason: reasonCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted. Admin will review it.'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to submit report: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  void _showProviderDetail(ServiceProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الصورة والاسم والتقييم
                      Row(
                        children: [
                          ClipOval(
                            child: provider.avatar.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: provider.avatar,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 72,
                                      height: 72,
                                      color: AppTheme.primaryContainer,
                                      child: const Icon(Icons.person_rounded,
                                          color: AppTheme.primary, size: 36),
                                    ),
                                  )
                                : Container(
                                    width: 72,
                                    height: 72,
                                    color: AppTheme.primaryContainer,
                                    child: const Icon(Icons.person_rounded,
                                        color: AppTheme.primary, size: 36),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.serviceName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Color(0xFFF59E0B), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${provider.rating.toStringAsFixed(1)} (${provider.reviewCount} reviews)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // معلومات الاتصال (هاتف - إيميل)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _contactRow(
                              icon: Icons.phone_android,
                              label: 'Phone',
                              value: provider.phone,
                              onTap: () => _makePhoneCall(provider.phone),
                            ),
                            const Divider(height: 16),
                            _contactRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: provider.email,
                              onTap: () => _sendEmail(provider.email),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // تفاصيل إضافية (ولاية، خبرة، سعر)
                      Row(
                        children: [
                          _detailChip(Icons.location_on_outlined, provider.location),
                          const SizedBox(width: 10),
                          _detailChip(Icons.work_outline, '${provider.yearsOfExperience} years exp'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _detailChip(Icons.attach_money_rounded,
                              '${provider.pricePerHour.toInt()} DZD/hr'),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: provider.isAvailable
                                  ? AppTheme.success.withAlpha(25)
                                  : AppTheme.error.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              provider.isAvailable ? 'Available' : 'Busy',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: provider.isAvailable
                                    ? AppTheme.success
                                    : AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // السيرة الذاتية
                      Text('About',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        provider.bio.isNotEmpty
                            ? provider.bio
                            : 'Professional healthcare provider dedicated to quality care.',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
                      ),
                      const SizedBox(height: 20),

                      // التخصصات
                      if (provider.specialties.isNotEmpty) ...[
                        Text('Specialties',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: provider.specialties.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer.withAlpha(80),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(s,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary)),
                          )).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // زر الحجز
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: provider.isAvailable
                              ? () {
                                  Navigator.pop(ctx);
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.selectDependant,
                                    arguments: {
                                      'providerId': provider.id,
                                      'providerName': provider.name,
                                      'serviceName': provider.serviceName,
                                      'hourlyRate': provider.pricePerHour,
                                    },
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Book Now',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ✅ زر الإبلاغ عن المزود
                      OutlinedButton.icon(
                        onPressed: () => _showReportDialog(provider),
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        label: const Text('Report Provider'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: value.isNotEmpty ? onTap : null,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: AppTheme.textMuted)),
                Text(value.isNotEmpty ? value : 'Not provided',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: value.isNotEmpty
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted)),
              ],
            ),
          ),
          if (value.isNotEmpty)
            Icon(Icons.open_in_new, size: 16, color: AppTheme.primary),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final Uri telUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      _showError('Cannot make call to $phone');
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      _showError('Cannot send email to $email');
    }
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search providers...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 14, color: AppTheme.textMuted),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: AppTheme.textMuted, size: 22),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded,
                                          color: AppTheme.textMuted, size: 20),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      const BorderSide(color: AppTheme.divider)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      const BorderSide(color: AppTheme.divider)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: AppTheme.primary, width: 2)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Wilaya',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _wilayas.map((w) {
                                final isSelected = _selectedWilaya == w;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedWilaya = w;
                                      _loadProviders();
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primary
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : AppTheme.divider),
                                    ),
                                    child: Text(
                                      w,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Category',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategoryId = 'All';
                                      _selectedServiceId = 'All';
                                      _loadProviders();
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _selectedCategoryId == 'All'
                                          ? AppTheme.primary
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: _selectedCategoryId == 'All'
                                              ? AppTheme.primary
                                              : AppTheme.divider),
                                    ),
                                    child: Text('All',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _selectedCategoryId == 'All'
                                              ? Colors.white
                                              : AppTheme.textSecondary,
                                        )),
                                  ),
                                ),
                                ..._categories.map((c) {
                                  final isSelected =
                                      _selectedCategoryId == c['id'];
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedCategoryId = c['id'];
                                        _selectedServiceId = 'All';
                                        _loadProviders();
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primary
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: isSelected
                                                ? AppTheme.primary
                                                : AppTheme.divider),
                                      ),
                                      child: Text(c['name'],
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : AppTheme.textSecondary,
                                          )),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_selectedCategoryId != 'All') ...[
                            Text('Service',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedServiceId = 'All';
                                        _loadProviders();
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: _selectedServiceId == 'All'
                                            ? AppTheme.primary
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: _selectedServiceId == 'All'
                                                ? AppTheme.primary
                                                : AppTheme.divider),
                                      ),
                                      child: Text('All',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _selectedServiceId == 'All'
                                                ? Colors.white
                                                : AppTheme.textSecondary,
                                          )),
                                    ),
                                  ),
                                  ..._filteredServices.map((s) {
                                    final isSelected =
                                        _selectedServiceId == s['id'];
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedServiceId = s['id'];
                                          _loadProviders();
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: isSelected
                                                  ? AppTheme.primary
                                                  : AppTheme.divider),
                                        ),
                                        child: Text(s['name'],
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppTheme.textSecondary,
                                            )),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Max Price (DZD)',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textMuted)),
                                    Slider(
                                      value: _maxPrice,
                                      min: 500,
                                      max: 5000,
                                      divisions: 9,
                                      label: '${_maxPrice.toInt()} DZD',
                                      onChanged: (val) {
                                        setState(() {
                                          _maxPrice = val;
                                          _loadProviders();
                                        });
                                      },
                                      activeColor: AppTheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Min Rating',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textMuted)),
                                    Slider(
                                      value: _minRating,
                                      min: 0,
                                      max: 5,
                                      divisions: 5,
                                      label: '${_minRating.toStringAsFixed(1)} ★',
                                      onChanged: (val) {
                                        setState(() {
                                          _minRating = val;
                                          _loadProviders();
                                        });
                                      },
                                      activeColor: AppTheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_filteredProviders.length} provider${_filteredProviders.length != 1 ? 's' : ''} found',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (_filteredProviders.isEmpty)
                    SliverFillRemaining(child: _buildEmpty())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                          child: _buildProviderCard(_filteredProviders[i]),
                        ),
                        childCount: _filteredProviders.length,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Find a Provider',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search by name, type, or location',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard(ServiceProvider provider) {
    return GestureDetector(
      onTap: () => _showProviderDetail(provider),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipOval(
                    child: provider.avatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: provider.avatar,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              color: AppTheme.primaryContainer,
                              child: const Icon(Icons.person_rounded,
                                  color: AppTheme.primary, size: 30),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: AppTheme.primaryContainer,
                            child: const Icon(Icons.person_rounded,
                                color: AppTheme.primary, size: 30),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: provider.isAvailable
                            ? AppTheme.success
                            : AppTheme.textMuted,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider.name,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text(provider.serviceName,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 3),
                        Text('${provider.rating.toStringAsFixed(1)}',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        const SizedBox(width: 4),
                        Text('(${provider.reviewCount})',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: AppTheme.textMuted)),
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 2),
                        Text(provider.location,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${provider.pricePerHour.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                  Text('DZD/hr',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textMuted, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppTheme.primaryContainer.withAlpha(80),
                shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded,
                color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text('No Providers Found',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Try adjusting your search\nor filter criteria.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}