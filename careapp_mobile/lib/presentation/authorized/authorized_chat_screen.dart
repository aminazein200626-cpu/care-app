import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../core/app_theme.dart';
import '../../services/authorized_api_service.dart';
import '../client/call_screen.dart';  // ✅ إضافة استدعاء شاشة المكالمات

class AuthorizedChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;

  AuthorizedChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  factory AuthorizedChatMessage.fromJson(Map<String, dynamic> json, String currentUserId) {
    return AuthorizedChatMessage(
      id: json['_id'] ?? json['id'] ?? '',
      text: json['message'] ?? '',
      isMe: json['senderId'] == currentUserId,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }
}

class AuthorizedChatScreen extends StatefulWidget {
  final String serviceId;
  final String providerName;
  final String providerId;      // ✅ أضف providerId
  final String? providerAvatar;

  const AuthorizedChatScreen({
    super.key,
    required this.serviceId,
    required this.providerName,
    required this.providerId,   // ✅ مطلوب للمكالمات
    this.providerAvatar,
  });

  @override
  State<AuthorizedChatScreen> createState() => _AuthorizedChatScreenState();
}

class _AuthorizedChatScreenState extends State<AuthorizedChatScreen> {
  final AuthorizedApiService _api = AuthorizedApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  IO.Socket? _socket;
  String? _currentUserId;
  bool _isLoading = true;
  
  List<AuthorizedChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _connectSocket();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _socket?.disconnect();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId');
    });
  }

  void _connectSocket() {
    _socket = IO.io('http://10.0.2.2:5001', {
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      _joinRoom();
    });

    _socket!.on('newMessage', (data) {
      if (data['serviceId'] == widget.serviceId) {
        _addNewMessage(data, isFromMe: false);
      }
    });

    _socket!.on('disconnect', (_) {
      print('Socket disconnected');
    });
  }

  void _joinRoom() {
    if (_currentUserId != null) {
      _socket?.emit('joinAuthorized', {
        'serviceId': widget.serviceId,
        'userId': _currentUserId,
      });
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    
    try {
      final messages = await _api.getMessages(widget.serviceId);
      setState(() {
        _messages = messages.map((m) => AuthorizedChatMessage.fromJson(m, _currentUserId!)).toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final messageText = _messageController.text.trim();
    _messageController.clear();
    
    final tempMessage = AuthorizedChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: messageText,
      isMe: true,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();
    
    try {
      await _api.sendMessage(widget.serviceId, messageText);
      _socket?.emit('authorizedMessage', {
        'serviceId': widget.serviceId,
        'senderId': _currentUserId,
        'message': messageText,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.id == tempMessage.id);
      });
    }
  }

  void _addNewMessage(Map<String, dynamic> data, {required bool isFromMe}) {
    final newMessage = AuthorizedChatMessage(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: data['message'],
      isMe: isFromMe,
      timestamp: DateTime.parse(data['timestamp']),
    );
    setState(() {
      _messages.add(newMessage);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ✅ دالة بدء مكالمة صوتية
  void _startAudioCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          providerId: widget.providerId,
          providerName: widget.providerName,
          callType: 'audio',
        ),
      ),
    );
  }

  // ✅ دالة بدء مكالمة فيديو
  void _startVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          providerId: widget.providerId,
          providerName: widget.providerName,
          callType: 'video',
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, hh:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: widget.providerAvatar != null
                  ? ClipOval(
                      child: Image.network(
                        widget.providerAvatar!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 16, color: AppTheme.primary),
                      ),
                    )
                  : const Icon(Icons.person, size: 16, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Text(
              widget.providerName,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        centerTitle: false,
        elevation: 0,
        // ✅ إضافة أزرار المكالمات في الـ AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: _startAudioCall,
            tooltip: 'Audio Call',
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: _startVideoCall,
            tooltip: 'Video Call',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[_messages.length - 1 - index];
                          return _buildMessageBubble(message, isDark);
                        },
                      ),
          ),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AuthorizedChatMessage message, bool isDark) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: message.isMe ? AppTheme.primary : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: message.isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: message.isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.text, style: TextStyle(color: message.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87))),
            const SizedBox(height: 4),
            Text(_formatTime(message.timestamp), style: TextStyle(color: message.isMe ? Colors.white70 : Colors.grey[500], fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[500]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
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
              color: AppTheme.primaryContainer.withAlpha(80),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'No Messages Yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to ${widget.providerName}',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}