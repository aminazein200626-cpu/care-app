import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../core/api_config.dart';
import '../../services/client_api_service.dart';
import '../client/call_screen.dart';

class TrackingScreen extends StatefulWidget {
  final String bookingId;
  const TrackingScreen({super.key, required this.bookingId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final ClientApiService _api = ClientApiService();
  IO.Socket? _socket;
  
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isProcessing = false;
  
  Map<String, dynamic> _bookingData = {};
  double _remainingAmount = 0.0;
  bool _isCompleted = false;
  
  bool _accepted = false;
  bool _onWay = false;
  bool _arrived = false;
  bool _started = false;
  bool _inProgress = false;
  bool _almostDone = false;
  bool _completed = false;
  
  final Map<int, String?> _stageTimes = {};
  
  double? _providerLat;
  double? _providerLng;
  double? _clientLat;
  double? _clientLng;
  String _eta = "Calculating...";
  
  List<Map<String, dynamic>> _workSteps = [];
  List<Map<String, dynamic>> _attachments = [];
  List<Map<String, dynamic>> _clientTasks = [];
  
  final String baseUrl = ApiConfig.baseUrl;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _connectSocket();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final booking = await _api.getBookingDetails(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _bookingData = booking;
        _remainingAmount = (booking['remainingAmount'] ?? 0).toDouble();
        _isCompleted = booking['status'] == 'Completed';
        _clientLat = booking['locationLat'] ?? booking['lat'] ?? 36.7538;
        _clientLng = booking['locationLng'] ?? booking['lng'] ?? 3.0588;
        _clientTasks = List<Map<String, dynamic>>.from(booking['clientTasks'] ?? []);
      });
      
      final tracking = await _api.getTrackingInfo(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _updateStagesFromStatus(tracking['stage'] ?? '');
        _workSteps = List<Map<String, dynamic>>.from(tracking['workSteps'] ?? []);
        _attachments = List<Map<String, dynamic>>.from(tracking['attachments'] ?? []);
        _providerLat = tracking['providerLat'] ?? tracking['locationLat'];
        _providerLng = tracking['providerLng'] ?? tracking['locationLng'];
        
        if (tracking['stageTimes'] != null) {
          final stageTimesMap = tracking['stageTimes'] as Map;
          stageTimesMap.forEach((key, value) {
            final index = _getStageIndex(key.toString());
            if (index != -1) _stageTimes[index] = value.toString();
          });
        }
        _isLoading = false;
      });
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load data: $e');
      }
    }
  }

  int _getStageIndex(String stage) {
    final stages = ['Accepted', 'OnWay', 'Arrived', 'Started', 'InProgress', 'AlmostDone', 'Completed'];
    return stages.indexOf(stage);
  }

  void _updateStagesFromStatus(String stage) {
    setState(() {
      _accepted = stage == 'Accepted' || _isStageCompleted(stage, 'Accepted');
      _onWay = stage == 'OnWay' || _isStageCompleted(stage, 'OnWay');
      _arrived = stage == 'Arrived' || _isStageCompleted(stage, 'Arrived');
      _started = stage == 'Started' || _isStageCompleted(stage, 'Started');
      _inProgress = stage == 'InProgress' || _isStageCompleted(stage, 'InProgress');
      _almostDone = stage == 'AlmostDone' || _isStageCompleted(stage, 'AlmostDone');
      _completed = stage == 'Completed';
    });
  }

  bool _isStageCompleted(String currentStage, String targetStage) {
    final stages = ['Accepted', 'OnWay', 'Arrived', 'Started', 'InProgress', 'AlmostDone', 'Completed'];
    final currentIndex = stages.indexOf(currentStage);
    final targetIndex = stages.indexOf(targetStage);
    return currentIndex > targetIndex;
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && !_completed) _refreshTracking();
      else if (_completed) timer.cancel();
    });
  }

  Future<void> _refreshTracking() async {
    try {
      final tracking = await _api.getTrackingInfo(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _updateStagesFromStatus(tracking['stage'] ?? '');
        _workSteps = List<Map<String, dynamic>>.from(tracking['workSteps'] ?? []);
        _attachments = List<Map<String, dynamic>>.from(tracking['attachments'] ?? []);
        _providerLat = tracking['providerLat'] ?? tracking['locationLat'];
        _providerLng = tracking['providerLng'] ?? tracking['locationLng'];
        _calculateETA();
      });
    } catch (e) {
      // silent fail
    }
  }

  void _calculateETA() {
    if (_providerLat != null && _clientLat != null && _providerLng != null && _clientLng != null) {
      final distance = _calculateDistance(_providerLat!, _providerLng!, _clientLat!, _clientLng!);
      final etaMinutes = (distance / 30) * 60;
      _eta = etaMinutes < 60 ? "${etaMinutes.toStringAsFixed(0)} min" : "${(etaMinutes / 60).toStringAsFixed(1)} hours";
      if (mounted) setState(() {});
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  Future<void> _connectSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      debugPrint('❌ No token for socket connection');
      return;
    }

    _socket = IO.io(baseUrl, {
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      debugPrint('✅ Socket connected');
      if (mounted) setState(() => _isConnected = true);
      _reconnectAttempts = 0;
      _joinTrackingRoom();
    });

    _socket!.on('trackingUpdate', (data) {
      if (data['bookingId'] == widget.bookingId) {
        _handleTrackingUpdate(data);
      }
    });

    _socket!.on('newWorkStep', (data) {
      if (data['bookingId'] == widget.bookingId) {
        if (mounted) {
          setState(() => _workSteps.insert(0, {
            'description': data['description'],
            'note': data['note'],
            'fileUrl': data['fileUrl'],
            'time': _formatTime(DateTime.parse(data['timestamp']))
          }));
        }
      }
    });

    _socket!.on('newAttachment', (data) {
      if (data['bookingId'] == widget.bookingId) {
        if (mounted) {
          setState(() => _attachments.insert(0, {
            'type': data['type'],
            'caption': data['caption'],
            'url': data['url'],
            'time': _formatTime(DateTime.parse(data['timestamp']))
          }));
        }
      }
    });

    _socket!.on('disconnect', (_) {
      debugPrint('⚠️ Socket disconnected');
      if (mounted) setState(() => _isConnected = false);
      _attemptReconnect();
    });

    _socket!.on('connect_error', (err) {
      debugPrint('❌ Socket connection error: $err');
      if (mounted) setState(() => _isConnected = false);
      _attemptReconnect();
    });
  }

  void _attemptReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isConnected && !_completed) {
        debugPrint('🔄 Attempting to reconnect socket...');
        _connectSocket();
      }
    });
  }

  Future<void> _joinTrackingRoom() async {
    if (_socket == null || !_socket!.connected) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId != null && userId.isNotEmpty) {
      _socket!.emit('joinTracking', {'bookingId': widget.bookingId, 'userId': userId});
      debugPrint('📡 Joined tracking room for booking ${widget.bookingId}');
    }
  }

  void _handleTrackingUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      if (data['stage'] != null) {
        _updateStagesFromStatus(data['stage']);
      }
      if (data['stageTimes'] != null) {
        (data['stageTimes'] as Map).forEach((key, value) {
          final index = _getStageIndex(key.toString());
          if (index != -1) _stageTimes[index] = value.toString();
        });
      }
      if (data['providerLat'] != null && data['providerLng'] != null) {
        _providerLat = data['providerLat'];
        _providerLng = data['providerLng'];
        _calculateETA();
      }
      if (data['workSteps'] != null) {
        _workSteps = List<Map<String, dynamic>>.from(data['workSteps']);
      }
      if (data['attachments'] != null) {
        _attachments = List<Map<String, dynamic>>.from(data['attachments']);
      }
      if (data['clientTasks'] != null) {
        _clientTasks = List<Map<String, dynamic>>.from(data['clientTasks']);
      }
      if (data['remainingAmount'] != null) {
        _remainingAmount = (data['remainingAmount'] as num).toDouble();
      }
    });
  }

  String _formatTime(DateTime time) => DateFormat('hh:mm a').format(time);

  void _startChat() => Navigator.pushNamed(context, AppRoutes.clientChat, arguments: {
    'providerId': _bookingData['providerId'],
    'providerName': _bookingData['provider'],
    'bookingId': widget.bookingId,
  });

  void _startAudioCall() => Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
    providerId: _bookingData['providerId'] ?? '',
    providerName: _bookingData['provider'] ?? 'Provider',
    callType: 'audio',
  )));

  void _startVideoCall() => Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
    providerId: _bookingData['providerId'] ?? '',
    providerName: _bookingData['provider'] ?? 'Provider',
    callType: 'video',
  )));

  Future<void> _payRemaining() async {
    if (_remainingAmount <= 0) {
      _showError('No remaining amount to pay');
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final result = await _api.payRemaining(widget.bookingId);
      if (!mounted) return;
      if (result['success'] == true) {
        _showSnackBar('Payment successful!', Colors.green);
        _showRatingDialog();
      } else {
        _showError(result['message'] ?? 'Payment failed');
      }
    } catch (e) {
      _showError('Payment error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRatingDialog() {
    int rating = 0;
    String comment = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Rate the Provider"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How was your experience?"),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Skip")),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _submitRating(rating, comment);
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(int rating, String comment) async {
    setState(() => _isProcessing = true);
    try {
      final result = await _api.rateProvider(widget.bookingId, rating, comment);
      if (!mounted) return;
      if (result['success'] == true) {
        _showSnackBar('Thank you for your feedback!', Colors.green);
        Navigator.pushReplacementNamed(context, AppRoutes.clientHistory);
      } else {
        _showError(result['message'] ?? 'Failed to submit rating');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)));
  }

  // ==================== FILE HANDLING ====================
  String _getFileType(Map<String, dynamic> att) {
    if (att['type'] != null && att['type'].toString().isNotEmpty) {
      String type = att['type'].toString().toLowerCase();
      if (type == 'image' || type == 'video' || type == 'audio') return type;
    }
    String url = att['url'] ?? '';
    if (url.isNotEmpty) {
      String ext = url.split('.').last.toLowerCase();
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'gif') return 'image';
      if (ext == 'mp4' || ext == 'mov' || ext == 'avi') return 'video';
      if (ext == 'mp3' || ext == 'wav') return 'audio';
    }
    return 'file';
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'image': return Icons.image;
      case 'video': return Icons.videocam;
      case 'audio': return Icons.mic;
      default: return Icons.attach_file;
    }
  }

  String _getDisplayType(String type) {
    switch (type) {
      case 'image': return "📷 Photo";
      case 'video': return "🎥 Video";
      case 'audio': return "🎤 Voice";
      default: return "📎 File";
    }
  }

  Future<void> _openFile(Map<String, dynamic> att) async {
    String url = att['url'] ?? '';
    if (url.isEmpty) return;
    String fullUrl = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
    String type = _getFileType(att);
    if (type == 'image') {
      _showImageDialog(fullUrl);
    } else {
      await _launchUrl(fullUrl);
    }
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url, fit: BoxFit.contain, height: 400, errorBuilder: (_, __, ___) {
              return const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.red)));
            }),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
                TextButton(
                  onPressed: () => _launchUrl(url),
                  child: const Text("Open in Browser"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final fullUrl = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
    try {
      if (await canLaunchUrl(Uri.parse(fullUrl))) {
        await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
      } else {
        _showManualOpenDialog(fullUrl);
      }
    } catch (e) {
      _showManualOpenDialog(fullUrl);
    }
  }

  void _showManualOpenDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cannot Open Automatically"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please copy this link and open in browser:"),
            const SizedBox(height: 8),
            SelectableText(url, style: const TextStyle(color: Colors.blue)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) return Scaffold(body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Service Tracking", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.chat_outlined), onPressed: _startChat),
          PopupMenuButton<String>(
            icon: const Icon(Icons.call_outlined),
            onSelected: (v) => v == 'audio' ? _startAudioCall() : _startVideoCall(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'audio', child: Row(children: [Icon(Icons.call), SizedBox(width: 10), Text('Audio Call')])),
              const PopupMenuItem(value: 'video', child: Row(children: [Icon(Icons.videocam), SizedBox(width: 10), Text('Video Call')])),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProviderCard(isDark),
                const SizedBox(height: 16),
                _buildStatusCard(isDark),
                const SizedBox(height: 16),
                _buildStages(isDark),
                if (_clientTasks.isNotEmpty) _buildClientTasks(isDark),
                if (_workSteps.isNotEmpty) _buildWorkSteps(isDark),
                if (_attachments.isNotEmpty) _buildAttachments(isDark),
                if (_completed && _remainingAmount > 0 && !_isProcessing) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _payRemaining,
                      icon: const Icon(Icons.payment),
                      label: Text("Pay Remaining (${_remainingAmount.toStringAsFixed(0)} DZD)"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
                if (_isProcessing) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
          _buildConnectionStatus(isDark),
        ],
      ),
    );
  }

  // ========== UI Components ==========
  Widget _buildProviderCard(bool isDark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Row(
      children: [
        CircleAvatar(radius: 30, backgroundColor: AppTheme.primary.withOpacity(0.1), child: const Icon(Icons.person, color: AppTheme.primary, size: 30)),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_bookingData['provider'] ?? 'Provider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text(_bookingData['service'] ?? 'Service', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
            Text(_bookingData['providerPhone'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        )),
        if (_onWay && !_completed) Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Column(children: [const Text("ETA", style: TextStyle(fontSize: 10)), Text(_eta, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary))]),
        ),
      ],
    ),
  );

  Widget _buildStatusCard(bool isDark) {
    String statusText = "Waiting for provider";
    Color statusColor = AppTheme.warning;
    if (_onWay) { statusText = "Provider is on the way"; statusColor = AppTheme.inProgress; }
    if (_arrived) { statusText = "Provider has arrived"; statusColor = AppTheme.success; }
    if (_started) { statusText = "Service in progress"; statusColor = AppTheme.primary; }
    if (_completed) { statusText = "Service completed"; statusColor = AppTheme.success; }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.3))),
      child: Row(children: [
        Icon(Icons.info_outline, color: statusColor),
        const SizedBox(width: 12),
        Expanded(child: Text(statusText, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500))),
        if (_isConnected) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
      ]),
    );
  }

  Widget _buildStages(bool isDark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(children: [
      _stageItem(0, "Request Accepted", _accepted, Icons.check_circle, isDark),
      _stageItem(1, "Provider On The Way", _onWay, Icons.directions_car, isDark),
      _stageItem(2, "Provider Arrived", _arrived, Icons.location_on, isDark),
      _stageItem(3, "Service Started", _started, Icons.play_circle, isDark),
      _stageItem(4, "In Progress", _inProgress, Icons.engineering, isDark),
      _stageItem(5, "Almost Done", _almostDone, Icons.timer, isDark),
      _stageItem(6, "Completed", _completed, Icons.verified, isDark, isLast: true),
    ]),
  );

  Widget _stageItem(int index, String title, bool isDone, IconData icon, bool isDark, {bool isLast = false}) => IntrinsicHeight(
    child: Row(
      children: [
        Column(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isDone ? Colors.green : Colors.grey[300], shape: BoxShape.circle),
            child: Icon(isDone ? Icons.check : icon, color: isDone ? Colors.white : Colors.grey, size: 18)),
          if (!isLast) Expanded(child: Container(width: 2, color: isDone ? Colors.green : Colors.grey[300])),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? (isDark ? Colors.white : Colors.black87) : Colors.grey)),
            if (isDone && _stageTimes[index] != null) Text(_stageTimes[index]!, style: const TextStyle(color: Colors.green, fontSize: 10)),
          ]),
        )),
      ],
    ),
  );

  Widget _buildClientTasks(bool isDark) {
    if (_clientTasks.isEmpty) return const SizedBox.shrink();
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
          const Text("Your Tasks", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ..._clientTasks.map((task) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  task['status'] == 'completed' ? Icons.check_circle : Icons.pending,
                  color: task['status'] == 'completed' ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['taskName'] ?? 'Task',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          decoration: task['status'] == 'completed' ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (task['providerNote'] != null && task['providerNote'].toString().isNotEmpty)
                        Text(
                          "📝 ${task['providerNote']}",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Text(
                  task['status'] == 'completed' ? "Done" : "Pending",
                  style: TextStyle(
                    fontSize: 11,
                    color: task['status'] == 'completed' ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildWorkSteps(bool isDark) {
    if (_workSteps.isEmpty) return const SizedBox.shrink();
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
          Text("Work Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          ..._workSteps.map((step) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(step['description'] ?? 'No description', style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
                    Text(step['time'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
                if (step['note'] != null && step['note'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("📝 ${step['note']}", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                if (step['fileUrl'] != null && step['fileUrl'].toString().isNotEmpty)
                  GestureDetector(
                    onTap: () => _openFile({'url': step['fileUrl'], 'type': 'file'}),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text("📎 View attachment", style: TextStyle(color: AppTheme.primary, fontSize: 12, decoration: TextDecoration.underline)),
                    ),
                  ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildAttachments(bool isDark) {
    if (_attachments.isEmpty) return const SizedBox.shrink();
    List<Widget> attachmentWidgets = [];
    for (var att in _attachments) {
      String fileType = _getFileType(att);
      IconData icon = _getFileIcon(fileType);
      String displayType = _getDisplayType(fileType);
      attachmentWidgets.add(
        GestureDetector(
          onTap: () => _openFile(att),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayType, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      if (att['caption'] != null && att['caption'].toString().isNotEmpty)
                        Text(att['caption'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      Text(att['time'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),
      );
    }
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
          Text("Updates (${_attachments.length})", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          ...attachmentWidgets,
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(bool isDark) {
    if (!_isConnected && !_completed) {
      return Positioned(
        bottom: 20,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text("Reconnecting...", style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}