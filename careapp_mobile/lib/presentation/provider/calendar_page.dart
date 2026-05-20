import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import '../../core/app_routes.dart';
import 'provider_dashboard.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Map<String, dynamic>>> _availability = {};
  bool _isLoading = true;
  String? _error;
  String _selectedStartTime = '09:00 AM';
  String _selectedEndTime = '12:00 PM';
  final List<String> _timeSlots = [
    '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
    '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM',
    '06:00 PM', '07:00 PM', '08:00 PM'
  ];

  @override
  void initState() {
    super.initState();
    _checkTokenAndLoad();
  }

  Future<void> _checkTokenAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('🔑 Token: $token');
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Please login first';
        _isLoading = false;
      });
      return;
    }
    await _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Not authenticated. Please login.';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/provider/availability');
      print('🌐 Calling: $url');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final Map<String, List<Map<String, dynamic>>> newSlots = {};
        data.forEach((dateStr, slots) {
          newSlots[dateStr] = List<Map<String, dynamic>>.from(slots);
        });
        if (!mounted) return;
        setState(() {
          _availability = newSlots;
          _error = null;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          _error = 'Session expired. Please login again.';
          _isLoading = false;
        });
      } else {
        String errorMsg = 'Failed to load data';
        try {
          final data = jsonDecode(response.body);
          errorMsg = data['message'] ?? errorMsg;
        } catch(e) {}
        if (!mounted) return;
        setState(() {
          _error = errorMsg;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Exception: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addSlot() async {
    if (_selectedDay == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first'), backgroundColor: Colors.orange),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/provider/availability');
      print('🌐 POST to: $url');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'date': DateFormat('yyyy-MM-dd').format(_selectedDay!),
          'startTime': _selectedStartTime,
          'endTime': _selectedEndTime,
        }),
      );
      
      final responseBody = await response.body;
      print('📡 POST response status: ${response.statusCode}');
      print('📡 POST response body: $responseBody');
      
      if (response.statusCode == 201) {
        await _loadAvailability();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time slot added successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        String errorMsg = 'Failed to add slot';
        try {
          final data = jsonDecode(responseBody);
          errorMsg = data['message'] ?? errorMsg;
        } catch(e) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ POST error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Available Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedStartTime,
              items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) {
                if (mounted) setState(() => _selectedStartTime = v!);
              },
              decoration: const InputDecoration(labelText: 'Start Time'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedEndTime,
              items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) {
                if (mounted) setState(() => _selectedEndTime = v!);
              },
              decoration: const InputDecoration(labelText: 'End Time'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addSlot();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _goToLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProviderDashboard(providerName: 'Provider')),
          ),
        ),
        title: Text('Availability Calendar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: _showAddDialog),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _error!.contains('login') ? _goToLogin : _loadAvailability,
                        child: Text(_error!.contains('login') ? 'Go to Login' : 'Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    TableCalendar(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(const Duration(days: 90)),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                      },
                      onFormatChanged: (format) => setState(() => _calendarFormat = format),
                      eventLoader: (day) {
                        final dateStr = DateFormat('yyyy-MM-dd').format(day);
                        return _availability.containsKey(dateStr) ? ['available'] : [];
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), shape: BoxShape.circle),
                        selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                        markerDecoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                        ),
                        child: _selectedDay == null
                            ? const Center(child: Text('Select a day from calendar'))
                            : _buildSlotsForDay(_selectedDay!),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _selectedDay != null && _error == null
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSlotsForDay(DateTime day) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final slots = _availability[dateStr] ?? [];
    if (slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text('No slots for $dateStr', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Slot'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: slots.length,
      itemBuilder: (ctx, idx) {
        final slot = slots[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.access_time, color: AppTheme.primary),
            title: Text('${slot['startTime']} - ${slot['endTime']}'),
            trailing: slot['isBooked'] == true
                ? const Chip(label: Text('Booked'), backgroundColor: Colors.orange)
                : const Chip(label: Text('Available'), backgroundColor: Colors.green),
          ),
        );
      },
    );
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}