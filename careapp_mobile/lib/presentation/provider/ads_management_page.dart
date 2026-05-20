import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';

import 'provider_dashboard.dart';

class AdsManagementPage extends StatefulWidget {
  const AdsManagementPage({super.key});

  @override
  State<AdsManagementPage> createState() => _AdsManagementPageState();
}

class _AdsManagementPageState extends State<AdsManagementPage> {
  int _selectedTab = 0;
  List<Map<String, dynamic>> _myAds = [];
  bool _isLoading = true;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  String _selectedService = '';
  int _selectedDuration = 7;
  List<Map<String, dynamic>> _services = [];

  final String baseUrl = 'http://10.0.2.2:5001';

  @override
  void initState() {
    super.initState();
    _fetchAds();
    _fetchServices();
  }

  Future<void> _fetchAds() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/ads'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _myAds = data.map((ad) => ({
            'id': ad['id'],
            'title': ad['title'],
            'service': ad['service'],
            'description': ad['description'],
            'status': ad['status'],
            'impressions': ad['impressions'] ?? 0,
            'clicks': ad['clicks'] ?? 0,
            'bookings': ad['bookings'] ?? 0,
            'budget': ad['budget'],
            'spent': ad['spent'] ?? 0,
            'startDate': ad['startDate'] ?? 'Pending',
            'endDate': ad['endDate'] ?? 'Pending',
            'image': ad['image'],
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

  Future<void> _fetchServices() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/services'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _services = data.map((s) => ({
            'id': s['_id'],
            'name': s['name'],
          })).toList();
          if (_services.isNotEmpty) {
            _selectedService = _services[0]['id'];
          }
        });
      }
    } catch (error) {
      print('Error: $error');
    }
  }

  Future<void> _createAd() async {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _budgetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.red),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/provider/ads'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': _titleController.text,
          'serviceId': _selectedService,
          'description': _descriptionController.text,
          'budget': int.parse(_budgetController.text),
          'duration': _selectedDuration,
        }),
      );

      if (response.statusCode == 201) {
        await _fetchAds();
        _titleController.clear();
        _descriptionController.clear();
        _budgetController.clear();
        _selectedDuration = 7;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ad created successfully!"), backgroundColor: Colors.green),
        );
        setState(() => _selectedTab = 0);
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to create ad'), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection error"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pauseAd(int adId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/provider/ads/$adId/pause'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        await _fetchAds();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ad paused"), backgroundColor: Colors.orange),
        );
      }
    } catch (error) {
      print('Error: $error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPauseDialog(int adId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Pause Campaign"),
        content: const Text("Are you sure you want to pause this ad campaign?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pauseAd(adId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Pause"),
          ),
        ],
      ),
    );
  }

  String _getServiceName(String serviceId) {
    final service = _services.firstWhere(
      (s) => s['id'] == serviceId,
      orElse: () => {'name': serviceId},
    );
    return service['name'];
  }

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
          "My Ads",
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
                _tabButton("My Ads", 0, isDark),
                const SizedBox(width: 20),
                _tabButton("Create Ad", 1, isDark),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedTab == 0 ? _buildMyAdsTab(isDark) : _buildCreateAdTab(isDark),
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

  Widget _buildMyAdsTab(bool isDark) {
    if (_myAds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No ads yet",
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _selectedTab = 1),
              child: const Text("Create your first ad"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myAds.length,
      itemBuilder: (context, index) {
        final ad = _myAds[index];
        return _adCard(ad, isDark);
      },
    );
  }

  Widget _adCard(Map<String, dynamic> ad, bool isDark) {
    Color statusColor;
    String statusText;
    switch (ad['status']) {
      case 'Active':
        statusColor = Colors.green;
        statusText = 'ACTIVE';
        break;
      case 'Pending':
        statusColor = Colors.orange;
        statusText = 'PENDING';
        break;
      case 'Expired':
        statusColor = Colors.grey;
        statusText = 'EXPIRED';
        break;
      case 'Paused':
        statusColor = Colors.red;
        statusText = 'PAUSED';
        break;
      default:
        statusColor = Colors.grey;
        statusText = ad['status']?.toUpperCase() ?? 'UNKNOWN';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    ad['status'] == 'Active' ? Icons.campaign : Icons.pending,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        _getServiceName(ad['service']),
                        style: TextStyle(color: AppTheme.primary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          if (ad['status'] == 'Active')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem("Impressions", "${ad['impressions']}", Icons.visibility, isDark),
                  _statItem("Clicks", "${ad['clicks']}", Icons.touch_app, isDark),
                  _statItem("Bookings", "${ad['bookings']}", Icons.assignment, isDark),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Budget", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    Text("${ad['budget']} DZD", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Spent", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    Text("${ad['spent']} DZD", style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                if (ad['status'] == 'Active') ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (ad['spent'] / ad['budget']).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[300],
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${ad['startDate']} - ${ad['endDate']}",
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                    if (ad['status'] == 'Active')
                      TextButton(
                        onPressed: () {
                          _showPauseDialog(ad['id']);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          backgroundColor: Colors.red.withOpacity(0.1),
                        ),
                        child: const Text("Pause", style: TextStyle(color: Colors.red, fontSize: 12)),
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

  Widget _statItem(String label, String value, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ],
    );
  }

  Widget _buildCreateAdTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Create New Ad Campaign",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Ad Title",
                    hintText: "e.g., Special Babysitting Offer",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedService.isNotEmpty ? _selectedService : null,
                  hint: Text(_services.isEmpty ? "Loading services..." : "Select Service"),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Service",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                  ),
                  items: _services.map((s) {
                    return DropdownMenuItem<String>(
                      value: s['id'].toString(),
                      child: Text(s['name'].toString()),
                    );
                  }).toList(),
                  onChanged: _services.isEmpty ? null : (value) {
                    setState(() => _selectedService = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Description",
                    hintText: "Describe your special offer...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Daily Budget (DZD)",
                    hintText: "e.g., 500",
                    prefixText: "DZD ",
                    prefixStyle: TextStyle(color: AppTheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 16),
                Text("Campaign Duration", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _durationChip("3 days", 3, isDark),
                    const SizedBox(width: 12),
                    _durationChip("7 days", 7, isDark),
                    const SizedBox(width: 12),
                    _durationChip("14 days", 14, isDark),
                    const SizedBox(width: 12),
                    _durationChip("30 days", 30, isDark),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _createAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("Create Ad Campaign", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationChip(String label, int days, bool isDark) {
    final isSelected = _selectedDuration == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? const Color(0xFF0F172A) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey[400]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}