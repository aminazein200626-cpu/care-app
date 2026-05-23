import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import '../../services/authorized_api_service.dart';
import '../client/call_screen.dart';

class AuthorizedTrackingScreen extends StatefulWidget {
  final String serviceId;
  const AuthorizedTrackingScreen({super.key, required this.serviceId});

  @override
  State<AuthorizedTrackingScreen> createState() => _AuthorizedTrackingScreenState();
}

class _AuthorizedTrackingScreenState extends State<AuthorizedTrackingScreen> {
  final AuthorizedApiService _api = AuthorizedApiService();
  IO.Socket? _socket;
  
  bool _isLoading = true;
  bool _isConnected = false;
  
  Map<String, dynamic> _bookingData = {};
  double _remainingAmount = 0.0;
  
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
  
  String? _providerId;
  String? _providerName;
  String? _providerPhone;
  String? _providerAvatar;
  
  final String baseUrl = ApiConfig.baseUrl;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;

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

  // دالة التطبيع المُحسَّنة: تتعامل مع جميع التنسيقات وترجع Map<String, String> آمنة
  Map<String, String> _normalizeStageTimes(dynamic stageTimes) {
    if (stageTimes == null) return {};
    
    // إذا كان List (مصفوفة)
    if (stageTimes is List) {
      final List<String> stageNames = [
        "Request Accepted", "Provider On The Way", "Provider Arrived",
        "Service Started", "In Progress", "Almost Done", "Completed"
      ];
      Map<String, String> result = {};
      for (int i = 0; i < stageTimes.length && i < stageNames.length; i++) {
        result[stageNames[i]] = stageTimes[i]?.toString() ?? '';
      }
      return result;
    }
    
    // إذا كان Map (كائن)
    if (stageTimes is Map) {
      Map<String, String> result = {};
      stageTimes.forEach((key, value) {
        final keyStr = key.toString();
        // تجاهل المفاتيح التي تبدأ بـ _ (مثل _id)
        if (keyStr.startsWith('_')) return;
        result[keyStr] = value?.toString() ?? '';
      });
      return result;
    }
    
    // أي نوع آخر
    return {};
  }

  // دالة مساعدة لتحويل أي قائمة إلى List<Map<String, dynamic>> بأمان (تجاهل العناصر غير الخريطة)
  List<Map<String, dynamic>> _safeList(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final booking = await _api.getBookingDetails(widget.serviceId);
      if (!mounted) return;
      setState(() {
        _bookingData = booking;
        _remainingAmount = (booking['remainingAmount'] ?? 0).toDouble();
        _clientLat = booking['locationLat'] ?? booking['lat'] ?? 36.7538;
        _clientLng = booking['locationLng'] ?? booking['lng'] ?? 3.0588;
        _clientTasks = _safeList(booking['clientTasks']);
        _providerId = booking['providerId'];
        _providerName = booking['provider'];
        _providerPhone = booking['providerPhone'];
        _providerAvatar = booking['providerAvatar'];
      });
      
      final tracking = await _api.getTrackingInfo(widget.serviceId);
      if (!mounted) return;
      setState(() {
        _updateStagesFromStatus(tracking['stage'] ?? '');
        _workSteps = _safeList(tracking['workSteps']);
        _attachments = _safeList(tracking['attachments']);
        _providerLat = tracking['providerLat'];
        _providerLng = tracking['providerLng'];
        
        final normalized = _normalizeStageTimes(tracking['stageTimes']);
        _stageTimes.clear();
        _stageTimes.addAll(normalized);
        
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
      final tracking = await _api.getTrackingInfo(widget.serviceId);
      if (!mounted) return;
      setState(() {
        _updateStagesFromStatus(tracking['stage'] ?? '');
        _workSteps = _safeList(tracking['workSteps']);
        _attachments = _safeList(tracking['attachments']);
        _providerLat = tracking['providerLat'];
        _providerLng = tracking['providerLng'];
        _calculateETA();
        
        final normalized = _normalizeStageTimes(tracking['stageTimes']);
        _stageTimes.clear();
        _stageTimes.addAll(normalized);
      });
    } catch (e) {}
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
    if (token == null || token.isEmpty) return;

    _socket = IO.io(baseUrl, {
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      if (mounted) setState(() => _isConnected = true);
      _joinTrackingRoom();
    });

    _socket!.on('trackingUpdate', (data) {
      if (data['bookingId'] == widget.serviceId && mounted) {
        setState(() {
          if (data['stage'] != null) _updateStagesFromStatus(data['stage']);
          if (data['stageTimes'] != null) {
            final normalized = _normalizeStageTimes(data['stageTimes']);
            _stageTimes.clear();
            _stageTimes.addAll(normalized);
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

    _socket!.on('disconnect', (_) {
      if (mounted) setState(() => _isConnected = false);
      _attemptReconnect();
    });

    _socket!.on('connect_error', (err) {
      if (mounted) setState(() => _isConnected = false);
      _attemptReconnect();
    });
  }

  void _attemptReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isConnected && !_completed) {
        _connectSocket();
      }
    });
  }

  Future<void> _joinTrackingRoom() async {
    if (_socket == null || !_socket!.connected) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId != null && userId.isNotEmpty) {
      _socket!.emit('joinTracking', {'bookingId': widget.serviceId, 'userId': userId});
    }
  }

  void _startChat() {
    Navigator.pushNamed(context, '/authorized/chat', arguments: {
      'serviceId': widget.serviceId,
      'providerId': _providerId,
      'providerName': _providerName,
    });
  }

  void _startAudioCall() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
      providerId: _providerId ?? '',
      providerName: _providerName ?? 'Provider',
      callType: 'audio',
    )));
  }

  void _startVideoCall() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
      providerId: _providerId ?? '',
      providerName: _providerName ?? 'Provider',
      callType: 'video',
    )));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

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
      case 'image': return "Photo";
      case 'video': return "Video";
      case 'audio': return "Voice";
      default: return "File";
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
              ],
            ),
          ),
          _buildConnectionStatus(isDark),
        ],
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
            Text(_providerName ?? 'Provider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text(_bookingData['service'] ?? 'Service', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
            Text(_providerPhone ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
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
          const Text("Client Tasks", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ..._clientTasks.map((task) {
            final taskName = task['taskName'] ?? 'Task';
            final status = task['status'] ?? 'pending';
            final isCompleted = status == 'completed';
            final providerNote = task['providerNote'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: isCompleted ? Border.all(color: Colors.green.withOpacity(0.3)) : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.pending,
                    color: isCompleted ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          taskName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (providerNote.isNotEmpty)
                          Text(
                            "📝 $providerNote",
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isCompleted ? "Completed" : "Pending",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
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
          const Text("Work Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ..._workSteps.map((step) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_turned_in, size: 20, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(step['description'] ?? 'No description', style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
                if (step['time'] != null) Text(step['time']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                        Text(
                          "📝 ${att['caption']}",
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      Text(
                        att['time'] ?? '',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
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