import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import 'provider_dashboard.dart';
import 'request_details_screen.dart';
import '../client/profile_screen.dart';

class BookingRequestsScreen extends StatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _statusFilter = "All";
  bool _isRating = false;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/booking-requests'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          final normalized = data.map((item) {
            if (item['status'] != null && item['status'] is String) {
              item['status'] = item['status'].toString().toLowerCase();
            }
            return item;
          }).toList();
          setState(() {
            _requests = List<Map<String, dynamic>>.from(normalized);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _reportClient(String clientId, String clientName, String clientEmail) {
    if (clientEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client email not available'), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          targetUserId: clientId,
          targetName: clientName,
          targetEmail: clientEmail,
          targetRole: 'Client',
        ),
      ),
    );
  }

  void _showRateClientDialog(String bookingId, String clientName) {
    if (bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot rate: no booking ID'), backgroundColor: Colors.red),
      );
      return;
    }

    int rating = 0;
    String comment = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Rate Client: $clientName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How was your experience with this client?"),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                  onPressed: () => setDialogState(() => rating = i + 1),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Leave a comment...",
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => comment = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Skip"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (rating == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a rating'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _submitClientRating(bookingId, rating, comment);
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitClientRating(String bookingId, int rating, String comment) async {
    setState(() => _isRating = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() => _isRating = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/bookings/$bookingId/rate-client'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'rating': rating,
          'comment': comment,
        }),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Client rated successfully"), backgroundColor: Colors.green),
        );
        await _fetchRequests();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${error['message']}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isRating = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _requests.where((request) {
      final clientName = request['clientName'] as String? ?? '';
      final serviceName = request['serviceName'] as String? ?? '';
      final matchesSearch = _searchQuery.isEmpty ||
          clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          serviceName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == "All" || request['status'] == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProviderDashboard(providerName: "Provider")),
            );
          },
        ),
        title: Text(
          "Booking Requests",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(isDark),
                _buildStatsSummary(isDark),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchRequests,
                    color: AppTheme.primary,
                    child: _filteredRequests.isEmpty
                        ? _buildEmptyState(isDark)
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredRequests.length,
                            itemBuilder: (context, index) {
                              final request = _filteredRequests[index];
                              return _buildRequestCard(request, isDark);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Search by client or service...",
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
              prefixIcon: Icon(Icons.search, color: AppTheme.primary, size: 20),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text("Status:", style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              _statusChip("All", _statusFilter == "All", isDark),
              const SizedBox(width: 8),
              _statusChip("pending", _statusFilter == "pending", isDark),
              const SizedBox(width: 8),
              _statusChip("accepted", _statusFilter == "accepted", isDark),
              const SizedBox(width: 8),
              _statusChip("rejected", _statusFilter == "rejected", isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool isSelected, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : (isDark ? const Color(0xFF0F172A) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary(bool isDark) {
    int pending = _requests.where((r) => r['status'] == 'pending').length;
    int accepted = _requests.where((r) => r['status'] == 'accepted').length;
    int rejected = _requests.where((r) => r['status'] == 'rejected').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip("Pending", pending, Colors.orange),
          _statChip("Accepted", accepted, Colors.green),
          _statChip("Rejected", rejected, Colors.red),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: $count",
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isDark) {
    final statusColor = _getStatusColor(request['status'] ?? 'pending');
    final dependent = request['dependent'];
    final clientId = request['clientId']?.toString() ?? '';
    final clientName = request['clientName'] ?? 'Unknown';
    final clientEmail = request['clientEmail']?.toString() ?? '';
    final bookingId = request['bookingId']?.toString() ?? '';
    final bool canRate = request['status'] == 'accepted' && bookingId.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['serviceName'] ?? 'Care Service',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        "Client: $clientName",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    (request['status'] ?? 'pending').toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip(Icons.calendar_today, request['date'] ?? 'N/A', Colors.grey),
                const SizedBox(width: 12),
                _infoChip(Icons.access_time, '${request['startTime'] ?? ''} - ${request['endTime'] ?? ''}', Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            _infoChip(Icons.location_on, request['location'] ?? 'Not specified', Colors.grey),
            if ((request['notes'] ?? '').isNotEmpty)
              _infoChip(Icons.note, request['notes']!, Colors.grey),
            if ((request['tasks'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              const Text("Tasks:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (request['tasks'] as List).map((task) => Chip(
                  label: Text(task['taskName'] ?? 'Task', style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                )).toList(),
              ),
            ],
            if (dependent != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("👤 Dependant", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("${dependent['name'] ?? 'N/A'} (${dependent['relationship'] ?? 'N/A'})",
                        style: const TextStyle(fontSize: 12)),
                    if (dependent['age'] != null)
                      Text("Age: ${dependent['age']}",
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    if ((dependent['healthNotes'] ?? '').isNotEmpty)
                      Text(dependent['healthNotes'],
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestDetailsScreen(requestData: request),
                        ),
                      );
                      _fetchRequests(); // إعادة تحميل بعد العودة من التفاصيل
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("View Details", style: TextStyle(color: AppTheme.primary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reportClient(clientId, clientName, clientEmail),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Report Client'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            if (canRate)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isRating ? null : () => _showRateClientDialog(bookingId, clientName),
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: Text(_isRating ? 'Submitting...' : 'Rate Client'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Colors.amber),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("No booking requests", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            "When clients request your services, they will appear here.",
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }
}