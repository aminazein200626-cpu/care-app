import 'dart:async'; // ✅ مهم جداً - يجب إضافته لاستخدام Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String? providerAvatar;
  final String callType; // 'audio' أو 'video'

  const CallScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    this.providerAvatar,
    required this.callType,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late CallService _callService;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isSpeaker = true;
  bool _isVideoOff = false;
  int _callDuration = 0;
  Timer? _timer; // ✅ الآن يعمل بشكل صحيح

  @override
  void initState() {
    super.initState();
    _callService = CallService();
    _initCall();
    
    // قفل اتجاه الشاشة
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _initCall() async {
    try {
      await _callService.initialize(widget.callType);
      
      final String channelName = "call_${widget.providerId}_${DateTime.now().millisecondsSinceEpoch}";
      const String token = "";
      const int uid = 0;

      await _callService.joinChannel(channelName, token, uid);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _startTimer();
      }
    } catch (e) {
      print("Error initializing call: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to initialize call")),
        );
        _endCall();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  String _formatDuration() {
    int minutes = _callDuration ~/ 60;
    int seconds = _callDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _toggleMute() {
    _callService.toggleMute();
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleSpeaker() {
    _callService.toggleSpeaker();
    setState(() {
      _isSpeaker = !_isSpeaker;
    });
  }

  void _toggleVideo() {
    _callService.toggleVideo();
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
  }

  void _endCall() {
    _timer?.cancel();
    _callService.leaveChannel();
    _callService.release();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callService.leaveChannel();
    _callService.release();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "${widget.callType == 'video' ? 'Video' : 'Audio'} Call with ${widget.providerName}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _endCall,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red),
            onPressed: _endCall,
          ),
        ],
      ),
      body: _isInitialized
          ? (widget.callType == 'video'
              ? _buildVideoCall()
              : _buildAudioCall())
          : _buildConnectingUI(),
      floatingActionButton: _isInitialized ? _buildControls() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildConnectingUI() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 20),
          Text(
            "Connecting...",
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCall() {
    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: _callService.buildRemoteVideoView(),
        ),
        Positioned(
          top: 60,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDuration(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
        Positioned(
          top: 60,
          right: 16,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 100,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _callService.buildLocalVideoView(),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.providerName,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioCall() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.05),
            duration: const Duration(milliseconds: 1000),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blueGrey[800]!, Colors.blueGrey[600]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipOval(
                child: widget.providerAvatar != null && widget.providerAvatar!.isNotEmpty
                    ? Image.network(
                        widget.providerAvatar!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person, size: 60, color: Colors.white);
                        },
                      )
                    : const Icon(Icons.person, size: 60, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            widget.providerName,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDuration(),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isMuted ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isMuted ? "Muted" : "Connected",
              style: TextStyle(
                color: _isMuted ? Colors.red : Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FloatingActionButton(
          heroTag: "mute",
          onPressed: _toggleMute,
          backgroundColor: _isMuted ? Colors.red : Colors.grey[800],
          child: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
        ),
        const SizedBox(width: 20),
        FloatingActionButton(
          heroTag: "end",
          onPressed: _endCall,
          backgroundColor: Colors.red,
          child: const Icon(Icons.call_end, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 20),
        if (widget.callType == 'audio')
          FloatingActionButton(
            heroTag: "speaker",
            onPressed: _toggleSpeaker,
            backgroundColor: _isSpeaker ? Colors.blue : Colors.grey[800],
            child: Icon(_isSpeaker ? Icons.volume_up : Icons.volume_off, color: Colors.white),
          ),
        if (widget.callType == 'video')
          FloatingActionButton(
            heroTag: "video",
            onPressed: _toggleVideo,
            backgroundColor: _isVideoOff ? Colors.orange : Colors.grey[800],
            child: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam, color: Colors.white),
          ),
      ],
    );
  }
}