import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../services/client_api_service.dart';

class AddTasksBeforeBookingScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String serviceName;
  final String selectedDate;
  final String dependantId;
  final String dependantName;
  final Map<String, dynamic> selectedSlot;
  final String location;
  final String notes;
  final int startTimestamp;   // ✅ جديد - required
  final int endTimestamp;     // ✅ جديد - required

  const AddTasksBeforeBookingScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.serviceName,
    required this.selectedDate,
    required this.selectedSlot,
    required this.location,
    required this.notes,
    required this.dependantId,
    required this.dependantName,
    required this.startTimestamp,
    required this.endTimestamp,
  });

  @override
  State<AddTasksBeforeBookingScreen> createState() => _AddTasksBeforeBookingScreenState();
}

class _AddTasksBeforeBookingScreenState extends State<AddTasksBeforeBookingScreen> {
  final List<TextEditingController> _taskControllers = [TextEditingController()];
  final ClientApiService _api = ClientApiService();
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedFiles = [];
  bool _isLoading = false;

  void _addTaskField() {
    setState(() {
      _taskControllers.add(TextEditingController());
    });
  }

  void _removeTaskField(int index) {
    setState(() {
      _taskControllers[index].dispose();
      _taskControllers.removeAt(index);
    });
  }

  Future<void> _pickFiles() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _selectedFiles = pickedFiles.map((f) => File(f.path)).toList();
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  // For display only (converts 12-hour to 24-hour for summary)
  String _convertTo24HourForDisplay(String time12) {
    final parts = time12.split(' ');
    if (parts.length != 2) return time12;
    final time = parts[0];
    final period = parts[1].toUpperCase();
    final hourMin = time.split(':');
    int hour = int.parse(hourMin[0]);
    final minute = int.parse(hourMin[1]);
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submitBookingRequest() async {
    final List<Map<String, String>> tasksList = _taskControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => {'taskName': c.text.trim()})
        .toList();

    if (widget.serviceName.trim().isEmpty) {
      _showError('Service name is missing. Please go back and select a service.');
      return;
    }

    if (widget.selectedSlot['startTime'] == null || widget.selectedSlot['endTime'] == null) {
      _showError('Time slot is missing. Please go back and select a time.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use the timestamps passed from AvailabilityScreen directly
      final startTimestamp = widget.startTimestamp;
      final endTimestamp = widget.endTimestamp;

      // For display only (backward compatibility)
      final startTime24 = _convertTo24HourForDisplay(widget.selectedSlot['startTime']);
      final endTime24 = _convertTo24HourForDisplay(widget.selectedSlot['endTime']);

      final String tasksJson = jsonEncode(tasksList);

      final Map<String, String> fields = {
        'providerId': widget.providerId,
        'dependantId': widget.dependantId,
        'serviceName': widget.serviceName,
        'date': widget.selectedDate,
        'startTimestamp': startTimestamp.toString(),
        'endTimestamp': endTimestamp.toString(),
        'startTime': startTime24,
        'endTime': endTime24,
        'location': widget.location,
        'notes': widget.notes,
        'tasks': tasksJson,
      };

      final result = await _api.createBookingRequestWithFiles(
        fields: fields,
        files: _selectedFiles,
      );

      print('✅ Booking request response: $result');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking request sent! Waiting for provider approval.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.clientDashboard,
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Error sending booking request: $e');
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Add Tasks & Files'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking Summary', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _summaryRow('Provider', widget.providerName),
                  _summaryRow('Service', widget.serviceName.isEmpty ? 'Not specified' : widget.serviceName),
                  _summaryRow('Date', widget.selectedDate),
                  _summaryRow('Time', '${widget.selectedSlot['startTime']} - ${widget.selectedSlot['endTime']}'),
                  _summaryRow('Location', widget.location.isEmpty ? 'Not specified' : widget.location),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('Tasks to be completed', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._taskControllers.asMap().entries.map((entry) {
              int index = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Task ${index + 1}',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                        ),
                      ),
                    ),
                    if (_taskControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeTaskField(index),
                      ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addTaskField,
              icon: const Icon(Icons.add, color: AppTheme.primary),
              label: Text('Add Another Task', style: TextStyle(color: AppTheme.primary)),
            ),

            const SizedBox(height: 20),

            Text('Attachments (Optional)', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_selectedFiles.isEmpty ? 'Select Files (Images)' : 'Add More Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    ..._selectedFiles.asMap().entries.map((entry) {
                      int idx = entry.key;
                      File file = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file, size: 20, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                file.path.split('/').last,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              onPressed: () => _removeFile(idx),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitBookingRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send Request', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}