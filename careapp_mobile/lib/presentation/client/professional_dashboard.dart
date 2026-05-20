// lib/presentation/client/professional_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/client_api_service.dart';

class ProfessionalDashboard extends StatefulWidget {
  const ProfessionalDashboard({super.key});

  @override
  State<ProfessionalDashboard> createState() => _ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends State<ProfessionalDashboard> {
  final ClientApiService _api = ClientApiService();
  bool _isLoading = true;
  String _userName = '';
  String? _profileImage;
  String? _activeBookingId;
  
  // ✅ جميع الأزرار مقسمة حسب الفئة مع مسارات صحيحة
  final List<Map<String, dynamic>> _primaryActions = [
    {'label': 'Book Service', 'icon': Icons.add_circle_outline_rounded, 'color': const Color(0xFF0D6E6E), 'route': AppRoutes.clientBooking, 'description': 'Book a new service'},
    {'label': 'Search', 'icon': Icons.search_rounded, 'color': const Color(0xFF6366F1), 'route': AppRoutes.clientSearch, 'description': 'Find providers'},
    {'label': 'My Bookings', 'icon': Icons.calendar_month_rounded, 'color': const Color(0xFF3B82F6), 'route': AppRoutes.clientBooking, 'description': 'View all bookings'},
    {'label': 'Track Service', 'icon': Icons.location_on_rounded, 'color': const Color(0xFF10B981), 'route': AppRoutes.clientTracking, 'description': 'Track active service', 'needsBookingId': true},
  ];

  final List<Map<String, dynamic>> _communicationActions = [
    {'label': 'Chat', 'icon': Icons.chat_bubble_outline_rounded, 'color': const Color(0xFF8B5CF6), 'route': AppRoutes.clientChat, 'description': 'Message providers'},
    {'label': 'Call History', 'icon': Icons.call_outlined, 'color': const Color(0xFFF59E0B), 'route': '/call-history', 'description': 'View call logs'},
    {'label': 'Notifications', 'icon': Icons.notifications_outlined, 'color': const Color(0xFFEF4444), 'route': AppRoutes.clientNotifications, 'description': 'View alerts'},
  ];

  final List<Map<String, dynamic>> _managementActions = [
    {'label': 'Dependants', 'icon': Icons.family_restroom_rounded, 'color': const Color(0xFFF59E0B), 'route': AppRoutes.clientDependents, 'description': 'Manage family members'},
    {'label': 'Authorized Persons', 'icon': Icons.verified_user_rounded, 'color': const Color(0xFF059669), 'route': AppRoutes.clientAuthorized, 'description': 'Manage access'},
    {'label': 'Payment Methods', 'icon': Icons.credit_card_rounded, 'color': const Color(0xFF1E88E5), 'route': AppRoutes.paymentScreen, 'description': 'Manage payments'},
    {'label': 'Service History', 'icon': Icons.history_rounded, 'color': const Color(0xFF6B7280), 'route': AppRoutes.clientHistory, 'description': 'Past services'},
  ];

  final List<Map<String, dynamic>> _supportActions = [
    {'label': 'Feedback', 'icon': Icons.star_outline_rounded, 'color': const Color(0xFFF59E0B), 'route': AppRoutes.clientFeedback, 'description': 'Rate your experience'},
    {'label': 'Special Offers', 'icon': Icons.campaign_rounded, 'color': const Color(0xFFDC2626), 'route': AppRoutes.adsScreen, 'description': 'View deals'},
    {'label': 'Settings', 'icon': Icons.settings_rounded, 'color': const Color(0xFF4B5563), 'route': AppRoutes.settingsScreen, 'description': 'App settings'},
    {'label': 'Help Center', 'icon': Icons.help_outline_rounded, 'color': const Color(0xFF6366F1), 'route': '/help', 'description': 'FAQs & support'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchActiveBooking();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser != null) {
        _userName = authService.currentUser!.fullName.split(' ').first;
      }
      final profile = await _api.getProfile();
      setState(() {
        _profileImage = profile['profilePicture'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchActiveBooking() async {
    try {
      final bookings = await _api.getBookings();
      final activeBooking = bookings.firstWhere(
        (b) => b['status'] == 'In Progress' || b['status'] == 'Confirmed',
        orElse: () => null,
      );
      if (activeBooking != null) {
        setState(() {
          _activeBookingId = activeBooking['_id'] ?? activeBooking['id'];
        });
      }
    } catch (e) {
      print('Error fetching active booking: $e');
    }
  }

  void _navigateTo(String route, {Map<String, dynamic>? arguments}) {
    if (route == AppRoutes.clientTracking) {
      if (_activeBookingId != null) {
        Navigator.pushNamed(
          context, 
          route, 
          arguments: {'bookingId': _activeBookingId}
        );
      } else {
        _showSelectBookingDialog();
      }
      return;
    }
    
    if (route == AppRoutes.clientChat) {
      Navigator.pushNamed(context, route);
      return;
    }
    
    if (arguments != null) {
      Navigator.pushNamed(context, route, arguments: arguments);
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  void _showSelectBookingDialog() async {
    final bookings = await _api.getBookings();
    final activeBookings = bookings.where(
      (b) => b['status'] == 'In Progress' || b['status'] == 'Confirmed'
    ).toList();
    
    if (activeBookings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active bookings to track'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select a booking to track',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...activeBookings.map((booking) => ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(booking['service'] ?? 'Service'),
              subtitle: Text('${booking['date']} - ${booking['provider'] ?? 'Provider'}'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  AppRoutes.clientTracking,
                  arguments: {'bookingId': booking['_id'] ?? booking['id']},
                );
              },
            )),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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
      body: CustomScrollView(
        slivers: [
          _buildHeader(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Quick Actions', Icons.flash_on_rounded, isDark),
                  const SizedBox(height: 16),
                  _buildActionsGrid(_primaryActions, isDark),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('Communication', Icons.chat_bubble_outline_rounded, isDark),
                  const SizedBox(height: 16),
                  _buildActionsGrid(_communicationActions, isDark),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('Management', Icons.account_tree_rounded, isDark),
                  const SizedBox(height: 16),
                  _buildActionsGrid(_managementActions, isDark),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('Support', Icons.support_agent_rounded, isDark),
                  const SizedBox(height: 16),
                  _buildActionsGrid(_supportActions, isDark),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  // ==================== HEADER ====================
  
  Widget _buildHeader(bool isDark) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppTheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()},',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_userName 👋',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_user, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified Client',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.clientProfile),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _buildProfileImage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ دالة منفصلة لبناء صورة الملف الشخصي (بدون أخطاء)
  Widget _buildProfileImage() {
    if (_profileImage != null && _profileImage!.isNotEmpty) {
      return Image.network(
        _profileImage!,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 60,
          height: 60,
          color: Colors.white.withOpacity(0.2),
          child: const Icon(Icons.person, size: 30, color: Colors.white),
        ),
      );
    } else {
      return Container(
        width: 60,
        height: 60,
        color: Colors.white.withOpacity(0.2),
        child: const Icon(Icons.person, size: 30, color: Colors.white),
      );
    }
  }

  // ==================== SECTION TITLE ====================
  
  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  // ==================== ACTIONS GRID ====================
  
  Widget _buildActionsGrid(List<Map<String, dynamic>> actions, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _buildActionCard(action, isDark);
      },
    );
  }

  Widget _buildActionCard(Map<String, dynamic> action, bool isDark) {
    final Color color = action['color'] as Color;
    
    return GestureDetector(
      onTap: () => _navigateTo(action['route'] as String),
      child: Container(
        padding: const EdgeInsets.all(16),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(action['icon'] as IconData, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              action['label'] as String,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              action['description'] as String,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: isDark ? Colors.white70 : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BOTTOM NAVIGATION ====================
  
  Widget _buildBottomNav(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 65,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomNavItem(Icons.home_rounded, 'Home', true, () {}, isDark),
          _bottomNavItem(Icons.calendar_month_rounded, 'Bookings', false, () => Navigator.pushNamed(context, AppRoutes.clientBooking), isDark),
          _bottomNavItem(Icons.search_rounded, 'Search', false, () => Navigator.pushNamed(context, AppRoutes.clientSearch), isDark),
          _bottomNavItem(Icons.chat_bubble_outline_rounded, 'Chat', false, () => Navigator.pushNamed(context, AppRoutes.clientChat), isDark),
          _bottomNavItem(Icons.person_rounded, 'Profile', false, () => Navigator.pushNamed(context, AppRoutes.clientProfile), isDark),
        ],
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, bool isActive, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? AppTheme.primary : (isDark ? Colors.white70 : Colors.grey[500]), size: 22),
            if (isActive)
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}