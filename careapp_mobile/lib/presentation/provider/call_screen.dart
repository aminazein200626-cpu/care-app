import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';


class CallScreen extends StatefulWidget {
  final String channelName;
  final String userName;
  final String callType;

  const CallScreen({
    super.key,
    required this.channelName,
    required this.userName,
    required this.callType,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final String _appId = "9e5de0af2d744b8a80384ee80a0c6d76";
  int? _remoteUid;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeaker = true;
  bool _isVideoOff = false;
  int _callDuration = 0;
  Timer? _timer;
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: _appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        if (mounted) {
          setState(() => _isJoined = true);
          _startTimer();
        }
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        if (mounted) setState(() => _remoteUid = remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        if (mounted) setState(() => _remoteUid = null);
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint("Agora Error: $err - $msg");
      },
    ));

    if (widget.callType == 'video') {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.enableAudio();
    }

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    await _engine.joinChannel(
      token: '', 
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  String _formatDuration() {
    int minutes = _callDuration ~/ 60;
    int seconds = _callDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _endCall() async {
    _timer?.cancel();
    await _engine.leaveChannel();
    await _engine.release();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_isJoined) {
       _engine.leaveChannel();
    }
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_isJoined 
          ? _buildConnectingUI()
          : Stack(
              children: [
                _remoteVideoView(),
                if (widget.callType == 'video' && !_isVideoOff) _localVideoView(),
                _buildOverlayUI(),
                _buildBottomControls(),
              ],
            ),
    );
  }

  Widget _buildConnectingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blueAccent),
          const SizedBox(height: 20),
          Text(
            "Connecting to ${widget.userName}...",
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _remoteVideoView() {
    if (widget.callType == 'video' && _remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }
    return Container(
      color: Colors.blueGrey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 60, child: Icon(Icons.person, size: 60)),
            const SizedBox(height: 20),
            Text(
              _remoteUid != null ? "Connected" : "Waiting for ${widget.userName}...",
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _localVideoView() {
    return Positioned(
      top: 50,
      right: 16,
      child: SizedBox(
        width: 110,
        height: 160,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayUI() {
    return Positioned(
      top: 80,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.userName,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _formatDuration(),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _circleActionBtn(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            color: _isMuted ? Colors.red : Colors.white24,
            onTap: () {
              _engine.muteLocalAudioStream(!_isMuted);
              setState(() => _isMuted = !_isMuted);
            },
          ),
          _circleActionBtn(
            icon: Icons.call_end,
            color: Colors.red,
            isBig: true,
            onTap: _endCall,
          ),
          if (widget.callType == 'video')
            _circleActionBtn(
              icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
              color: _isVideoOff ? Colors.red : Colors.white24,
              onTap: () {
                _engine.muteLocalVideoStream(!_isVideoOff);
                setState(() => _isVideoOff = !_isVideoOff);
              },
            )
          else
            _circleActionBtn(
              icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
              color: Colors.white24,
              onTap: () {
                _engine.setEnableSpeakerphone(!_isSpeaker);
                setState(() => _isSpeaker = !_isSpeaker);
              },
            ),
        ],
      ),
    );
  }

  Widget _circleActionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isBig = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isBig ? 20 : 15),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: isBig ? 32 : 24),
      ),
    );
  }
}