import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import 'tracking_screen.dart';

class RequestDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const RequestDetailsScreen({super.key, required this.requestData});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  bool _isProcessing = false;
  List<Map<String, dynamic>> _taskFiles = [];

  List<dynamic> _safeList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {}
      return [];
    }
    return [];
  }

  String _safeAge(dynamic age) {
    if (age == null) return 'N/A';
    if (age is int) return age.toString();
    if (age is String) return age;
    return age.toString();
  }

  Future<void> _openFile(String path) async {
    if (path.isEmpty) return;
    final String url = path.startsWith('http') ? path : '${ApiConfig.baseUrl}$path';
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error opening file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchTaskFiles(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/task-files/$taskId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _taskFiles = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Error fetching task files: $e');
    }
  }

  void _acceptRequest() async {
    setState(() => _isProcessing = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/booking-requests/${widget.requestData['id']}/accept'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bookingId = data['bookingId'];
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Request accepted"), backgroundColor: Colors.green),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TrackingScreen(bookingId: bookingId),
            ),
          );
        }
      } else {
        throw Exception('Failed to accept');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error accepting request"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _rejectRequest() async {
    setState(() => _isProcessing = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/booking-requests/${widget.requestData['id']}/reject'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Request rejected"), backgroundColor: Colors.red),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to reject');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error rejecting request"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final taskId = widget.requestData['taskId'];
    if (taskId != null && taskId.isNotEmpty) {
      _fetchTaskFiles(taskId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final dependent = widget.requestData['dependent'];
    final tasks = _safeList(widget.requestData['tasks']);
    // Files from DependentFile collection are already inside dependent['files']
    final files = dependent != null ? _safeList(dependent['files']) : [];
    final medicalInfo = dependent != null ? dependent['medicalInfo'] : null;
    
    final String requestStatus = widget.requestData['status']?.toString().toLowerCase() ?? '';
    final bool isPending = requestStatus == 'pending';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Request Details",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (isPending)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  onPressed: _isProcessing ? null : _acceptRequest,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  onPressed: _isProcessing ? null : _rejectRequest,
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Client Information"),
            _buildSimpleCard(isDark, [
              _infoRow(Icons.person_outline, "Full Name", widget.requestData['clientName'] ?? 'Unknown'),
              _infoRow(Icons.email_outlined, "Email", widget.requestData['clientEmail'] ?? 'Not provided'),
              _infoRow(Icons.phone_android_outlined, "Phone", widget.requestData['clientPhone'] ?? 'Not provided'),
              _infoRow(Icons.location_on_outlined, "Address", widget.requestData['clientAddress'] ?? 'Not specified'),
              _infoRow(Icons.map_outlined, "Wilaya", widget.requestData['clientWilaya'] ?? 'Not specified'),
            ]),

            const SizedBox(height: 20),

            _buildSectionTitle("Dependant Information"),
            _buildSimpleCard(isDark, [
              if (dependent != null) ...[
                _infoRow(Icons.person_outline, "Full Name", dependent['name'] ?? 'Not specified'),
                _infoRow(Icons.family_restroom, "Relationship", dependent['relationship'] ?? 'Not specified'),
                _infoRow(Icons.cake_outlined, "Age", _safeAge(dependent['age'])),
                _infoRow(Icons.medical_services, "Health Notes", dependent['healthNotes'] ?? 'No health notes'),
                
                // Medical Information (if available)
                if (medicalInfo != null && (medicalInfo['bloodType']?.isNotEmpty == true ||
                    medicalInfo['allergies']?.isNotEmpty == true ||
                    medicalInfo['medications']?.isNotEmpty == true ||
                    medicalInfo['conditions']?.isNotEmpty == true)) ...[
                  const SizedBox(height: 12),
                  const Text("Medical Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  if (medicalInfo['bloodType'] != null && medicalInfo['bloodType'].isNotEmpty)
                    _infoRow(Icons.bloodtype, "Blood Type", medicalInfo['bloodType']),
                  if (medicalInfo['allergies'] != null && medicalInfo['allergies'].isNotEmpty)
                    _infoRow(Icons.warning, "Allergies", medicalInfo['allergies']),
                  if (medicalInfo['medications'] != null && medicalInfo['medications'].isNotEmpty)
                    _infoRow(Icons.medication, "Medications", medicalInfo['medications']),
                  if (medicalInfo['conditions'] != null && medicalInfo['conditions'].isNotEmpty)
                    _infoRow(Icons.health_and_safety, "Conditions", medicalInfo['conditions']),
                ],
                
                // Files from DependentFile
                if (files.isNotEmpty) _buildFilesSection(files, isDark),
              ] else
                _infoRow(Icons.info_outline, "No dependant", "No dependant associated with this booking", isWarning: true),
            ]),

            const SizedBox(height: 20),

            _buildSectionTitle("Service Details"),
            _buildSimpleCard(isDark, [
              _infoRow(Icons.category_outlined, "Service", widget.requestData['serviceName'] ?? 'Care Service'),
              _infoRow(Icons.calendar_month_outlined, "Date", widget.requestData['date'] ?? 'N/A'),
              _infoRow(Icons.access_time_outlined, "Time", '${widget.requestData['startTime'] ?? ''} - ${widget.requestData['endTime'] ?? ''}'),
              _infoRow(Icons.location_on_outlined, "Location", widget.requestData['location'] ?? 'Not specified'),
              if ((widget.requestData['notes'] ?? '').isNotEmpty)
                _infoRow(Icons.note_outlined, "Notes", widget.requestData['notes']),
            ]),

            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionTitle("Tasks Requested"),
              _buildSimpleCard(isDark, [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tasks.map((task) {
                    final taskName = task is Map ? (task['taskName'] ?? 'Task') : task.toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.checklist, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(taskName)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ]),
            ],

            if (_taskFiles.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionTitle("Client Attachments"),
              _buildSimpleCard(isDark, [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _taskFiles.map((file) => GestureDetector(
                    onTap: () => _openFile(file['url'] ?? ''),
                    child: Chip(
                      label: Text(file['name'] ?? 'File', style: const TextStyle(fontSize: 11)),
                      avatar: const Icon(Icons.attach_file, size: 14),
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                    ),
                  )).toList(),
                ),
              ]),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: isPending ? _buildBottomActions(context, isDark) : null,
    );
  }

  Widget _buildFilesSection(List files, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Attached Files:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: files.map((file) {
              String filePath = '';
              String fileName = 'File';
              if (file is Map) {
                filePath = file['url'] ?? file['path'] ?? '';
                fileName = file['name'] ?? filePath.split('/').last;
              } else if (file is String) {
                filePath = file;
                fileName = filePath.split('/').last;
              }
              if (filePath.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () => _openFile(filePath),
                child: Chip(
                  label: Text(fileName.length > 30 ? '${fileName.substring(0, 27)}...' : fileName,
                      style: const TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.attach_file, size: 14),
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildSimpleCard(bool isDark, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isWarning = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isWarning ? Colors.orange : Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
                children: [
                  TextSpan(text: "$label: ", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isWarning ? Colors.orange : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isProcessing ? null : _rejectRequest,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Reject", style: TextStyle(color: Colors.red)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _acceptRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Accept", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}