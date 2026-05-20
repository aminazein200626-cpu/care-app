import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../../core/app_routes.dart';

class AdModel {
  final String id;
  final String providerId;
  final String providerName;
  final String providerAvatar;
  final String title;
  final String description;
  final String service;
  final double budget;
  final String? imageUrl;
  final String startDate;
  final String endDate;
  final int impressions;
  final int clicks;

  AdModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerAvatar,
    required this.title,
    required this.description,
    required this.service,
    required this.budget,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.impressions,
    required this.clicks,
  });

  factory AdModel.fromJson(Map<String, dynamic> json) {
    return AdModel(
      id: json['_id'] ?? json['id'] ?? '',
      providerId: json['providerId'] ?? '',
      providerName: json['providerName'] ?? json['name'] ?? '',
      providerAvatar: json['providerAvatar'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      service: json['service'] ?? '',
      budget: (json['budget'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'],
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      impressions: json['impressions'] ?? 0,
      clicks: json['clicks'] ?? 0,
    );
  }
}

class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  final ScrollController _scrollController = ScrollController();

  List<AdModel> _ads = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;

  final String baseUrl = 'http://10.0.2.2:5001';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    
    _loadAds();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreAds();
    }
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    _currentPage = 1;
    _hasMore = true;
    
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/client/ads?page=$_currentPage&limit=10'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _ads = data.map((a) => AdModel.fromJson(a)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ads: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreAds() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    _currentPage++;
    
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/client/ads?page=$_currentPage&limit=10'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isEmpty) {
          setState(() => _hasMore = false);
        } else {
          setState(() {
            _ads.addAll(data.map((a) => AdModel.fromJson(a)).toList());
          });
        }
      }
    } catch (e) {
      print('Error loading more ads: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ✅ دالة Book Now معدلة لتروح لشاشة Availability
  void _bookService(AdModel ad) {
  Navigator.pushNamed(
    context,
    '/client/select-dependant',  // ✅ يروح لشاشة اختيار الشخص
    arguments: {
      'providerId': ad.providerId,
      'providerName': ad.providerName,
      'serviceName': ad.service,
    },
  );
}

  void _viewProvider(AdModel ad) {
    Navigator.pushNamed(
      context,
      AppRoutes.searchScreen,
      arguments: {'providerId': ad.providerId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Special Offers"),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _ads.isEmpty
                ? _buildEmptyState(isDark)
                : RefreshIndicator(
                    onRefresh: _loadAds,
                    color: AppTheme.primary,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _ads.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _ads.length) {
                          return _buildLoadingMore();
                        }
                        return _buildAdCard(_ads[index], isDark);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildAdCard(AdModel ad, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ad Image or Placeholder
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: ad.imageUrl != null && ad.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: ad.imageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      height: 160,
                      color: AppTheme.primary.withOpacity(0.1),
                      child: Center(
                        child: Icon(
                          Icons.campaign_rounded,
                          size: 48,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  )
                : Container(
                    height: 160,
                    color: AppTheme.primary.withOpacity(0.1),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.campaign_rounded,
                            size: 48,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Special Offer",
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Provider Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      backgroundImage: ad.providerAvatar.isNotEmpty
                          ? CachedNetworkImageProvider(ad.providerAvatar)
                          : null,
                      child: ad.providerAvatar.isEmpty
                          ? const Icon(Icons.person, color: AppTheme.primary, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ad.providerName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            ad.service,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Sponsored",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Title
                Text(
                  ad.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Description
                Text(
                  ad.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Date Range
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      "${ad.startDate} - ${ad.endDate}",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _bookService(ad),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Book Now",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _viewProvider(ad),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "View Provider",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer.withAlpha(80),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'No Special Offers',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for exclusive deals\nfrom our providers.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMore() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}