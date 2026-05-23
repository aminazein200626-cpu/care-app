// lib/presentation/client/professional_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/client_api_service.dart';
import '../../services/theme_provider.dart';

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
  int _unreadNotificationsCount = 0;

  // ✅ Quick Actions: فقط 4 أيقونات (بدون Book)
  final List<Map<String, dynamic>> _primaryActions = [
    {'label': 'Search', 'icon': Icons.search_rounded, 'color': const Color(0xFF6366F1), 'route': AppRoutes.clientSearch, 'description': 'Find providers'},
    {'label': 'My Bookings', 'icon': Icons.calendar_month_rounded, 'color': const Color(0xFF3B82F6), 'route': AppRoutes.clientBooking, 'description': 'View all'},
    {'label': 'Track', 'icon': Icons.location_on_rounded, 'color': const Color(0xFF10B981), 'route': AppRoutes.clientTracking, 'description': 'Active service', 'needsBookingId': true},
    {'label': 'History', 'icon': Icons.history_rounded, 'color': const Color(0xFF6B7280), 'route': AppRoutes.clientHistory, 'description': 'Past services'},
  ];

  final List<Map<String, dynamic>> _communicationActions = [
    {'label': 'Chat', 'icon': Icons.chat_bubble_outline_rounded, 'color': const Color(0xFF8B5CF6), 'route': AppRoutes.clientChat, 'description': 'Messages'},
    {'label': 'Call Log', 'icon': Icons.call_rounded, 'color': const Color(0xFFF59E0B), 'route': '/call-history', 'description': 'Call history'},
    {'label': 'Alerts', 'icon': Icons.notifications_none_rounded, 'color': const Color(0xFFEF4444), 'route': AppRoutes.clientNotifications, 'description': 'Notifications'},
  ];

  final List<Map<String, dynamic>> _managementActions = [
    {'label': 'Family', 'icon': Icons.family_restroom_rounded, 'color': const Color(0xFFF59E0B), 'route': AppRoutes.clientDependents, 'description': 'Dependants'},
    {'label': 'Access', 'icon': Icons.verified_user_rounded, 'color': const Color(0xFF059669), 'route': AppRoutes.clientAuthorized, 'description': 'Authorized persons'},
    {'label': 'Payment', 'icon': Icons.credit_card_rounded, 'color': const Color(0xFF1E88E5), 'route': AppRoutes.paymentScreen, 'description': 'Methods'},
    {'label': 'Offers', 'icon': Icons.local_offer_rounded, 'color': const Color(0xFFDC2626), 'route': AppRoutes.adsScreen, 'description': 'Special deals'},
  ];

  final List<Map<String, dynamic>> _supportActions = [
    {'label': 'Feedback', 'icon': Icons.star_outline_rounded, 'color': const Color(0xFFF59E0B), 'route': AppRoutes.clientFeedback, 'description': 'Rate us'},
    {'label': 'Settings', 'icon': Icons.settings_rounded, 'color': const Color(0xFF4B5563), 'route': AppRoutes.settingsScreen, 'description': 'Preferences'},
    {'label': 'Help', 'icon': Icons.help_outline_rounded, 'color': const Color(0xFF6366F1), 'route': '/help', 'description': 'Support'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchActiveBooking();
    _fetchUnreadNotificationsCount();
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

  Future<void> _fetchUnreadNotificationsCount() async {
    try {
      final notifications = await _api.getNotifications();
      final unread = notifications.where((n) => n['isRead'] == false).length;
      setState(() {
        _unreadNotificationsCount = unread;
      });
    } catch (e) {
      print('Error fetching notifications count: $e');
    }
  }

  void _navigateTo(String route, {Map<String, dynamic>? arguments}) {
    if (route == AppRoutes.clientTracking) {
      if (_activeBookingId != null) {
        Navigator.pushNamed(context, route, arguments: {'bookingId': _activeBookingId});
      } else {
        _showSelectBookingDialog();
      }
      return;
    }
    if (route == AppRoutes.clientChat) {
      Navigator.pushNamed(context, route);
      return;
    }
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  void _showSelectBookingDialog() async {
    final bookings = await _api.getBookings();
    final activeBookings = bookings.where(
      (b) => b['status'] == 'In Progress' || b['status'] == 'Confirmed'
    ).toList();
    
    if (activeBookings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active bookings to track'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a booking to track', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...activeBookings.map((booking) => ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(booking['service'] ?? 'Service'),
              subtitle: Text('${booking['date']} - ${booking['provider'] ?? 'Provider'}'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AppRoutes.clientTracking, arguments: {'bookingId': booking['_id'] ?? booking['id']});
              },
            )),
          ],
        ),
      ),
    );
  }

  void _toggleTheme() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.toggleTheme();
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
      expandedHeight: 230,
      pinned: true,
      backgroundColor: AppTheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _toggleTheme,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.clientNotifications),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.notifications_none, color: Colors.white, size: 18),
                            ),
                          ),
                          if (_unreadNotificationsCount > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                                child: Text(
                                  '$_unreadNotificationsCount',
                                  style: const TextStyle(color: Colors.white, fontSize: 8),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_getGreeting()},',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_userName 💙',
                    style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('Verified Client', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.clientProfile),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                      ),
                      child: ClipOval(child: _buildProfileImage()),
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

  Widget _buildProfileImage() {
    if (_profileImage != null && _profileImage!.isNotEmpty) {
      return Image.network(
        _profileImage!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 40,
          height: 40,
          color: Colors.white.withOpacity(0.2),
          child: const Icon(Icons.person, size: 20, color: Colors.white),
        ),
      );
    } else {
      return Container(
        width: 40,
        height: 40,
        color: Colors.white.withOpacity(0.2),
        child: const Icon(Icons.person, size: 20, color: Colors.white),
      );
    }
  }

  // ==================== SECTION TITLE ====================
  
  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 14, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
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
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.1,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(action['icon'] as IconData, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              action['label'] as String,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              action['description'] as String,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: isDark ? Colors.white60 : Colors.grey[600]),
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
      height: 55,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? AppTheme.primary : (isDark ? Colors.white60 : Colors.grey[500]), size: 20),
            if (isActive)
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}