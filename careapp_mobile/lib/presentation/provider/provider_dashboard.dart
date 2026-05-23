import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import '../../services/theme_provider.dart';
import 'profile_page.dart';
import 'calendar_page.dart';
import 'communication_screen.dart';
import 'settings_page.dart';
import 'payment_page.dart';
import 'ads_management_page.dart';
import 'notifications_page.dart';
import 'feedback_rating_page.dart';
import 'booking_requests_screen.dart';
import 'active_bookings_screen.dart';

class ProviderDashboard extends StatefulWidget {
  final String providerName;
  const ProviderDashboard({super.key, required this.providerName});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  int _selectedIndex = 0;
  bool _isAvailable = true;
  bool _isLoading = true;

  Map<String, dynamic> _stats = {
    'pendingRequests': 0,
    'completedServices': 0,
    'monthlyEarnings': 0,
    'rating': 0,
  };

  List<FlSpot> _weeklyBookings = [
    const FlSpot(0, 0),
    const FlSpot(1, 0),
    const FlSpot(2, 0),
    const FlSpot(3, 0),
    const FlSpot(4, 0),
    const FlSpot(5, 0),
    const FlSpot(6, 0),
  ];

  List<Map<String, dynamic>> _recentNotifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchNotifications();
  }

  Future<void> _fetchDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/stats'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _stats = {
            'pendingRequests': data['pendingRequests'] ?? 0,
            'completedServices': data['completedServices'] ?? 0,
            'monthlyEarnings': data['monthlyEarnings'] ?? 0,
            'rating': data['rating'] ?? 0,
          };
          
          if (data['weeklyBookings'] != null && data['weeklyBookings'].length == 7) {
            _weeklyBookings = List.generate(7, (index) => FlSpot(
              index.toDouble(),
              (data['weeklyBookings'][index] as num).toDouble(),
            ));
          }
          
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _recentNotifications = data.map((n) => {
            'id': n['id'],
            'title': n['title'],
            'message': n['message'],
            'time': n['time'],
            'isRead': n['isRead'] ?? false,
          }).toList();
          _unreadCount = _recentNotifications.where((n) => !n['isRead']).length;
        });
      }
    } catch (error) {
      print('Error: $error');
    }
  }

  Future<void> _updateAvailability(bool isAvailable) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    try {
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/availability'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isAvailable': isAvailable}),
      );
    } catch (error) {
      print('Error: $error');
    }
  }

  void _toggleTheme() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      _buildHomeContent(isDark),
      const BookingRequestsScreen(),
      const CommunicationScreen(),
      const ProfilePage(),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildHomeContent(bool isDark) {
    return Column(
      children: [
        _buildModernHeader(isDark),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      _buildStatsRow(isDark),
                      const SizedBox(height: 24),
                      _buildChartSection(isDark),
                      const SizedBox(height: 24),
                      _buildQuickToolsGrid(isDark),
                      const SizedBox(height: 24),
                      _buildNotificationsPreview(isDark),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildModernHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0284C7), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome back,",
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
              ),
              Text(
                widget.providerName,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  setState(() {
                    _isAvailable = !_isAvailable;
                  });
                  await _updateAvailability(_isAvailable);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isAvailable ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isAvailable ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isAvailable ? "Available" : "Busy",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsPage()),
                      );
                    },
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: _toggleTheme,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = 3);
                },
                child: Container(
                  width: 55,
                  height: 55,
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
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        _statCard(isDark, "Pending", "${_stats['pendingRequests']}", Icons.pending_actions_rounded, Colors.orange, "+2 new"),
        const SizedBox(width: 12),
        _statCard(isDark, "Completed", "${_stats['completedServices']}", Icons.check_circle_rounded, Colors.green, "+8 this month"),
        const SizedBox(width: 12),
        _statCard(isDark, "Earnings", "${(_stats['monthlyEarnings'] / 1000).toStringAsFixed(0)}k", Icons.monetization_on_rounded, Colors.blue, "DZD"),
        const SizedBox(width: 12),
        _statCard(isDark, "Rating", "${_stats['rating']}", Icons.star_rounded, Colors.amber, "⭐ 4.8"),
      ],
    );
  }

  Widget _statCard(bool isDark, String label, String value, IconData icon, Color color, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Weekly Bookings",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text("This Week", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(days[value.toInt()], style: TextStyle(color: Colors.grey[500], fontSize: 10));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _weeklyBookings,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppTheme.primary.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ قائمة الأدوات بعد الإزالة والإعادة التنظيم
  Widget _buildQuickToolsGrid(bool isDark) {
    final tools = [
      {'title': 'Booking Requests', 'icon': Icons.pending_actions_rounded, 'color': Colors.deepOrange, 'route': () => const BookingRequestsScreen()},
      {'title': 'Messages', 'icon': Icons.chat_bubble_rounded, 'color': Colors.blue, 'route': 2},
      {'title': 'Profile', 'icon': Icons.person_rounded, 'color': Colors.indigo, 'route': 3},
      {'title': 'Calendar', 'icon': Icons.calendar_month_rounded, 'color': Colors.purple, 'route': () => const CalendarPage()},
      {'title': 'Tracking', 'icon': Icons.map_rounded, 'color': Colors.teal, 'route': () => const ActiveBookingsScreen()},
      {'title': 'Payment', 'icon': Icons.wallet_rounded, 'color': Colors.green, 'route': () => const PaymentPage()},
      {'title': 'My Ads', 'icon': Icons.campaign_rounded, 'color': Colors.pink, 'route': () => const AdsManagementPage()},
      {'title': 'Feedback', 'icon': Icons.rate_review_rounded, 'color': Colors.amber, 'route': () => const FeedbackRatingPage()},
      {'title': 'Settings', 'icon': Icons.settings_rounded, 'color': Colors.blueGrey, 'route': 4},
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: tools.map((tool) {
        final route = tool['route'];
        return GestureDetector(
          onTap: () {
            if (route is int) {
              setState(() => _selectedIndex = route);
            } else if (route is Widget Function()) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => route()));
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (tool['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(tool['icon'] as IconData, color: tool['color'] as Color, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  tool['title'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNotificationsPreview(bool isDark) {
    if (_recentNotifications.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Center(
          child: Text("No notifications yet"),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recent Notifications",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
                },
                child: const Text("View All", style: TextStyle(color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentNotifications.take(2).map((notification) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      notification['title'] == 'New Booking Request' ? Icons.assignment_rounded : Icons.payment_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['title'],
                          style: TextStyle(
                            fontWeight: notification['isRead'] ? FontWeight.normal : FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          notification['message'],
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    notification['time'],
                    style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.home_rounded, "Home", isDark),
          _navItem(1, Icons.assignment_rounded, "Requests", isDark),
          _navItem(2, Icons.chat_bubble_rounded, "Inbox", isDark),
          _navItem(3, Icons.person_rounded, "Me", isDark),
          _navItem(4, Icons.settings_rounded, "Set", isDark),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isDark) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : Colors.grey[400], size: 24),
            if (isSelected)
              Text(
                label,
                style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}