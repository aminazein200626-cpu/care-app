import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../core/app_theme.dart';
import 'call_screen.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  bool isRead;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String currentUserId) {
    return ChatMessage(
      id: json['_id'] ?? json['id'] ?? '',
      text: json['message'] ?? '',
      isMe: json['senderId'] == currentUserId,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String? providerAvatar;
  final String? bookingId;

  const ChatScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    this.providerAvatar,
    this.bookingId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  IO.Socket? _socket;
  String? _currentUserId;
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isTyping = false;
  Timer? _typingTimer;
  
  List<ChatMessage> _messages = [];
  String _conversationId = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _connectSocket();
    _loadMessages();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _socket?.disconnect();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId');
      if (_currentUserId != null) {
        _conversationId = _getConversationId(_currentUserId!, widget.providerId);
      }
    });
  }

  String _getConversationId(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return ids.join('_');
  }

  void _connectSocket() {
    _socket = IO.io('http://10.0.2.2:5001', {
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      setState(() => _isConnected = true);
      _joinRoom();
    });

    _socket!.on('newMessage', (data) {
      if (data['conversationId'] == _conversationId) {
        _addNewMessage(data, isFromMe: false);
      }
    });

    _socket!.on('messageSent', (data) {
      if (data['conversationId'] == _conversationId) {
        _addNewMessage(data, isFromMe: true);
      }
    });

    _socket!.on('typing', (data) {
      if (data['senderId'] == widget.providerId && data['isTyping'] == true) {
        setState(() => _isTyping = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isTyping = false);
        });
      }
    });

    _socket!.on('disconnect', (_) {
      setState(() => _isConnected = false);
    });
  }

  void _joinRoom() {
    if (_currentUserId != null) {
      _socket?.emit('join', _currentUserId);
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5001/api/provider/chats/messages/${widget.providerId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _messages = data.map((m) => ChatMessage.fromJson(m, _currentUserId!)).toList();
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final messageText = _messageController.text.trim();
    _messageController.clear();
    
    final tempMessage = ChatMessage(
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
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5001/api/provider/chats/messages/${widget.providerId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': messageText}),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _socket?.emit('sendMessage', {
          'conversationId': _conversationId,
          'senderId': _currentUserId,
          'receiverId': widget.providerId,
          'message': messageText,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        setState(() {
          _messages.removeWhere((m) => m.id == tempMessage.id);
        });
        throw Exception('Failed to send message');
      }
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.id == tempMessage.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _addNewMessage(Map<String, dynamic> data, {required bool isFromMe}) {
    final newMessage = ChatMessage(
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

  void _sendTypingIndicator() {
    if (_typingTimer != null && _typingTimer!.isActive) return;
    
    _socket?.emit('typing', {
      'conversationId': _conversationId,
      'senderId': _currentUserId,
      'receiverId': widget.providerId,
      'isTyping': true,
    });
    
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _socket?.emit('typing', {
        'conversationId': _conversationId,
        'senderId': _currentUserId,
        'receiverId': widget.providerId,
        'isTyping': false,
      });
      _typingTimer = null;
    });
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

  void _deleteMessage(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Message',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete this message?',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _messages.removeAt(index));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, hh:mm a').format(time);
  }

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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: widget.providerAvatar != null
                  ? ClipOval(
                      child: Image.network(
                        widget.providerAvatar!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 18, color: AppTheme.primary),
                      ),
                    )
                  : const Icon(Icons.person, size: 18, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.providerName,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
                if (_isTyping)
                  Text(
                    'Typing...',
                    style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500),
                  )
                else if (_isConnected)
                  Text(
                    'Online',
                    style: TextStyle(fontSize: 11, color: Colors.green[400]),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: _startAudioCall,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: _startVideoCall,
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
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return GestureDetector(
                            onLongPress: () => _deleteMessage(index),
                            child: _buildMessageBubble(message, isDark),
                          );
                        },
                      ),
          ),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: message.isMe
              ? AppTheme.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
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
            Text(
              message.text,
              style: TextStyle(
                color: message.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: message.isMe ? Colors.white70 : Colors.grey[500],
                fontSize: 10,
              ),
            ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: AppTheme.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File attachment coming soon')),
              );
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: (_) => _sendTypingIndicator(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
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
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}