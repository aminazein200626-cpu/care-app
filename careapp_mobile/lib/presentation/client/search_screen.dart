import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../services/client_api_service.dart';

class ServiceProvider {
  final String id;
  final String name;
  final String serviceType;
  final String location;
  final double rating;
  final int reviewCount;
  final double pricePerHour;
  final String avatar;
  final String bio;
  final bool isAvailable;
  final List<String> specialties;

  ServiceProvider({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.location,
    required this.rating,
    required this.reviewCount,
    required this.pricePerHour,
    required this.avatar,
    required this.bio,
    required this.isAvailable,
    required this.specialties,
  });

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    // Extract service name from possible fields
    String serviceName = '';
    
    // Try to get from 'service' field
    if (json['service'] != null && json['service'].toString().isNotEmpty) {
      serviceName = json['service'].toString();
    }
    // Try from 'serviceType'
    else if (json['serviceType'] != null && json['serviceType'].toString().isNotEmpty) {
      serviceName = json['serviceType'].toString();
    }
    // Try from 'services' array (list of service objects or strings)
    else if (json['services'] != null && json['services'] is List && json['services'].isNotEmpty) {
      dynamic firstService = json['services'][0];
      if (firstService is Map && firstService['name'] != null) {
        serviceName = firstService['name'];
      } else if (firstService is String) {
        serviceName = firstService;
      } else {
        serviceName = firstService.toString();
      }
    }
    // Try from 'serviceNames' array
    else if (json['serviceNames'] != null && json['serviceNames'] is List && json['serviceNames'].isNotEmpty) {
      serviceName = json['serviceNames'][0].toString();
    }
    // Default if nothing found
    else {
      serviceName = 'Care Service';
    }

    return ServiceProvider(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['fullName'] ?? json['name'] ?? '',
      serviceType: serviceName,
      location: json['wilaya'] ?? json['location'] ?? '',
      rating: (json['averageRating'] ?? json['rating'] ?? 0).toDouble(),
      reviewCount: json['totalReviews'] ?? json['reviewCount'] ?? 0,
      pricePerHour: (json['hourlyRate'] ?? 0).toDouble(),
      avatar: json['profilePicture'] ?? json['avatar'] ?? '',
      bio: json['bio'] ?? '',
      isAvailable: json['isAvailable'] ?? true,
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
  final TextEditingController _searchCtrl = TextEditingController();
  
  String _selectedType = 'All';
  String _selectedLocation = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  List<ServiceProvider> _allProviders = [];
  
  final List<String> _serviceTypes = [
    'All',
    'Super Nanny',
    'Babysitter',
    'Pickup',
    'Elderly Care',
  ];
  
  final List<String> _locations = [
    'All',
    'Algiers',
    'Oran',
    'Constantine',
    'Annaba',
    'Setif',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    
    _loadProviders();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    
    try {
      final providersData = await _api.searchProviders();
      setState(() {
        _allProviders = providersData.map((p) => ServiceProvider.fromJson(p)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load providers: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  List<ServiceProvider> get _filteredProviders {
    return _allProviders.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.serviceType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.location.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesType = _selectedType == 'All' || p.serviceType == _selectedType;
      final matchesLocation = _selectedLocation == 'All' || p.location == _selectedLocation;
      
      return matchesSearch && matchesType && matchesLocation;
    }).toList();
  }

  void _showProviderDetail(ServiceProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
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
                                      child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 36),
                                    ),
                                  )
                                : Container(
                                    width: 72,
                                    height: 72,
                                    color: AppTheme.primaryContainer,
                                    child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 36),
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
                                  provider.serviceType,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${provider.rating} (${provider.reviewCount} reviews)',
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
                      Row(
                        children: [
                          _detailChip(Icons.location_on_outlined, provider.location),
                          const SizedBox(width: 10),
                          _detailChip(Icons.attach_money_rounded, '${provider.pricePerHour.toInt()} DZD/hr'),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: provider.isAvailable ? AppTheme.success.withAlpha(25) : AppTheme.error.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              provider.isAvailable ? 'Available' : 'Busy',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: provider.isAvailable ? AppTheme.success : AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('About', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        provider.bio.isNotEmpty ? provider.bio : 'Professional healthcare provider dedicated to quality care.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      if (provider.specialties.isNotEmpty) ...[
                        Text('Specialties', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
                            child: Text(s, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                          )).toList(),
                        ),
                      ],
                      const SizedBox(height: 28),
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
                                      'serviceName': provider.serviceType,
                                    },
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Book Now', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
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
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
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
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search providers...',
                              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textMuted),
                              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 22),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 20),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.divider)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.divider)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Service Type', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _serviceTypes.map((t) {
                                final isSelected = _selectedType == t;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedType = t),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
                                    ),
                                    child: Text(
                                      t,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Location', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _locations.map((l) {
                                final isSelected = _selectedLocation == l;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedLocation = l),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primaryContainer.withAlpha(150) : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (l != 'All') ...[
                                          Icon(Icons.location_on_outlined, size: 12, color: isSelected ? AppTheme.primary : AppTheme.textMuted),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(l, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppTheme.primary : AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '${_filteredProviders.length} provider${_filteredProviders.length != 1 ? 's' : ''} found',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
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
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
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
                              child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 30),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: AppTheme.primaryContainer,
                            child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 30),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: provider.isAvailable ? AppTheme.success : AppTheme.textMuted,
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
                    Text(provider.name, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text(provider.serviceType, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 3),
                        Text('${provider.rating}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        const SizedBox(width: 4),
                        Text('(${provider.reviewCount})', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 2),
                        Text(provider.location, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${provider.pricePerHour.toInt()}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                  Text('DZD/hr', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
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
            decoration: BoxDecoration(color: AppTheme.primaryContainer.withAlpha(80), shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text('No Providers Found', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Try adjusting your search\nor filter criteria.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}