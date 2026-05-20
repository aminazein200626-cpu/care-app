import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import 'provider_dashboard.dart';
import 'payment_page.dart'; // ✅ للانتقال إلى صفحة الدفع

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int _selectedFilter = 0;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _notifications = data.map((n) => ({
            'id': n['id'],
            'title': n['title'],
            'message': n['message'],
            'time': n['time'],
            'isRead': n['isRead'] ?? false,
            'type': n['type'] ?? 'system',
            'bookingId': n['bookingId'], // ✅ قد يكون موجوداً من الباك إند
          })).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/notifications/$id/read'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }
      });
    } catch (error) {
      print('Error: $error');
    }
  }

  Future<void> _markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      for (var n in _notifications.where((n) => !n['isRead'])) {
        await http.put(
          Uri.parse('${ApiConfig.baseUrl}/api/provider/notifications/${n['id']}/read'),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
      
      setState(() {
        for (var n in _notifications) {
          n['isRead'] = true;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All notifications marked as read"), backgroundColor: Colors.green),
      );
    } catch (error) {
      print('Error: $error');
    }
  }

  Future<void> _deleteNotification(int id) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Notification"),
        content: const Text("Are you sure you want to delete this notification?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('token');
              if (token == null) return;

              try {
                await http.delete(
                  Uri.parse('${ApiConfig.baseUrl}/api/provider/notifications/$id'),
                  headers: {'Authorization': 'Bearer $token'},
                );
                
                setState(() {
                  _notifications.removeWhere((n) => n['id'] == id);
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Notification deleted"), backgroundColor: Colors.red),
                );
              } catch (error) {
                print('Error: $error');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAll() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear All"),
        content: const Text("Are you sure you want to delete all notifications?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('token');
              if (token == null) return;

              try {
                for (var n in _notifications) {
                  await http.delete(
                    Uri.parse('${ApiConfig.baseUrl}/api/provider/notifications/${n['id']}'),
                    headers: {'Authorization': 'Bearer $token'},
                  );
                }
                
                setState(() {
                  _notifications.clear();
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All notifications cleared"), backgroundColor: Colors.red),
                );
              } catch (error) {
                print('Error: $error');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }

  // ✅ دالة للانتقال إلى الصفحة المناسبة بناءً على نوع الإشعار
  void _navigateToRelatedPage(Map<String, dynamic> notification) async {
    // تحديد ما إذا كان الإشعار للدفع (نصف المبلغ)
    if (notification['type'] == 'payment' && notification['title'] == 'Half Payment Received') {
      // محاولة جلب bookingId من الإشعار (إن وُجد)
      String? bookingId = notification['bookingId']?.toString();
      if (bookingId != null && bookingId.isNotEmpty) {
        // انتقل إلى PaymentPage (أو يمكن فتح صفحة تفاصيل الحجز)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentPage(), // يمكن تمرير bookingId إذا أردت
          ),
        );
      } else {
        // إذا لم يكن هناك bookingId، فقط نعرض رسالة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Open Payment Page to see half payments details")),
        );
      }
    }
    // يمكن إضافة أنواع أخرى من الإشعارات (مثل booking, service, etc.)
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 0) return _notifications;
    if (_selectedFilter == 1) return _notifications.where((n) => !n['isRead']).toList();
    return _notifications.where((n) => n['isRead']).toList();
  }

  int get _unreadCount => _notifications.where((n) => !n['isRead']).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          "Notifications",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'mark_all') _markAllAsRead();
                if (value == 'clear_all') _clearAll();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'mark_all', child: Text("Mark all as read")),
                const PopupMenuItem(value: 'clear_all', child: Text("Clear all")),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      _filterChip("All", 0, _notifications.length, isDark),
                      const SizedBox(width: 12),
                      _filterChip("Unread", 1, _unreadCount, isDark),
                      const SizedBox(width: 12),
                      _filterChip("Read", 2, _notifications.length - _unreadCount, isDark),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredNotifications.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredNotifications.length,
                          itemBuilder: (context, index) {
                            final notification = _filteredNotifications[index];
                            return GestureDetector(
                              onTap: () {
                                // ✅ أولاً نحدد الإشعار كمقروء
                                if (!notification['isRead']) {
                                  _markAsRead(notification['id']);
                                }
                                // ✅ ثم ننتقل إلى الصفحة المناسبة
                                _navigateToRelatedPage(notification);
                              },
                              child: _notificationTile(notification, isDark),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String label, int filter, int count, bool isDark) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey[400]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notificationTile(Map<String, dynamic> notification, bool isDark) {
    IconData icon;
    Color color;
    switch (notification['type']) {
      case 'booking':
        icon = Icons.assignment;
        color = Colors.blue;
        break;
      case 'payment':
        icon = Icons.currency_franc; // ✅ أيقونة مناسبة للدفع
        color = Colors.pink;         // ✅ لون وردي لتمييز إشعارات الدفع
        break;
      case 'ad':
        icon = Icons.campaign;
        color = Colors.purple;
        break;
      case 'service':
        icon = Icons.check_circle;
        color = Colors.teal;
        break;
      case 'message':
        icon = Icons.chat;
        color = Colors.orange;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: !notification['isRead']
            ? Border.all(color: AppTheme.primary, width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notification['title'],
                        style: TextStyle(
                          fontWeight: notification['isRead'] ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      notification['time'],
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification['message'],
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[400], size: 18),
            onPressed: () => _deleteNotification(notification['id']),
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
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No notifications",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You're all caught up!",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}