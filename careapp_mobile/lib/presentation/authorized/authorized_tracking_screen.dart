// lib/presentation/authorized/authorized_tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../services/authorized_api_service.dart';

class AuthorizedTrackingScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final String providerName;

  const AuthorizedTrackingScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.providerName,
  });

  @override
  State<AuthorizedTrackingScreen> createState() => _AuthorizedTrackingScreenState();
}

class _AuthorizedTrackingScreenState extends State<AuthorizedTrackingScreen> {
  final AuthorizedApiService _api = AuthorizedApiService();
  Timer? _timer;
  bool _isLoading = true;
  
  Map<String, dynamic> _trackingData = {};
  
  // مراحل التتبع
  bool _accepted = false;
  bool _onWay = false;
  bool _arrived = false;
  bool _started = false;
  bool _inProgress = false;
  bool _almostDone = false;
  bool _completed = false;
  
  final Map<int, String?> _stageTimes = {};

  @override
  void initState() {
    super.initState();
    _loadTrackingData();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadTrackingData();
    });
  }

  Future<void> _loadTrackingData() async {
    try {
      final data = await _api.getTrackingInfo(widget.serviceId);
      setState(() {
        _trackingData = data;
        _updateStages(data['stage'] ?? '');
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _updateStages(String stage) {
    setState(() {
      _accepted = stage == 'Accepted' || _isStageAfter(stage, 'Accepted');
      _onWay = stage == 'OnWay' || _isStageAfter(stage, 'OnWay');
      _arrived = stage == 'Arrived' || _isStageAfter(stage, 'Arrived');
      _started = stage == 'Started' || _isStageAfter(stage, 'Started');
      _inProgress = stage == 'InProgress' || _isStageAfter(stage, 'InProgress');
      _almostDone = stage == 'AlmostDone' || _isStageAfter(stage, 'AlmostDone');
      _completed = stage == 'Completed';
      
      if (_trackingData['stageTimes'] != null) {
        _trackingData['stageTimes'].forEach((key, value) {
          _stageTimes[int.parse(key.toString())] = value.toString();
        });
      }
    });
  }

  bool _isStageAfter(String currentStage, String targetStage) {
    final stages = ['Accepted', 'OnWay', 'Arrived', 'Started', 'InProgress', 'AlmostDone', 'Completed'];
    final currentIndex = stages.indexOf(currentStage);
    final targetIndex = stages.indexOf(targetStage);
    return currentIndex > targetIndex;
  }

  String _formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.serviceName,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProviderCard(isDark),
                  const SizedBox(height: 16),
                  _buildStatusCard(isDark),
                  const SizedBox(height: 16),
                  _buildStages(isDark),
                  if (_trackingData['workSteps'] != null && (_trackingData['workSteps'] as List).isNotEmpty)
                    _buildWorkSteps(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildProviderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            child: const Icon(Icons.person, color: AppTheme.primary, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.providerName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  widget.serviceName,
                  style: TextStyle(color: AppTheme.primary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_onWay && !_completed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text("ETA", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    _trackingData['eta'] ?? 'Calculating...',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    String statusText = "Waiting for provider";
    Color statusColor = AppTheme.warning;
    
    if (_onWay) {
      statusText = "Provider is on the way";
      statusColor = AppTheme.inProgress;
    }
    if (_arrived) {
      statusText = "Provider has arrived";
      statusColor = AppTheme.success;
    }
    if (_started) {
      statusText = "Service in progress";
      statusColor = AppTheme.primary;
    }
    if (_completed) {
      statusText = "Service completed";
      statusColor = AppTheme.success;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStages(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _stageItem(0, "Request Accepted", _accepted, Icons.check_circle, isDark),
          _stageItem(1, "Provider On The Way", _onWay, Icons.directions_car, isDark),
          _stageItem(2, "Provider Arrived", _arrived, Icons.location_on, isDark),
          _stageItem(3, "Service Started", _started, Icons.play_circle, isDark),
          _stageItem(4, "In Progress", _inProgress, Icons.engineering, isDark),
          _stageItem(5, "Almost Done", _almostDone, Icons.timer, isDark),
          _stageItem(6, "Completed", _completed, Icons.verified, isDark, isLast: true),
        ],
      ),
    );
  }

  Widget _stageItem(int index, String title, bool isDone, IconData icon, bool isDark, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDone ? Colors.green : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(isDone ? Icons.check : icon, color: isDone ? Colors.white : Colors.grey, size: 18),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: isDone ? Colors.green : Colors.grey[300])),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDone ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                        ),
                      ),
                      if (isDone && _stageTimes[index] != null)
                        Text(
                          _stageTimes[index]!,
                          style: const TextStyle(color: Colors.green, fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkSteps(bool isDark) {
    final steps = _trackingData['workSteps'] as List;
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Work Progress",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 8),
          ...steps.map((step) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    step['description'].toString(),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text(
                  _formatTime(DateTime.parse(step['time'].toString())),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}