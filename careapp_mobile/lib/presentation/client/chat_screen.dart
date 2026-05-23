import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String otherUserId;
  final String otherUserName;
  final IO.Socket? socket;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.otherUserId,
    required this.otherUserName,
    this.socket,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  String? _currentUserRole;
  bool _socketListenerSet = false;
  Timer? _pollingTimer;
  
  // ✅ تخزين معرفات الرسائل + بصمة نصية لمنع التكرار
  final Set<String> _messageKeys = {};

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadMessages();
    _setupSocketListener();
    _startPollingIfNeeded();
  }

  Future<void> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString('userId');
        _currentUserRole = prefs.getString('role');
      });
    }
    _joinBookingRoom();
  }

  void _joinBookingRoom() {
    if (widget.socket != null && widget.socket!.connected && _currentUserId != null) {
      widget.socket!.emit('joinBookingRoom', widget.bookingId);
    }
  }

  void _setupSocketListener() {
    if (_socketListenerSet) return;
    _socketListenerSet = true;

    widget.socket?.off('newBookingMessage');
    widget.socket?.on('newBookingMessage', (data) {
      if (!mounted) return;
      if (data['bookingId'] == widget.bookingId) {
        final msg = data['message'];
        final isMe = msg['senderId'] == _currentUserId;
        _addMessageIfNew(
          id: msg['_id']?.toString(),
          text: msg['message'],
          isMe: isMe,
          timestamp: DateTime.parse(msg['timestamp']),
          senderName: msg['senderName'],
        );
      }
    });

    widget.socket?.off('connect');
    widget.socket?.on('connect', (_) {
      _joinBookingRoom();
      // ✅ بمجرد اتصال Socket، نلغي Polling
      _pollingTimer?.cancel();
      _pollingTimer = null;
    });
  }

  // ✅ دالة قوية لمنع التكرار
  void _addMessageIfNew({
    required String? id,
    required String text,
    required bool isMe,
    required DateTime timestamp,
    required String senderName,
  }) {
    if (!mounted) return;

    // إنشاء مفتاح فريد للرسالة
    final uniqueKey = id ?? '${timestamp.millisecondsSinceEpoch}_$text';
    if (_messageKeys.contains(uniqueKey)) return;

    _messageKeys.add(uniqueKey);
    setState(() {
      _messages.add({
        'key': uniqueKey,
        'text': text,
        'isMe': isMe,
        'timestamp': timestamp,
        'senderName': senderName,
      });
    });
    _scrollToBottom();
  }

  String _getMessagesEndpoint() {
    if (_currentUserRole == 'Client') {
      return '/api/client/bookings/${widget.bookingId}/messages';
    } else if (_currentUserRole == 'Provider') {
      return '/api/provider/bookings/${widget.bookingId}/messages';
    } else {
      return '/api/client/bookings/${widget.bookingId}/messages';
    }
  }

  bool _isLoadingMessages = false;
  Future<void> _loadMessages() async {
    if (_isLoadingMessages) return;
    _isLoadingMessages = true;
    if (mounted) setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      _isLoadingMessages = false;
      return;
    }

    final endpoint = _getMessagesEndpoint();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          int addedCount = 0;
          for (var item in data) {
            final id = item['_id']?.toString();
            final text = item['message'];
            final isMe = item['senderId'] == _currentUserId;
            final timestamp = DateTime.parse(item['timestamp']);
            final senderName = item['senderName'];
            final uniqueKey = id ?? '${timestamp.millisecondsSinceEpoch}_$text';
            if (!_messageKeys.contains(uniqueKey)) {
              _messageKeys.add(uniqueKey);
              _messages.add({
                'key': uniqueKey,
                'text': text,
                'isMe': isMe,
                'timestamp': timestamp,
                'senderName': senderName,
              });
              addedCount++;
            }
          }
          if (addedCount > 0) {
            _messages.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
            _scrollToBottom();
          }
          setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (error) {
      print('Error loading messages: $error');
      if (mounted) setState(() => _isLoading = false);
    }
    _isLoadingMessages = false;
  }

  void _startPollingIfNeeded() {
    // ✅ نبدأ Polling فقط إذا لم يكن هناك Socket (أو كان Socket معطلاً)
    _pollingTimer?.cancel();
    if (widget.socket == null) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _loadMessages();
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isSending) return;
    final text = _controller.text.trim();
    _controller.clear();
    setState(() => _isSending = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) setState(() => _isSending = false);
      _showSnackBar('Not authenticated', Colors.red);
      return;
    }

    final endpoint = _getMessagesEndpoint();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'message': text}),
      );
      if (response.statusCode == 201) {
        final newMessage = jsonDecode(response.body);
        final msgData = newMessage['data'] ?? newMessage;
        final id = msgData['_id']?.toString();
        
        // ✅ إرسال عبر Socket إذا كان متاحاً
        widget.socket?.emit('sendBookingMessage', {
          'bookingId': widget.bookingId,
          'message': text,
        });
        
        // ✅ إضافة محلية فقط إذا لم يكن هناك Socket (أو Socket غير متصل)
        // لتجنب التكرار، ننتظر وصول الرسالة عبر Socket أو Polling.
        if (widget.socket == null || !widget.socket!.connected) {
          _addMessageIfNew(
            id: id,
            text: text,
            isMe: true,
            timestamp: DateTime.now(),
            senderName: 'Me',
          );
        }
      } else {
        print('❌ Failed to send message: ${response.statusCode} - ${response.body}');
        _showSnackBar('Failed to send message (${response.statusCode})', Colors.red);
      }
    } catch (error) {
      print('Error sending message: $error');
      _showSnackBar('Error: $error', Colors.red);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
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
    final key = _messages[index]['key'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Message"),
        content: const Text("Are you sure you want to delete this message?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _messages.removeAt(index);
                _messageKeys.remove(key);
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    widget.socket?.off('newBookingMessage');
    widget.socket?.off('connect');
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: const Icon(Icons.person, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              widget.otherUserName,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      return GestureDetector(
                        onLongPress: () => _deleteMessage(_messages.length - 1 - index),
                        child: _messageBubble(msg, isDark),
                      );
                    },
                  ),
                ),
                _buildInputBar(isDark),
              ],
            ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> msg, bool isDark) {
    return Align(
      alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg['isMe'] ? AppTheme.primary : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: msg['isMe'] ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: msg['isMe'] ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(msg['text'], style: TextStyle(color: msg['isMe'] ? Colors.white : (isDark ? Colors.white : Colors.black87))),
            const SizedBox(height: 4),
            Text(_formatTime(msg['timestamp']), style: TextStyle(color: msg['isMe'] ? Colors.white70 : Colors.grey[500], fontSize: 10)),
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
          IconButton(icon: Icon(Icons.attach_file, color: AppTheme.primary), onPressed: () {}),
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.grey[500]),
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
              child: _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}