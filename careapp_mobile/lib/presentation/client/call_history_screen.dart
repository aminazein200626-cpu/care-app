import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final List<Map<String, dynamic>> _calls = [
    {'name': 'Dr. Amina', 'type': 'audio', 'duration': '5:23', 'date': '2026-04-03', 'time': '10:30 AM', 'missed': false},
    {'name': 'Nurse Fatima', 'type': 'video', 'duration': '12:45', 'date': '2026-04-02', 'time': '02:15 PM', 'missed': false},
    {'name': 'Dr. Ahmed', 'type': 'audio', 'duration': '3:12', 'date': '2026-04-01', 'time': '09:00 AM', 'missed': true},
  ];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Call History'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _calls.length,
                  itemBuilder: (context, index) {
                    final call = _calls[index];
                    return _buildCallCard(call, isDark);
                  },
                ),
    );
  }

  Widget _buildCallCard(Map<String, dynamic> call, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: call['missed'] == true ? Colors.red.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              call['type'] == 'audio' ? Icons.call : Icons.videocam,
              color: call['missed'] == true ? Colors.red : AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call['name'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${call['date']} at ${call['time']}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.timer, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      call['duration'],
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (call['missed'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Missed',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red),
              ),
            ),
          IconButton(
            icon: Icon(Icons.call_outlined, color: AppTheme.primary, size: 22),
            onPressed: () {},
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.call_end, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'No Call History',
            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}