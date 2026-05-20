import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import 'provider_dashboard.dart';
import 'tracking_screen.dart';

class ServiceHistoryPage extends StatefulWidget {
  const ServiceHistoryPage({super.key});

  @override
  State<ServiceHistoryPage> createState() => _ServiceHistoryPageState();
}

class _ServiceHistoryPageState extends State<ServiceHistoryPage> {
  int _selectedTab = 0;

  List<Map<String, dynamic>> _completedServices = [];
  List<Map<String, dynamic>> _pendingServices = [];
  List<Map<String, dynamic>> _canceledServices = [];
  bool _isLoading = true;

  final String baseUrl = 'http://10.0.2.2:5001';

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/bookings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        
        List<Map<String, dynamic>> completed = [];
        List<Map<String, dynamic>> pending = [];
        List<Map<String, dynamic>> canceled = [];

        for (var item in data) {
          final status = item['status']?.toLowerCase() ?? '';
          final service = {
            'id': item['id'],
            'client': item['client'] ?? '',
            'service': item['service'] ?? '',
            'date': item['date'] ?? '',
            'time': item['time'] ?? '',
            'duration': _getDuration(item['startTime'], item['endTime']),
            'location': item['location'] ?? '',
            'amount': item['price'] ?? 0,
            'status': status,
            'rating': item['rating'] ?? null,
            'feedback': item['feedback'] ?? null,
            'paymentStatus': item['paymentStatus'] ?? 'pending',
            'reason': item['reason'] ?? null,
          };

          if (status == 'completed') {
            completed.add(service);
          } else if (status == 'pending' || status == 'confirmed') {
            pending.add(service);
          } else if (status == 'cancelled' || status == 'canceled') {
            canceled.add(service);
          }
        }

        setState(() {
          _completedServices = completed;
          _pendingServices = pending;
          _canceledServices = canceled;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
    }
  }

  String _getDuration(String? start, String? end) {
    if (start == null || end == null) return 'N/A';
    return '${start} - ${end}';
  }

  List<Map<String, dynamic>> get _currentList {
    if (_selectedTab == 0) return _completedServices;
    if (_selectedTab == 1) return _pendingServices;
    return _canceledServices;
  }

  int get _totalEarnings {
    return _completedServices.fold(0, (sum, item) => sum + (item['amount'] as int));
  }

  void _startService(Map<String, dynamic> service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackingScreen(bookingId: service['id']),
      ),
    );
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ProviderDashboard(providerName: "Amina"),
              ),
            );
          },
        ),
        title: Text(
          "Service History",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _tabButton("Completed (${_completedServices.length})", 0, isDark),
                const SizedBox(width: 20),
                _tabButton("Pending (${_pendingServices.length})", 1, isDark),
                const SizedBox(width: 20),
                _tabButton("Canceled (${_canceledServices.length})", 2, isDark),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildStatsSummary(isDark),
          Expanded(
            child: _currentList.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _currentList.length,
                    itemBuilder: (context, index) {
                      final service = _currentList[index];
                      return _serviceCard(service, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String title, int index, bool isDark) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
            "Total Services",
            "${_completedServices.length + _pendingServices.length + _canceledServices.length}",
            Icons.work,
            Colors.blue,
            isDark,
          ),
          _statItem(
            "Completed",
            "${_completedServices.length}",
            Icons.check_circle,
            Colors.green,
            isDark,
          ),
          _statItem(
            "Earnings",
            "${_totalEarnings} DZD",
            Icons.monetization_on,
            AppTheme.primary,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ],
    );
  }

  Widget _serviceCard(Map<String, dynamic> service, bool isDark) {
    final isCompleted = service['status'] == 'completed';
    final isPending = service['status'] == 'pending' || service['status'] == 'confirmed';
    final isCanceled = service['status'] == 'cancelled' || service['status'] == 'canceled';

    Color statusColor;
    String statusText;
    if (isCompleted) {
      statusColor = Colors.green;
      statusText = 'COMPLETED';
    } else if (isPending) {
      statusColor = Colors.orange;
      statusText = 'PENDING';
    } else {
      statusColor = Colors.red;
      statusText = 'CANCELED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isCompleted ? Border.all(color: Colors.green.withOpacity(0.3)) : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Icon(Icons.person, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service['client'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              service['service'],
                              style: TextStyle(color: AppTheme.primary, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _infoChip(Icons.calendar_today, service['date'], Colors.grey),
                    const SizedBox(width: 12),
                    _infoChip(Icons.access_time, service['time'], Colors.grey),
                    const SizedBox(width: 12),
                    _infoChip(Icons.location_on, service['location'], Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${service['amount']} DZD",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    if (isCompleted && service['rating'] != null)
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < (service['rating'] as int) ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        )),
                      ),
                    if (isPending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          service['paymentStatus'] == 'pending' ? 'Awaiting Payment' : 'Paid',
                          style: TextStyle(color: Colors.orange, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                if (isCompleted && service['feedback'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Client Feedback:",
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service['feedback'],
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isCanceled && service['reason'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cancellation Reason:",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service['reason'],
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (isPending)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _startService(service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Start Service", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                if (isCompleted)
                  OutlinedButton(
                    onPressed: () => _showServiceDetails(service, isDark),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("View Details", style: TextStyle(color: AppTheme.primary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  void _showServiceDetails(Map<String, dynamic> service, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Service Details",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Divider(height: 24),
            _detailRow("Client", service['client'], isDark),
            _detailRow("Service", service['service'], isDark),
            _detailRow("Date", service['date'], isDark),
            _detailRow("Time", service['time'], isDark),
            _detailRow("Duration", service['duration'], isDark),
            _detailRow("Location", service['location'], isDark),
            _detailRow("Amount", "${service['amount']} DZD", isDark),
            if (service['rating'] != null) _detailRow("Rating", "${service['rating']} ★", isDark),
            if (service['feedback'] != null) _detailRow("Feedback", service['feedback'], isDark),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Close", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
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
          Icon(Icons.history, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No services found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedTab == 0 ? "You haven't completed any services yet" :
            _selectedTab == 1 ? "No pending services" : "No canceled services",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}