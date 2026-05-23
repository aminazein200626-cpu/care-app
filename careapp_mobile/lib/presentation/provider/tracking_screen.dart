import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../client/chat_screen.dart';  // ✅ استيراد ChatScreen الموحد

class TrackingScreen extends StatefulWidget {
  final String? bookingId;
  const TrackingScreen({super.key, this.bookingId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  bool _isUpdating = false;
  bool _isPicking = false;
  bool _ratingDialogShown = false;
  IO.Socket? _socket;
  bool _isConnected = false;

  bool _isDisposed = false;

  Map<String, dynamic>? _dependent;
  List<Map<String, dynamic>> _dependentFiles = [];
  List<Map<String, dynamic>> _taskFiles = [];

  bool _accepted = false;
  bool _onWay = false;
  bool _arrived = false;
  bool _started = false;
  bool _inProgress = false;
  bool _almostDone = false;
  bool _completed = false;

  List<Map<String, dynamic>> _workSteps = [];
  List<Map<String, dynamic>> _attachments = [];
  Timer? _locationTimer;
  bool _isTrackingLocation = false;

  String get _actualBookingId => _data['_id']?.toString() ?? _data['id']?.toString() ?? widget.bookingId ?? '';

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _fetchData();
    _requestLocationPermission();
    _connectSocket();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _connectSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) return;

    _socket = IO.io(ApiConfig.baseUrl, {
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      if (_isDisposed) return;
      debugPrint('✅ Provider socket connected');
      setState(() => _isConnected = true);
      _joinTrackingRoom();
    });

    _socket!.on('trackingUpdate', (data) {
      if (_isDisposed) return;
      if (data['bookingId'] == _actualBookingId) {
        _handleTrackingUpdate(data);
      }
    });

    _socket!.on('disconnect', (_) {
      if (_isDisposed) return;
      debugPrint('⚠️ Provider socket disconnected');
      setState(() => _isConnected = false);
    });
  }

  void _joinTrackingRoom() {
    if (_socket != null && _socket!.connected && _actualBookingId.isNotEmpty) {
      _socket!.emit('joinTracking', {'bookingId': _actualBookingId});
      debugPrint('📡 Provider joined tracking room: $_actualBookingId');
    }
  }

  void _handleTrackingUpdate(Map<String, dynamic> data) {
    if (!mounted || _isDisposed) return;
    if (data['paymentStatus'] != null) {
      setState(() {
        _data['paymentStatus'] = data['paymentStatus'];
        if (data['remainingAmount'] != null) {
          _data['remainingAmount'] = data['remainingAmount'];
        }
      });
      debugPrint('💰 Payment status updated: ${_data['paymentStatus']}, remaining: ${_data['remainingAmount']}');
      _checkAndShowClientRatingDialog();
    }
    if (data['stage'] != null) {
      setState(() {
        _updateStagesFromStatus(data['stage']);
        if (data['stageTimes'] != null) _data['stageTimes'] = data['stageTimes'];
        if (data['workSteps'] != null) _workSteps = List<Map<String, dynamic>>.from(data['workSteps']);
        if (data['attachments'] != null) _attachments = List<Map<String, dynamic>>.from(data['attachments']);
        if (data['clientTasks'] != null) _data['clientTasks'] = data['clientTasks'];
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
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
      debugPrint('Error fetching task files: $e');
    }
  }

  Future<void> _fetchData() async {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) {
      setState(() { _error = "No booking ID"; _isLoading = false; });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() { _error = "Not authenticated"; _isLoading = false; });
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/bookings/${widget.bookingId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _data = data;
          _workSteps = List<Map<String, dynamic>>.from(data['workSteps'] ?? []);
          _attachments = List<Map<String, dynamic>>.from(data['attachments'] ?? []);
          if (data['dependent'] != null) {
            _dependent = Map<String, dynamic>.from(data['dependent']);
            _dependentFiles = List<Map<String, dynamic>>.from(_dependent?['files'] ?? []);
          }
          final stage = data['trackingStage'] ?? 'Pending';
          _updateStagesFromStatus(stage);
          _isLoading = false;
        });
        if (data['taskId'] != null) {
          await _fetchTaskFiles(data['taskId'].toString());
        }
        if (_onWay && !_completed && !_isTrackingLocation) {
          _startLocationTracking();
        }
        _checkAndShowClientRatingDialog();
      } else {
        setState(() { _error = "Failed to load"; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _updateStagesFromStatus(String stage) {
    _accepted = stage == 'Accepted' || stage == 'OnWay' || stage == 'Arrived' || stage == 'Started' || stage == 'InProgress' || stage == 'AlmostDone';
    _onWay = stage == 'OnWay' || stage == 'Arrived' || stage == 'Started' || stage == 'InProgress' || stage == 'AlmostDone';
    _arrived = stage == 'Arrived' || stage == 'Started' || stage == 'InProgress' || stage == 'AlmostDone';
    _started = stage == 'Started' || stage == 'InProgress' || stage == 'AlmostDone';
    _inProgress = stage == 'InProgress' || stage == 'AlmostDone';
    _almostDone = stage == 'AlmostDone';
    _completed = stage == 'Completed';
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted || _isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2))
    );
  }

  Future<void> _notifyClient(String title, String message) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || _actualBookingId.isEmpty) return;
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/notifications'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _data['clientId'],
          'title': title,
          'message': message,
          'type': 'tracking'
        }),
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> _updateStage(String stage) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || _actualBookingId.isEmpty) return;
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/tracking'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'bookingId': _actualBookingId, 'stage': stage}),
      );
      await _notifyClient("Service Update", "Service stage changed to $stage");
    } catch (e) {}
  }

  void _handleStage(int index) {
    setState(() {
      if (index == 0 && !_accepted) {
        _accepted = true;
        _updateStage('Accepted');
        _showSnackBar("✓ Request Accepted", Colors.green);
      }
      else if (index == 1 && _accepted && !_onWay) {
        _onWay = true;
        _updateStage('OnWay');
        _showSnackBar("✓ On the Way", Colors.green);
        _startLocationTracking();
      }
      else if (index == 2 && _onWay && !_arrived) {
        _arrived = true;
        _updateStage('Arrived');
        _showSnackBar("✓ Arrived", Colors.green);
      }
      else if (index == 3 && _arrived && !_started) {
        _started = true;
        _updateStage('Started');
        _showSnackBar("✓ Started", Colors.green);
      }
      else if (index == 4 && _started && !_inProgress) {
        _inProgress = true;
        _updateStage('InProgress');
        _showSnackBar("✓ In Progress", Colors.green);
      }
      else if (index == 5 && _inProgress && !_almostDone) {
        _almostDone = true;
        _updateStage('AlmostDone');
        _showSnackBar("✓ Almost Done", Colors.green);
      }
    });
  }

  Future<void> _completeService() async {
    setState(() { _completed = true; _isLoading = true; });
    await _updateStage('Completed');
    _locationTimer?.cancel();
    await _notifyClient("Service Completed", "The service has been marked as completed.");
    _showSnackBar("✓ Service Completed", Colors.green);
    await _fetchData();
    setState(() { _isLoading = false; });
  }

  void _checkAndShowClientRatingDialog() {
    if (!mounted || _isDisposed) return;
    final paymentStatus = _data['paymentStatus'] ?? 'Pending';
    final clientRating = _data['clientRating'];
    if (_completed && paymentStatus == 'Completed' && clientRating == null && !_ratingDialogShown) {
      _ratingDialogShown = true;
      _showRateClientDialog();
    }
  }

  void _showRateClientDialog() {
    if (!mounted || _isDisposed) return;
    int rating = 0;
    String comment = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Rate the Client"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How was your experience with this client?"),
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
            TextButton(onPressed: () {
              Navigator.pop(ctx);
              _ratingDialogShown = false;
            }, child: const Text("Skip")),
            ElevatedButton(
              onPressed: () async {
                if (rating == 0) {
                  _showSnackBar("Please select a rating", Colors.red);
                  return;
                }
                Navigator.pop(ctx);
                await _submitClientRating(rating, comment);
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitClientRating(int rating, String comment) async {
    setState(() => _isUpdating = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || _actualBookingId.isEmpty) {
      setState(() => _isUpdating = false);
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/bookings/$_actualBookingId/rate-client'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'rating': rating,
          'comment': comment,
        }),
      );
      if (response.statusCode == 200) {
        _showSnackBar("Client rated successfully", Colors.green);
        setState(() {
          _data['clientRating'] = rating;
          _data['clientFeedback'] = comment;
          _ratingDialogShown = false;
        });
      } else {
        final error = jsonDecode(response.body);
        _showSnackBar("Error: ${error['message']}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateTaskStatus(int taskIndex, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || _actualBookingId.isEmpty) return;

    setState(() => _isUpdating = true);
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/bookings/$_actualBookingId/tasks/$taskIndex'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'status': status, 'note': 'Completed by provider'}),
      );
      if (response.statusCode == 200) {
        setState(() {
          (_data['clientTasks'] as List)[taskIndex]['status'] = status;
        });
        await _notifyClient("Task Completed", "Provider completed task: ${(_data['clientTasks'] as List)[taskIndex]['taskName']}");
        _showSnackBar("Task marked as $status", Colors.green);
      } else {
        final errorBody = await response.body;
        _showSnackBar("Failed: $errorBody", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _addWorkStepWithFile(File? file, String description, String note) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || _actualBookingId.isEmpty) return;

    setState(() => _isUpdating = true);
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/provider/work-steps-with-file'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['bookingId'] = _actualBookingId;
      request.fields['description'] = description;
      request.fields['note'] = note;
      if (file != null) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final newStep = jsonDecode(responseBody);
        setState(() {
          _workSteps.insert(0, {
            'description': description,
            'note': note,
            'time': newStep['workStep']?['time'] ?? DateTime.now().toString().substring(11, 16),
            'fileUrl': newStep['workStep']?['fileUrl'],
          });
        });
        await _notifyClient("Work Progress Update", description);
        _showSnackBar("Work step added", Colors.green);
      } else {
        _showSnackBar("Failed: $responseBody", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showAddWorkStepDialog() {
    final descCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    File? selectedFile;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text("Add Work Step"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: descCtrl, decoration: const InputDecoration(hintText: "Description *")),
              const SizedBox(height: 8),
              TextField(controller: noteCtrl, decoration: const InputDecoration(hintText: "Note (optional)")),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("Attach file:"),
                  TextButton(
                    onPressed: _isPicking ? null : () async {
                      if (_isPicking) return;
                      setState(() => _isPicking = true);
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) setStateDialog(() => selectedFile = File(picked.path));
                      setState(() => _isPicking = false);
                    },
                    child: const Text("Choose"),
                  ),
                ],
              ),
              if (selectedFile != null) Text(selectedFile!.path.split('/').last),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                if (descCtrl.text.isNotEmpty) {
                  Navigator.pop(ctx);
                  _addWorkStepWithFile(selectedFile, descCtrl.text, noteCtrl.text);
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAttachment(File file, String type, String caption) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || _actualBookingId.isEmpty) return;

    setState(() => _isUpdating = true);
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/provider/attachments/upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['bookingId'] = _actualBookingId;
      request.fields['caption'] = caption;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        setState(() {
          _attachments.insert(0, {
            'type': type,
            'caption': caption,
            'time': DateTime.now().toString().substring(11, 16),
          });
        });
        await _notifyClient("New $type", caption.isEmpty ? "Provider added a $type" : caption);
        _showSnackBar("$type uploaded successfully", Colors.green);
      } else {
        _showSnackBar("Failed: $responseBody", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showAddAttachmentDialog() {
    final captionCtrl = TextEditingController();
    String type = 'image';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text("Add Attachment"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'image', child: Text("📷 Photo")),
                  DropdownMenuItem(value: 'video', child: Text("🎥 Video")),
                  DropdownMenuItem(value: 'audio', child: Text("🎤 Voice")),
                ],
                onChanged: (v) => setStateDialog(() => type = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: captionCtrl, decoration: const InputDecoration(hintText: "Caption")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: _isPicking ? null : () async {
                if (_isPicking) return;
                setState(() => _isPicking = true);
                final picker = ImagePicker();
                XFile? picked;
                if (type == 'image') picked = await picker.pickImage(source: ImageSource.gallery);
                else if (type == 'video') picked = await picker.pickVideo(source: ImageSource.gallery);
                else picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  Navigator.pop(ctx);
                  await _uploadAttachment(File(picked.path), type, captionCtrl.text);
                }
                setState(() => _isPicking = false);
              },
              child: const Text("Upload"),
            ),
          ],
        ),
      ),
    );
  }

  void _startLocationTracking() async {
    _isTrackingLocation = true;
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_completed) {
        timer.cancel();
        return;
      }
      try {
        Position pos = await Geolocator.getCurrentPosition();
        await _sendLocationToServer(pos.latitude, pos.longitude);
      } catch (e) {}
    });
  }

  Future<void> _sendLocationToServer(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || _actualBookingId.isEmpty) return;
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/provider/tracking/location'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'bookingId': _actualBookingId, 'lat': lat, 'lng': lng}),
    );
  }

  Future<void> _openFile(String url) async {
    final fullUrl = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
    final Uri uri = Uri.parse(fullUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar("Cannot open file: $e", Colors.red);
    }
  }

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text("Error: $_error")));
    }

    final clientTasks = _data['clientTasks'] as List? ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Service Tracking", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined, color: Colors.white),
            onPressed: _startChat,
          ),
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Client Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.person, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_data['client'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_data['service'] ?? 'Service', style: const TextStyle(color: AppTheme.primary)),
                      Text(_data['clientPhone'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dependant Information
          if (_dependent != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Dependant Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  _infoRow("Full Name", _dependent!['name'] ?? 'N/A'),
                  _infoRow("Relationship", _dependent!['relationship'] ?? 'N/A'),
                  _infoRow("Age", _dependent!['age']?.toString() ?? 'N/A'),
                  _infoRow("Health Notes", _dependent!['healthNotes'] ?? 'No notes'),
                  if (_dependentFiles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text("Files:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dependentFiles.map((file) => GestureDetector(
                        onTap: () => _openFile(file['url'] ?? ''),
                        child: Chip(
                          label: Text(file['filename'] ?? 'File', style: const TextStyle(fontSize: 11)),
                          avatar: const Icon(Icons.attach_file, size: 14),
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Task Files
          if (_taskFiles.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Client Attachments (from request)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action Buttons
          if (!_completed)
            Column(
              children: [
                Row(
                  children: [
                    if (!_accepted) Flexible(child: _buildActionButton("Accept", 0)),
                    if (_accepted && !_onWay) Flexible(child: _buildActionButton("On Way", 1)),
                    if (_onWay && !_arrived) Flexible(child: _buildActionButton("Arrived", 2)),
                    if (_arrived && !_started) Flexible(child: _buildActionButton("Start", 3)),
                    if (_started && !_inProgress) Flexible(child: _buildActionButton("Progress", 4)),
                    if (_inProgress && !_almostDone) Flexible(child: _buildActionButton("Almost", 5)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(child: _buildActionButton("Add Work Step", -1, isWorkStep: true)),
                    const SizedBox(width: 8),
                    Flexible(child: _buildActionButton("Add Photo", -2, isAttachment: true)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCompleteButton(),
              ],
            ),
          const SizedBox(height: 16),

          // Stages Progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Service Progress", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildProgressRow("1. Request Accepted", _accepted),
                _buildProgressRow("2. On the Way", _onWay),
                _buildProgressRow("3. Arrived", _arrived),
                _buildProgressRow("4. Started", _started),
                _buildProgressRow("5. In Progress", _inProgress),
                _buildProgressRow("6. Almost Done", _almostDone),
                _buildProgressRow("7. Completed", _completed),
              ],
            ),
          ),

          // Client Tasks
          if (clientTasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Client's Tasks", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...clientTasks.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final task = entry.value;
                    final taskName = task['taskName'] ?? 'Task';
                    final status = task['status'] ?? 'pending';
                    final isCompleted = status == 'completed';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(taskName, style: TextStyle(fontWeight: FontWeight.w500, decoration: isCompleted ? TextDecoration.lineThrough : null)),
                                if (task['providerNote'] != null)
                                  Text("Note: ${task['providerNote']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          if (!isCompleted)
                            TextButton(
                              onPressed: _isUpdating ? null : () => _updateTaskStatus(idx, 'completed'),
                              child: const Text("Mark Done"),
                            ),
                          if (isCompleted) const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

          // Work Steps
          if (_workSteps.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Work Progress", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._workSteps.map((step) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.work_outline, size: 20, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(step['description'] ?? '')),
                        if (step['time'] != null) Text(step['time']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  )),
                ],
              ),
            ),

          // Attachments
          if (_attachments.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _attachments.map((att) => GestureDetector(
                      onTap: () => _openFile(att['url'] ?? ''),
                      child: Chip(
                        label: Text(att['type'] == 'image' ? "📷 Photo" : (att['type'] == 'video' ? "🎥 Video" : "🎤 Voice")),
                        avatar: att['type'] == 'image' ? const Icon(Icons.image, size: 16) : (att['type'] == 'video' ? const Icon(Icons.videocam, size: 16) : const Icon(Icons.mic, size: 16)),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),

          // Map Placeholder
          Container(
            margin: const EdgeInsets.only(top: 16),
            height: 200,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text("📍 Location tracking active", style: TextStyle(color: Colors.grey))),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, int index, {bool isWorkStep = false, bool isAttachment = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () {
          if (isWorkStep) _showAddWorkStepDialog();
          else if (isAttachment) _showAddAttachmentDialog();
          else _handleStage(index);
        },
        style: TextButton.styleFrom(
          backgroundColor: isWorkStep ? Colors.orange : (isAttachment ? Colors.purple : AppTheme.primary),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return TextButton(
      onPressed: _completeService,
      style: TextButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text("Complete Service"),
    );
  }

  Widget _buildProgressRow(String title, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(isDone ? Icons.check_circle : Icons.circle_outlined, size: 18, color: isDone ? Colors.green : Colors.grey),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.green : null)),
        ],
      ),
    );
  }

  // ✅ دالة الدردشة المعدلة لاستخدام ChatScreen الموحد
  void _startChat() {
    if (!mounted) return;
    
    // استخراج clientId
    String clientId = '';
    dynamic clientIdField = _data['clientId'];
    
    if (clientIdField != null) {
      if (clientIdField is String) {
        clientId = clientIdField;
      } else if (clientIdField is Map) {
        clientId = clientIdField['_id']?.toString() ?? '';
      }
    }
    
    if (clientId.isEmpty && _data['client'] is Map) {
      clientId = (_data['client'] as Map)['_id']?.toString() ?? '';
    }
    
    // اسم العميل
    String clientName = _data['client']?.toString() ?? '';
    if (clientName.isEmpty && _data['client'] is Map) {
      clientName = (_data['client'] as Map)['fullName']?.toString() ?? 'Client';
    }
    
    final bookingId = _actualBookingId;
    
    if (clientId.isEmpty) {
      _showSnackBar("Cannot start chat: client ID missing.", Colors.red);
      return;
    }
    
    if (bookingId.isEmpty) {
      _showSnackBar("Cannot start chat: booking ID missing.", Colors.red);
      return;
    }
    
    // ✅ استخدام ChatScreen الموحد مع otherUserId و otherUserName
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          bookingId: bookingId,
          otherUserId: clientId,
          otherUserName: clientName.isNotEmpty ? clientName : 'Client',
          socket: _socket,
        ),
      ),
    );
  }
}