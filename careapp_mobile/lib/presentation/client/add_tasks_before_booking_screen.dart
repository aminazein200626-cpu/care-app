import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
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
  });

  @override
  State<AddTasksBeforeBookingScreen> createState() => _AddTasksBeforeBookingScreenState();
}

class _AddTasksBeforeBookingScreenState extends State<AddTasksBeforeBookingScreen> {
  final List<TextEditingController> _taskControllers = [TextEditingController()];
  final ClientApiService _api = ClientApiService();
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

  Future<void> _submitBookingRequest() async {
    // جمع المهام
    final tasks = _taskControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => {'taskName': c.text.trim()})
        .toList();
    
    // التحقق من وجود خدمة
    if (widget.serviceName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service name is missing. Please go back and select a service.'), backgroundColor: Colors.red),
      );
      return;
    }

    // التحقق من وجود وقت
    if (widget.selectedSlot['startTime'] == null || widget.selectedSlot['endTime'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time slot is missing. Please go back and select a time.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final requestData = {
        'providerId': widget.providerId,
        'dependantId': widget.dependantId, 
        'serviceName': widget.serviceName,
        'date': widget.selectedDate,
        'startTime': widget.selectedSlot['startTime'],
        'endTime': widget.selectedSlot['endTime'],
        'location': widget.location,
        'notes': widget.notes,
        'tasks': tasks,
      };
      
      print('📤 Sending booking request: $requestData');
      
      final result = await _api.createBookingRequest(requestData);
      
      print('✅ Booking request response: $result');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking request sent! Waiting for provider approval.'),
            backgroundColor: Colors.green,
          ),
        );
        // العودة إلى الصفحة الرئيسية
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print('❌ Error sending booking request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Add Tasks'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
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