import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/client_api_service.dart';

class AvailabilityScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String serviceName;
  final String dependantId;
  final String dependantName;
  final double hourlyRate;

  const AvailabilityScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.serviceName,
    required this.dependantId,
    required this.dependantName,
    required this.hourlyRate,
  });

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  final ClientApiService _api = ClientApiService();
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _availability = {};
  String? _selectedDate;
  Map<String, dynamic>? _selectedSlot;
  double _totalPrice = 0.0;
  double _hours = 0.0;

  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);
    try {
      dynamic rawData = await _api.getProviderAvailability(widget.providerId);
      if (rawData is String) rawData = jsonDecode(rawData);
      Map<String, dynamic> availabilityMap = {};
      if (rawData is Map && rawData.containsKey('availability')) {
        availabilityMap = Map<String, dynamic>.from(rawData['availability']);
      } else if (rawData is Map<String, dynamic>) {
        availabilityMap = rawData;
      }
      Map<String, List<Map<String, dynamic>>> formattedSlots = {};
      availabilityMap.forEach((dateStr, slots) {
        if (slots is List) {
          List<Map<String, dynamic>> slotList = [];
          for (var slot in slots) {
            if (slot is Map && slot['isBooked'] != true) {
              slotList.add({
                'startTime': slot['startTime']?.toString() ?? '',
                'endTime': slot['endTime']?.toString() ?? '',
                'isBooked': false,
              });
            }
          }
          if (slotList.isNotEmpty) formattedSlots[dateStr] = slotList;
        }
      });
      setState(() {
        _availability = formattedSlots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading availability: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _updateTotalPrice(String startTime, String endTime) {
    try {
      final start = _parseTime(startTime);
      final end = _parseTime(endTime);
      _hours = (end - start).abs();
      _totalPrice = _hours * widget.hourlyRate;
      setState(() {});
    } catch (e) {
      _hours = 0;
      _totalPrice = 0;
    }
  }

  double _parseTime(String time12) {
    final parts = time12.split(' ');
    if (parts.length != 2) return 0;
    final time = parts[0];
    final period = parts[1].toUpperCase();
    final hourMin = time.split(':');
    int hour = int.parse(hourMin[0]);
    final minute = int.parse(hourMin[1]);
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return hour + minute / 60;
  }

  void _goToAddTasks() {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot'), backgroundColor: Colors.orange),
      );
      return;
    }

    final startDateTime = _combineDateAndTime(_selectedDate!, _selectedSlot!['startTime']);
    final endDateTime = _combineDateAndTime(_selectedDate!, _selectedSlot!['endTime']);
    final startTimestamp = startDateTime.millisecondsSinceEpoch;
    final endTimestamp = endDateTime.millisecondsSinceEpoch;

    Navigator.pushNamed(
      context,
      '/client/add-tasks-before-booking',
      arguments: {
        'providerId': widget.providerId,
        'providerName': widget.providerName,
        'serviceName': widget.serviceName,
        'dependantId': widget.dependantId,
        'dependantName': widget.dependantName,
        'selectedDate': _selectedDate,
        'selectedSlot': _selectedSlot,
        'startTimestamp': startTimestamp,
        'endTimestamp': endTimestamp,
        'location': _locationCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      },
    );
  }

  DateTime _combineDateAndTime(String dateStr, String time12) {
    final dateParts = dateStr.split('-');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);

    final timeParts = time12.split(' ');
    final time = timeParts[0];
    final period = timeParts[1].toUpperCase();
    final hourMin = time.split(':');
    int hour = int.parse(hourMin[0]);
    final minute = int.parse(hourMin[1]);

    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    return DateTime(year, month, day, hour, minute);
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, d MMMM yyyy', 'en_US').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Book ${widget.serviceName}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availability.isEmpty
              ? _buildEmptyState(isDark)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 24, backgroundColor: AppTheme.primary.withOpacity(0.1), child: Icon(Icons.person, color: AppTheme.primary, size: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.providerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(widget.serviceName, style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                                  Text('${widget.hourlyRate.toInt()} DZD / hour', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Select Date & Time', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._availability.entries.map((entry) {
                        final date = entry.key;
                        final slots = entry.value;
                        final isSelected = _selectedDate == date;
                        return Column(
                          children: [
                            Card(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ExpansionTile(
                                title: Text(_formatDate(date), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                leading: Icon(Icons.calendar_today, color: AppTheme.primary),
                                initiallyExpanded: isSelected,
                                onExpansionChanged: (expanded) {
                                  if (expanded) setState(() => _selectedDate = date);
                                },
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: slots.map((slot) {
                                        final isSlotSelected = _selectedSlot == slot;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedSlot = slot;
                                              _updateTotalPrice(slot['startTime'], slot['endTime']);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isSlotSelected ? AppTheme.primary : (isDark ? const Color(0xFF0F172A) : Colors.grey[100]),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: isSlotSelected ? AppTheme.primary : Colors.grey[400]!),
                                            ),
                                            child: Text('${slot['startTime']} - ${slot['endTime']}'),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }).toList(),
                      if (_selectedSlot != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Duration', style: TextStyle(color: Colors.grey[500], fontSize: 12)), Text('${_hours.toStringAsFixed(1)} hours', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Total Price', style: TextStyle(color: Colors.grey[500], fontSize: 12)), Text('${_totalPrice.toInt()} DZD', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary))]),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text('Location Details', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(controller: _locationCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(hintText: 'Your address', prefixIcon: Icon(Icons.location_on, color: AppTheme.primary), filled: true, fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                      const SizedBox(height: 16),
                      TextField(controller: _notesCtrl, maxLines: 3, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(hintText: 'Additional notes (optional)', prefixIcon: Icon(Icons.note, color: AppTheme.primary), filled: true, fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                      const SizedBox(height: 30),
                      SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _goToAddTasks, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text('Continue to Tasks', style: TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No available slots', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text('This provider has no available time slots at the moment.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}