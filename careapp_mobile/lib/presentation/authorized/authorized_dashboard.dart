import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/authorized_api_service.dart';
import 'authorized_profile_screen.dart';
import 'authorized_notifications_screen.dart';
import 'authorized_tracking_screen.dart';

class AuthorizedDashboard extends StatefulWidget {
  const AuthorizedDashboard({super.key});

  @override
  State<AuthorizedDashboard> createState() => _AuthorizedDashboardState();
}

class _AuthorizedDashboardState extends State<AuthorizedDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  final AuthorizedApiService _api = AuthorizedApiService();
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  String _userName = '';
  String _greeting = '';
  IconData _greetingIcon = Icons.wb_sunny;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();

    _setGreeting();
    _loadData();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
      _greetingIcon = Icons.wb_sunny;
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
      _greetingIcon = Icons.wb_twilight;
    } else {
      _greeting = 'Good Evening';
      _greetingIcon = Icons.nightlight_round;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser != null) {
        final fullName = authService.currentUser!.fullName;
        _userName = fullName.split(' ').first;
      }

      final services = await _api.getAuthorizedServices();
      if (!mounted) return;
      setState(() {
        _services = services.map((s) => {
          'id': s['id'],
          'service': s['service'] ?? 'Service',
          'provider': s['provider'] ?? 'Provider',
          'providerId': s['providerId'],
          'providerAvatar': s['providerAvatar'],
          'clientName': s['clientName'] ?? 'Client',
          'date': s['date'],
          'time': s['time'],
          'status': s['status'] ?? 'Pending',
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  int get _activeServicesCount => _services.where((s) => s['status'] == 'In Progress' || s['status'] == 'Confirmed').length;
  int get _completedServicesCount => _services.where((s) => s['status'] == 'Completed').length;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'In Progress': return const Color(0xFF3B82F6);
      case 'Confirmed': return const Color(0xFF10B981);
      case 'Pending': return const Color(0xFFF59E0B);
      case 'Completed': return const Color(0xFF6366F1);
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'In Progress': return 'In Progress';
      case 'Confirmed': return 'Confirmed';
      case 'Pending': return 'Pending';
      case 'Completed': return 'Completed';
      default: return status;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Date TBD';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 380;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: _isLoading
              ? _buildLoadingState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primary,
                  child: CustomScrollView(
                    slivers: [
                      _buildHeader(isDark, isSmall),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(isSmall ? 12 : 20),
                          child: Column(
                            children: [
                              _buildStatsRow(isDark, isSmall),
                              const SizedBox(height: 20),
                              _buildQuickActions(isDark, isSmall),
                              const SizedBox(height: 24),
                              _buildSectionHeader('My Services', _services.length, isDark),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      _services.isEmpty
                          ? SliverFillRemaining(child: _buildEmptyState(isDark))
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => Padding(
                                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 20, vertical: 6),
                                  child: _buildServiceCard(_services[index], isDark, isSmall),
                                ),
                                childCount: _services.length,
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(height: 16),
        Text(
          'Loading your dashboard...',
          style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white70 : Colors.grey[600]),
        ),
      ],
    ),
  );

  Widget _buildHeader(bool isDark, bool isSmall) {
    return SliverAppBar(
      expandedHeight: isSmall ? 240 : 280,
      pinned: true,
      backgroundColor: AppTheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D6E6E), Color(0xFF1A9090), Color(0xFF0D6E6E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(isSmall ? 16 : 24, 40, isSmall ? 16 : 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthorizedProfileScreen())),
                        child: CircleAvatar(
                          radius: isSmall ? 22 : 28,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: const Icon(Icons.person, color: Colors.white, size: 28),
                        ),
                      ),
                      Row(
                        children: [
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthorizedNotificationsScreen())),
                              ),
                              if (_unreadCount > 0)
                                Positioned(
                                  right: 5,
                                  top: 5,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                    child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center),
                                  ),
                                ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthorizedProfileScreen())),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white),
                            onPressed: () async {
                              final authService = Provider.of<AuthService>(context, listen: false);
                              await authService.logout();
                              if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(_greetingIcon, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Text('$_greeting,', style: GoogleFonts.plusJakartaSans(fontSize: isSmall ? 14 : 16, color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('$_userName 👋', style: GoogleFonts.plusJakartaSans(fontSize: isSmall ? 26 : 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text('Welcome to your authorized dashboard', style: GoogleFonts.plusJakartaSans(fontSize: isSmall ? 12 : 14, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, bool isSmall) {
    final stats = [
      {'icon': Icons.play_circle_outline, 'label': 'Active', 'value': '$_activeServicesCount', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.check_circle_outline, 'label': 'Completed', 'value': '$_completedServicesCount', 'color': const Color(0xFF10B981)},
      {'icon': Icons.people_outline, 'label': 'Providers', 'value': '${_services.map((s) => s['providerId']).toSet().length}', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.access_time, 'label': 'Total', 'value': '${_services.length}', 'color': const Color(0xFF6366F1)},
    ];
    return Row(
      children: stats.map((stat) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: isSmall ? 6 : 12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: (stat['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(stat['icon'] as IconData, color: stat['color'] as Color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(stat['value'] as String, style: GoogleFonts.plusJakartaSans(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              Text(stat['label'] as String, style: GoogleFonts.plusJakartaSans(fontSize: isSmall ? 9 : 10, color: Colors.grey[500])),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildQuickActions(bool isDark, bool isSmall) {
    final actions = [
      {'icon': Icons.refresh, 'label': 'Refresh', 'color': AppTheme.primary, 'onTap': _loadData},
      {'icon': Icons.support_agent, 'label': 'Support', 'color': const Color(0xFF8B5CF6), 'onTap': () {}},
      {'icon': Icons.info_outline, 'label': 'Help', 'color': const Color(0xFF10B981), 'onTap': () {}},
    ];
    return Row(
      children: actions.map((action) => Expanded(
        child: GestureDetector(
          onTap: action['onTap'] as VoidCallback?,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: isSmall ? 2 : 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                Icon(action['icon'] as IconData, color: action['color'] as Color, size: isSmall ? 20 : 24),
                const SizedBox(height: 4),
                Text(action['label'] as String, style: GoogleFonts.plusJakartaSans(fontSize: isSmall ? 10 : 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.grey[600])),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildSectionHeader(String title, int count, bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ),
          ],
        ),
        if (count > 2) TextButton(onPressed: () {}, child: Text('See All', style: TextStyle(color: AppTheme.primary, fontSize: 12))),
      ],
    ),
  );

  Widget _buildServiceCard(Map<String, dynamic> service, bool isDark, bool isSmall) {
    final statusColor = _getStatusColor(service['status']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AuthorizedTrackingScreen(serviceId: service['id']),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(isSmall ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [statusColor, statusColor.withOpacity(0.6)])),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        backgroundImage: service['providerAvatar'] != null ? CachedNetworkImageProvider(service['providerAvatar']) : null,
                        child: service['providerAvatar'] == null
                            ? Text(service['provider'][0].toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(service['service'], style: GoogleFonts.plusJakartaSans(fontSize: isSmall ? 14 : 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(child: Text(service['provider'], style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(_getStatusText(service['status']), style: GoogleFonts.plusJakartaSans(fontSize: isSmall ? 9 : 10, fontWeight: FontWeight.w600, color: statusColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.family_restroom, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text('For: ${service['clientName']}', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(_formatDate(service['date']), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[500])),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(service['time'] ?? 'TBD', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AuthorizedTrackingScreen(serviceId: service['id']),
                        ),
                      );
                    },
                    icon: Icon(Icons.location_on, size: isSmall ? 16 : 18),
                    label: Text(isSmall ? 'Track' : 'Track Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
                      textStyle: GoogleFonts.plusJakartaSans(fontSize: isSmall ? 12 : 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 100, height: 100, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.visibility_off_rounded, size: 50, color: AppTheme.primary)),
          const SizedBox(height: 24),
          Text('No Services to Track', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Text('You haven\'t been authorized to track\nany services yet.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[600], height: 1.5)),
          const SizedBox(height: 30),
          ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          ),
        ],
      ),
    ),
  );
}