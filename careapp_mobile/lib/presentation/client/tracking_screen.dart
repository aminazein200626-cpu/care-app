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
import 'chat_screen.dart';   // ChatScreen الموحد (باستخدام otherUserId, otherUserName)

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
  bool _isDisposed = false;
  
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
  
  final Map<String, String> _stageTimes = {};
  
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

  // دوال مساعدة آمنة
  List<Map<String, dynamic>> _safeList(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Map<String, String> _normalizeStageTimes(dynamic stageTimes) {
    if (stageTimes == null) return {};
    if (stageTimes is Map) {
      return Map.fromEntries(stageTimes.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())));
    }
    if (stageTimes is List) {
      const stageNames = [
        "Request Accepted", "Provider On The Way", "Provider Arrived",
        "Service Started", "In Progress", "Almost Done", "Completed"
      ];
      final result = <String, String>{};
      for (int i = 0; i < stageTimes.length && i < stageNames.length; i++) {
        result[stageNames[i]] = stageTimes[i].toString();
      }
      return result;
    }
    return {};
  }

  void _updateStagesFromStatus(String stage) {
    if (_isDisposed) return;
    final stages = ['Accepted', 'OnWay', 'Arrived', 'Started', 'InProgress', 'AlmostDone', 'Completed'];
    final currentIdx = stages.indexOf(stage);
    _safeSetState(() {
      _accepted = currentIdx >= 0;
      _onWay = currentIdx >= 1;
      _arrived = currentIdx >= 2;
      _started = currentIdx >= 3;
      _inProgress = currentIdx >= 4;
      _almostDone = currentIdx >= 5;
      _completed = currentIdx >= 6;
    });
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Future<void> _loadData() async {
    if (_isDisposed || !mounted) return;
    _safeSetState(() => _isLoading = true);
    try {
      final booking = await _api.getBookingDetails(widget.bookingId);
      final tracking = await _api.getTrackingInfo(widget.bookingId);
      if (_isDisposed || !mounted) return;
      
      _safeSetState(() {
        _bookingData = booking;
        _remainingAmount = (booking['remainingAmount'] ?? 0).toDouble();
        _isCompleted = booking['status'] == 'Completed';
        _clientLat = booking['locationLat'] ?? booking['lat'] ?? 36.7538;
        _clientLng = booking['locationLng'] ?? booking['lng'] ?? 3.0588;
        _clientTasks = _safeList(booking['clientTasks']);
        
        _updateStagesFromStatus(tracking['stage'] ?? '');
        _workSteps = _safeList(tracking['workSteps']);
        _attachments = _safeList(tracking['attachments']);
        _providerLat = tracking['providerLat'] ?? tracking['locationLat'];
        _providerLng = tracking['providerLng'] ?? tracking['locationLng'];
        _stageTimes.addAll(_normalizeStageTimes(tracking['stageTimes']));
        _isLoading = false;
      });
      _startPolling();
    } catch (e) {
      if (_isDisposed || !mounted) return;
      _safeSetState(() => _isLoading = false);
      _showError('Failed to load data: $e');
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      if (_completed) {
        timer.cancel();
        return;
      }
      _refreshTracking();
    });
  }

  Future<void> _refreshTracking() async {
    if (_isDisposed || !mounted) return;
    try {
      final tracking = await _api.getTrackingInfo(widget.bookingId);
      if (_isDisposed || !mounted) return;
      _safeSetState(() {
        _updateStagesFromStatus(tracking['stage'] ?? '');
        _workSteps = _safeList(tracking['workSteps']);
        _attachments = _safeList(tracking['attachments']);
        _providerLat = tracking['providerLat'] ?? tracking['locationLat'];
        _providerLng = tracking['providerLng'] ?? tracking['locationLng'];
        _calculateETA();
        final normalized = _normalizeStageTimes(tracking['stageTimes']);
        _stageTimes.clear();
        _stageTimes.addAll(normalized);
      });
    } catch (e) {}
  }

  void _calculateETA() {
    if (_providerLat != null && _clientLat != null) {
      const double R = 6371;
      double dLat = _toRadians(_providerLat! - _clientLat!);
      double dLon = _toRadians(_providerLng! - _clientLng!);
      double a = sin(dLat/2)*sin(dLat/2) + cos(_toRadians(_clientLat!))*cos(_toRadians(_providerLat!))*sin(dLon/2)*sin(dLon/2);
      double c = 2 * atan2(sqrt(a), sqrt(1-a));
      double distance = R * c;
      double etaMinutes = (distance / 30) * 60;
      _safeSetState(() {
        _eta = etaMinutes < 60 ? "${etaMinutes.toStringAsFixed(0)} min" : "${(etaMinutes / 60).toStringAsFixed(1)} hours";
      });
    }
  }
  double _toRadians(double deg) => deg * pi / 180;

  Future<void> _connectSocket() async {
    if (_isDisposed) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    _socket = IO.io(baseUrl, {
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      if (_isDisposed || !mounted) return;
      _safeSetState(() => _isConnected = true);
      _reconnectAttempts = 0;
      _joinTrackingRoom();
    });

    _socket!.on('trackingUpdate', (data) {
      if (_isDisposed || !mounted) return;
      if (data['bookingId'] == widget.bookingId) {
        _safeSetState(() {
          if (data['stage'] != null) _updateStagesFromStatus(data['stage']);
          if (data['stageTimes'] != null) {
            _stageTimes.clear();
            _stageTimes.addAll(_normalizeStageTimes(data['stageTimes']));
          }
          if (data['providerLat'] != null && data['providerLng'] != null) {
            _providerLat = data['providerLat'];
            _providerLng = data['providerLng'];
            _calculateETA();
          }
          if (data['workSteps'] != null) _workSteps = _safeList(data['workSteps']);
          if (data['attachments'] != null) _attachments = _safeList(data['attachments']);
          if (data['clientTasks'] != null) _clientTasks = _safeList(data['clientTasks']);
          if (data['remainingAmount'] != null) _remainingAmount = (data['remainingAmount'] as num).toDouble();
        });
      }
    });

    _socket!.on('newWorkStep', (data) {
      if (_isDisposed || !mounted) return;
      if (data['bookingId'] == widget.bookingId) {
        final timestamp = DateTime.parse(data['timestamp']);
        _safeSetState(() {
          _workSteps.insert(0, {
            'description': data['description'],
            'note': data['note'],
            'fileUrl': data['fileUrl'],
            'time': DateFormat('MMM dd, yyyy · hh:mm a').format(timestamp),
          });
        });
        _showSnackBar('New work step added', Colors.blue);
      }
    });

    _socket!.on('newAttachment', (data) {
      if (_isDisposed || !mounted) return;
      if (data['bookingId'] == widget.bookingId) {
        final timestamp = DateTime.parse(data['timestamp']);
        _safeSetState(() {
          _attachments.insert(0, {
            'type': data['type'],
            'caption': data['caption'],
            'url': data['url'],
            'time': DateFormat('MMM dd, yyyy · hh:mm a').format(timestamp),
          });
        });
        _showSnackBar('New ${data['type']} uploaded', Colors.blue);
      }
    });

    _socket!.on('taskUpdate', (data) {
      if (_isDisposed || !mounted) return;
      if (data['bookingId'] == widget.bookingId) {
        final index = data['taskIndex'] as int?;
        if (index != null && index < _clientTasks.length) {
          _safeSetState(() {
            _clientTasks[index]['status'] = data['status'];
            _clientTasks[index]['providerNote'] = data['note'] ?? '';
          });
          _showSnackBar('Task "${data['taskName']}" marked as ${data['status']}', Colors.green);
        }
      }
    });

    _socket!.on('disconnect', (_) {
      if (_isDisposed || !mounted) return;
      _safeSetState(() => _isConnected = false);
      _attemptReconnect();
    });

    _socket!.on('connect_error', (_) {
      if (_isDisposed || !mounted) return;
      _safeSetState(() => _isConnected = false);
      _attemptReconnect();
    });
  }

  void _attemptReconnect() {
    if (_isDisposed) return;
    if (_reconnectTimer?.isActive == true) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDisposed && mounted && !_isConnected && !_completed) {
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
    }
  }

  // ✅ دالة الدردشة المعدلة (تستخدم otherUserId و otherUserName)
  void _startChat() {
    if (_isDisposed) return;
    
    final providerId = _bookingData['providerId']?.toString();
    final providerName = _bookingData['provider']?.toString() ?? '';
    
    if (providerId == null || providerId.isEmpty) {
      _showError('Cannot start chat: provider ID missing. Please refresh or contact support.');
      return;
    }
    
    if (providerName.isEmpty) {
      _showError('Cannot start chat: provider name not available.');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          bookingId: widget.bookingId,
          otherUserId: providerId,
          otherUserName: providerName,
          socket: _socket,
        ),
      ),
    );
  }

  void _startAudioCall() {
    if (_isDisposed) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
      providerId: _bookingData['providerId'] ?? '',
      providerName: _bookingData['provider'] ?? 'Provider',
      callType: 'audio',
    )));
  }

  void _startVideoCall() {
    if (_isDisposed) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
      providerId: _bookingData['providerId'] ?? '',
      providerName: _bookingData['provider'] ?? 'Provider',
      callType: 'video',
    )));
  }

  Future<void> _payRemaining() async {
    if (_isDisposed) return;
    if (_remainingAmount <= 0) return;
    _safeSetState(() => _isProcessing = true);
    try {
      final result = await _api.payRemaining(widget.bookingId);
      if (_isDisposed || !mounted) return;
      if (result['success'] == true) {
        _showSnackBar('Payment successful!', Colors.green);
        _showRatingDialog();
      } else {
        _showError(result['message'] ?? 'Payment failed');
      }
    } catch (e) {
      _showError('Payment error: $e');
    } finally {
      if (!_isDisposed && mounted) _safeSetState(() => _isProcessing = false);
    }
  }

  void _showRatingDialog() {
    if (_isDisposed) return;
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
              Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                  onPressed: () => setDialogState(() => rating = i + 1),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 3,
                decoration: const InputDecoration(hintText: "Leave a comment...", border: OutlineInputBorder()),
                onChanged: (val) => comment = val,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Skip")),
            ElevatedButton(onPressed: () async {
              Navigator.pop(ctx);
              await _submitRating(rating, comment);
            }, child: const Text("Submit")),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(int rating, String comment) async {
    if (_isDisposed) return;
    _safeSetState(() => _isProcessing = true);
    try {
      final result = await _api.rateProvider(widget.bookingId, rating, comment);
      if (_isDisposed || !mounted) return;
      if (result['success'] == true) {
        _showSnackBar('Thank you for your feedback!', Colors.green);
        Navigator.pushReplacementNamed(context, AppRoutes.clientHistory);
      } else {
        _showError(result['message'] ?? 'Failed to submit rating');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (!_isDisposed && mounted) _safeSetState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    if (_isDisposed || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSnackBar(String msg, Color color) {
    if (_isDisposed || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)));
  }

  Future<void> _openFile(Map<String, dynamic> att) async {
    if (_isDisposed) return;
    String url = att['url'] ?? '';
    if (url.isEmpty) return;
    String fullUrl = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
    if (_getFileType(att) == 'image') {
      _showImageDialog(fullUrl);
    } else {
      await _launchUrl(fullUrl);
    }
  }

  String _getFileType(Map<String, dynamic> att) {
    if (att['type'] != null && att['type'].toString().isNotEmpty) {
      String type = att['type'].toString().toLowerCase();
      if (type == 'image' || type == 'video' || type == 'audio') return type;
    }
    String url = att['url'] ?? '';
    if (url.isNotEmpty) {
      String ext = url.split('.').last.toLowerCase();
      if (['jpg','jpeg','png','gif'].contains(ext)) return 'image';
      if (['mp4','mov','avi'].contains(ext)) return 'video';
      if (['mp3','wav'].contains(ext)) return 'audio';
    }
    return 'file';
  }

  void _showImageDialog(String url) {
    if (_isDisposed) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url, fit: BoxFit.contain, height: 400, errorBuilder: (_, __, ___) => const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.red)))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
              TextButton(onPressed: () => _launchUrl(url), child: const Text("Open in Browser")),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (_isDisposed) return;
    final fullUrl = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
    if (await canLaunchUrl(Uri.parse(fullUrl))) {
      await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
    } else {
      _showManualOpenDialog(fullUrl);
    }
  }

  void _showManualOpenDialog(String url) {
    if (_isDisposed) return;
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
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _loadData();
    _connectSocket();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'audio', child: Row(children: [Icon(Icons.call), SizedBox(width: 10), Text('Audio Call')])),
              PopupMenuItem(value: 'video', child: Row(children: [Icon(Icons.videocam), SizedBox(width: 10), Text('Video Call')])),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTracking,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
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
              if (_completed && _remainingAmount > 0 && !_isProcessing)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _payRemaining,
                      icon: const Icon(Icons.payment),
                      label: Text("Pay Remaining (${_remainingAmount.toStringAsFixed(0)} DZD)"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ),
              if (_isProcessing) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      ),
    );
  }

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
      _stageItem("Request Accepted", _accepted, Icons.check_circle, isDark),
      _stageItem("Provider On The Way", _onWay, Icons.directions_car, isDark),
      _stageItem("Provider Arrived", _arrived, Icons.location_on, isDark),
      _stageItem("Service Started", _started, Icons.play_circle, isDark),
      _stageItem("In Progress", _inProgress, Icons.engineering, isDark),
      _stageItem("Almost Done", _almostDone, Icons.timer, isDark),
      _stageItem("Completed", _completed, Icons.verified, isDark, isLast: true),
    ]),
  );

  Widget _stageItem(String title, bool isDone, IconData icon, bool isDark, {bool isLast = false}) => IntrinsicHeight(
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
            if (isDone && _stageTimes.containsKey(title)) Text(_stageTimes[title]!, style: const TextStyle(color: Colors.green, fontSize: 10)),
          ]),
        )),
      ],
    ),
  );

  Widget _buildClientTasks(bool isDark) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Your Tasks", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      ..._clientTasks.map((task) {
        final isCompleted = task['status'] == 'completed';
        final providerNote = task['providerNote'] ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(isCompleted ? Icons.check_circle : Icons.pending, color: isCompleted ? Colors.green : Colors.orange, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task['taskName']?.toString() ?? 'Task', style: TextStyle(fontWeight: FontWeight.w600, decoration: isCompleted ? TextDecoration.lineThrough : null, color: isDark ? Colors.white : Colors.black87)),
              if (providerNote.isNotEmpty) Text("📝 $providerNote", style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Text(isCompleted ? "Completed" : "Pending", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isCompleted ? Colors.green : Colors.orange)),
            ),
          ]),
        );
      }).toList(),
    ]),
  );

  Widget _buildWorkSteps(bool isDark) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Work Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      ..._workSteps.map((step) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.assignment_turned_in, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step['description'] ?? 'No description', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
            if (step['note']?.isNotEmpty == true) Text("📝 ${step['note']}", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic)),
            if (step['fileUrl']?.isNotEmpty == true)
              GestureDetector(onTap: () => _openFile({'url': step['fileUrl'], 'type': 'file'}), child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.attach_file, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text("View attachment", style: TextStyle(color: AppTheme.primary, fontSize: 12, decoration: TextDecoration.underline)),
                ]),
              )),
          ])),
          if (step['time'] != null) Text(step['time']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      )),
    ]),
  );

  Widget _buildAttachments(bool isDark) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Updates (${_attachments.length})", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
      const SizedBox(height: 8),
      ..._attachments.map((att) {
        String fileType = _getFileType(att);
        IconData icon = fileType == 'image' ? Icons.image : (fileType == 'video' ? Icons.videocam : Icons.attach_file);
        String displayType = fileType == 'image' ? "Photo" : (fileType == 'video' ? "Video" : "File");
        return GestureDetector(
          onTap: () => _openFile(att),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
            child: Row(children: [
              Icon(icon, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(displayType, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                if (att['caption']?.isNotEmpty == true) Text("📝 ${att['caption']}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                if (att['time'] != null) Text(att['time']!, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ])),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ]),
          ),
        );
      }).toList(),
    ]),
  );
}