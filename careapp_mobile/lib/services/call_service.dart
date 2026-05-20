import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  static const String appId = "9e5de0af2d744b8a80384ee80a0c6d76";
  
  RtcEngine? _engine;
  int? _remoteUid;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeaker = true;
  bool _isVideoOff = false;
  int _callDuration = 0;
  Timer? _timer;
  
  bool get isJoined => _isJoined;
  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;
  bool get isVideoOff => _isVideoOff;
  int get callDuration => _callDuration;
  int? get remoteUid => _remoteUid;
  
  final StreamController<int?> _remoteUidController = StreamController<int?>.broadcast();
  final StreamController<int> _durationController = StreamController<int>.broadcast();
  final StreamController<bool> _mutedController = StreamController<bool>.broadcast();
  final StreamController<bool> _speakerController = StreamController<bool>.broadcast();
  final StreamController<bool> _videoOffController = StreamController<bool>.broadcast();
  
  Stream<int?> get onRemoteUidChanged => _remoteUidController.stream;
  Stream<int> get onDurationChanged => _durationController.stream;
  Stream<bool> get onMutedChanged => _mutedController.stream;
  Stream<bool> get onSpeakerChanged => _speakerController.stream;
  Stream<bool> get onVideoOffChanged => _videoOffController.stream;
  
  Future<void> initialize(String callType) async {
    await [Permission.microphone, Permission.camera].request();
    
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        _isJoined = true;
        _startTimer();
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        _remoteUid = remoteUid;
        _remoteUidController.add(_remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        _remoteUid = null;
        _remoteUidController.add(null);
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint("Agora Error: $err - $msg");
      },
    ));
    
    if (callType == 'video') {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.enableAudio();
    }
    
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
  }
  
  Future<void> joinChannel(String channelName, String token, int uid) async {
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
  }
  
  Future<void> leaveChannel() async {
    _timer?.cancel();
    await _engine?.leaveChannel();
  }
  
  Future<void> release() async {
    await _engine?.release();
    _engine = null;
  }
  
  void toggleMute() {
    _isMuted = !_isMuted;
    _engine?.muteLocalAudioStream(_isMuted);
    _mutedController.add(_isMuted);
  }
  
  void toggleSpeaker() {
    _isSpeaker = !_isSpeaker;
    _engine?.setEnableSpeakerphone(_isSpeaker);
    _speakerController.add(_isSpeaker);
  }
  
  void toggleVideo() {
    _isVideoOff = !_isVideoOff;
    _engine?.muteLocalVideoStream(_isVideoOff);
    _videoOffController.add(_isVideoOff);
  }
  
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration++;
      _durationController.add(_callDuration);
    });
  }
  
  Widget buildLocalVideoView() {
    if (_engine == null) return Container(color: Colors.black);
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }
  
  Widget buildRemoteVideoView() {
    if (_engine == null || _remoteUid == null) {
      return Container(color: Colors.blueGrey[900]);
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: _remoteUid),
        connection: RtcConnection(channelId: ""),
      ),
    );
  }
  
  void dispose() {
    _timer?.cancel();
    _remoteUidController.close();
    _durationController.close();
    _mutedController.close();
    _speakerController.close();
    _videoOffController.close();
  }
}