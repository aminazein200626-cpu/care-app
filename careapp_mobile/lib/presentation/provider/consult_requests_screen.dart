import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';

import 'request_details_screen.dart';
import 'provider_dashboard.dart';

class ConsultRequestsScreen extends StatefulWidget {
  const ConsultRequestsScreen({super.key});

  @override
  State<ConsultRequestsScreen> createState() => _ConsultRequestsScreenState();
}

class _ConsultRequestsScreenState extends State<ConsultRequestsScreen> {
  List<Map<String, dynamic>> _allRequests = [];
  bool _isLoading = true;

  String _searchQuery = "";
  String _statusFilter = "All";
  String _categoryFilter = "All";
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  List<String> _statusOptions = ["All", "Pending", "Accepted", "Completed", "Cancelled"];
  List<String> _categoryOptions = ["All", "Nursing Care", "Babysitting", "Elderly Care", "Medical Assistance"];

  final String baseUrl = 'http://10.0.2.2:5001';

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
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
        
        List<Map<String, dynamic>> requests = data.map((item) => {
          "id": item['id'],
          "client": item['client'] ?? 'Unknown',
          "clientImage": null,
          "clientPhone": item['clientPhone'] ?? '',
          "service": item['service'] ?? '',
          "category": _getCategoryFromService(item['service']),
          "date": item['date'] ?? '',
          "time": item['time'] ?? '',
          "duration": "2 hours",
          "location": item['location'] ?? '',
          "address": item['address'] ?? '',
          "distance": "2.5 km",
          "price": item['price'] ?? 0,
          "status": item['status'] ?? 'Pending',
          "notes": item['notes'] ?? '',
          "hasFiles": false,
          "dependent": item['dependent'] ?? null,
          "dependentNotes": null,
        }).toList();
        
        setState(() {
          _allRequests = requests;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
    }
  }

  String _getCategoryFromService(String service) {
    switch (service) {
      case 'Physical Therapy':
      case 'Nursing Care':
      case 'Night Shift Nurse':
        return 'Nursing Care';
      case 'Babysitting':
      case 'Super Nanny':
      case 'Emergency Babysitting':
        return 'Babysitting';
      case 'Elderly Care':
      case 'Elderly Companion':
        return 'Elderly Care';
      case 'General Consultation':
      case 'Medical Assistance':
        return 'Medical Assistance';
      default:
        return 'Other';
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/provider/bookings/${request['id']}/accept'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          request['status'] = 'Accepted';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request accepted successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      print('Error: $error');
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/provider/bookings/${request['id']}/reject'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          request['status'] = 'Cancelled';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request rejected"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      print('Error: $error');
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _allRequests.where((request) {
      bool matchesSearch = _searchQuery.isEmpty ||
          request['client'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          request['service'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (request['dependent'] != null && request['dependent'].toString().toLowerCase().contains(_searchQuery.toLowerCase()));
      
      bool matchesStatus = _statusFilter == "All" || request['status'] == _statusFilter;
      
      bool matchesCategory = _categoryFilter == "All" || request['category'] == _categoryFilter;
      
      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();
  }

  List<Map<String, dynamic>> get _paginatedRequests {
    int start = (_currentPage - 1) * _itemsPerPage;
    int end = start + _itemsPerPage;
    if (start >= _filteredRequests.length) {
      return _filteredRequests.take(_itemsPerPage).toList();
    }
    return _filteredRequests.sublist(start, end > _filteredRequests.length ? _filteredRequests.length : end);
  }

  int get _totalPages => (_filteredRequests.length / _itemsPerPage).ceil();

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Confirmed': return Colors.green;
      case 'Accepted': return Colors.green;
      case 'Completed': return Colors.blue;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange.withOpacity(0.1);
      case 'Confirmed': return Colors.green.withOpacity(0.1);
      case 'Accepted': return Colors.green.withOpacity(0.1);
      case 'Completed': return Colors.blue.withOpacity(0.1);
      case 'Cancelled': return Colors.red.withOpacity(0.1);
      default: return Colors.grey.withOpacity(0.1);
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
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const ProviderDashboard(providerName: "Amina")),
              (route) => false,
            );
          },
        ),
        title: Text(
          "Service Requests",
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
                _buildFiltersSection(isDark),
                _buildStatsSummary(isDark),
                Expanded(
                  child: _filteredRequests.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildRequestsList(isDark),
                ),
              ],
            ),
    );
  }

  Widget _buildFiltersSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _currentPage = 1;
              });
            },
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Search by client, service...",
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
              prefixIcon: Icon(Icons.search, color: AppTheme.primary, size: 20),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  isDark,
                  "Status",
                  _statusFilter,
                  _statusOptions,
                  (value) {
                    setState(() {
                      _statusFilter = value!;
                      _currentPage = 1;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  isDark,
                  "Category",
                  _categoryFilter,
                  _categoryOptions,
                  (value) {
                    setState(() {
                      _categoryFilter = value!;
                      _currentPage = 1;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(bool isDark, String label, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.primary),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatsSummary(bool isDark) {
    int pending = _allRequests.where((r) => r['status'] == 'Pending').length;
    int accepted = _allRequests.where((r) => r['status'] == 'Accepted' || r['status'] == 'Confirmed').length;
    int completed = _allRequests.where((r) => r['status'] == 'Completed').length;

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
          _statChip("Completed", completed, Colors.blue),
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

  Widget _buildRequestsList(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _paginatedRequests.length,
            itemBuilder: (context, index) {
              final request = _paginatedRequests[index];
              return _buildRequestCard(request, isDark);
            },
          ),
        ),
        if (_totalPages > 1) _buildPagination(isDark),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isDark) {
    Color statusColor = _getStatusColor(request['status']);
    Color statusBgColor = _getStatusBgColor(request['status']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                              request['client'],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (request['dependent'] != null)
                              Text(
                                "For: ${request['dependent']}",
                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        request['status'],
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        request['service'],
                        style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      request['category'],
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _infoChip(Icons.calendar_today_rounded, request['date'], Colors.grey),
                    const SizedBox(width: 12),
                    _infoChip(Icons.access_time_rounded, request['time'], Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      "${request['price']} DZD",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (request['status'] == 'Pending')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rejectRequest(request),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Decline", style: TextStyle(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptRequest(request),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Accept", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                if (request['status'] != 'Pending')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RequestDetailsScreen(requestData: request),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("View Details", style: TextStyle(color: AppTheme.primary)),
                    ),
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

  Widget _buildPagination(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: Icon(Icons.chevron_left, color: _currentPage > 1 ? AppTheme.primary : Colors.grey),
          ),
          Text(
            "$_currentPage / $_totalPages",
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          IconButton(
            onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
            icon: Icon(Icons.chevron_right, color: _currentPage < _totalPages ? AppTheme.primary : Colors.grey),
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
          Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No requests found",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Try changing your filters",
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }
}