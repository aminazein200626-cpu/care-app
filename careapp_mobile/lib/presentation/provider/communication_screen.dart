import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/app_theme.dart';


class CommunicationScreen extends StatefulWidget {
  const CommunicationScreen({super.key});

  @override
  State<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> {
  int _selectedIndex = 0;

  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _calls = [];
  bool _isLoading = true;
  IO.Socket? _socket;
  String? _currentUserId;

  final String baseUrl = 'http://10.0.2.2:5001';

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _connectSocket();
    _fetchChats();
    _fetchCalls();
  }

  Future<void> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('userId');
  }

  void _connectSocket() {
    _socket = IO.io(baseUrl, {
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      print('Socket connected');
      if (_currentUserId != null) {
        _socket!.emit('join', _currentUserId);
      }
    });

    _socket!.on('newMessage', (data) {
      _refreshChats();
    });

    _socket!.on('disconnect', (_) {
      print('Socket disconnected');
    });
  }

  Future<void> _refreshChats() async {
    await _fetchChats();
    if (mounted) setState(() {});
  }

  Future<void> _fetchChats() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/chats/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _chats = data.map((item) => ({
            'id': item['id'],
            'name': item['name'],
            'image': item['image'],
            'lastMessage': item['lastMessage'],
            'time': item['time'],
            'unread': item['unread'] ?? 0,
            'online': item['online'] ?? false,
            'typing': item['typing'] ?? false,
          })).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/calls'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _calls = data.map((item) => ({
            'id': item['id'],
            'name': item['name'],
            'image': item['image'],
            'type': item['type'],
            'duration': item['duration'],
            'time': item['time'],
            'missed': item['missed'] ?? false,
          })).toList();
        });
      }
    } catch (error) {
      print('Error: $error');
    }
  }

  void _startCall(String userId, String userName, String callType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          userId: userId,
          userName: userName,
          callType: callType,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Communication",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _tabButton("Chats", 0, isDark),
                const SizedBox(width: 20),
                _tabButton("Calls", 1, isDark),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedIndex == 0 
              ? _buildChatsList(isDark) 
              : _buildCallsList(isDark),
    );
  }

  Widget _tabButton(String title, int index, bool isDark) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildChatsList(bool isDark) {
    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No conversations yet", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return _chatTile(chat, isDark);
      },
    );
  }

  Widget _chatTile(Map<String, dynamic> chat, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              userId: chat['id'].toString(),
              name: chat['name'],
              image: chat['image'],
              socket: _socket,
              currentUserId: _currentUserId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Icon(Icons.person, color: AppTheme.primary, size: 28),
                ),
                if (chat['online'])
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        chat['time'],
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (chat['typing'])
                        const Text(
                          "Typing...",
                          style: TextStyle(color: AppTheme.primary, fontSize: 12),
                        )
                      else
                        Expanded(
                          child: Text(
                            chat['lastMessage'],
                            style: TextStyle(
                              color: chat['unread'] > 0 ? Colors.black87 : Colors.grey[500],
                              fontWeight: chat['unread'] > 0 ? FontWeight.w500 : FontWeight.normal,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (chat['unread'] > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "${chat['unread']}",
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallsList(bool isDark) {
    if (_calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_disabled, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No call history", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _calls.length,
      itemBuilder: (context, index) {
        final call = _calls[index];
        return _callTile(call, isDark);
      },
    );
  }

  Widget _callTile(Map<String, dynamic> call, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            child: Icon(Icons.person, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      call['type'] == 'video' ? Icons.videocam : Icons.call,
                      size: 12,
                      color: call['missed'] ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      call['type'] == 'video' ? "Video call" : "Voice call",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      call['duration'],
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            call['time'],
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _startCall(call['id'].toString(), call['name'], call['type']),
            icon: Icon(
              call['type'] == 'video' ? Icons.videocam : Icons.call,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== CHAT SCREEN ====================
class ChatScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String? image;
  final IO.Socket? socket;
  final String? currentUserId;
  const ChatScreen({
    super.key,
    required this.userId,
    required this.name,
    this.image,
    this.socket,
    this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  final TextEditingController _controller = TextEditingController();
  final String baseUrl = 'http://10.0.2.2:5001';

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _listenForNewMessages();
  }

  void _listenForNewMessages() {
    widget.socket?.on('newMessage', (data) {
      if (data['senderId'] == widget.userId || data['receiverId'] == widget.userId) {
        _fetchMessages();
      }
    });
  }

  Future<void> _fetchMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/chats/messages/${widget.userId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _messages = data.map((item) => ({
            'text': item['message'],
            'isMe': item['senderId'] == widget.currentUserId,
            'time': _formatTime(DateTime.parse(item['timestamp'])),
          })).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    String text = _controller.text;
    String timestamp = DateTime.now().toIso8601String();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/provider/chats/messages/${widget.userId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': text}),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.socket?.emit('sendMessage', {
          'conversationId': _getConversationId(widget.currentUserId, widget.userId),
          'senderId': widget.currentUserId,
          'receiverId': widget.userId,
          'message': text,
          'timestamp': timestamp,
        });
        
        setState(() {
          _messages.add({
            'text': text,
            'isMe': true,
            'time': _formatTime(DateTime.now()),
          });
        });
        _controller.clear();
      }
    } catch (error) {
      print('Error: $error');
    }
  }

  String _getConversationId(String? user1, String user2) {
    List<String> ids = [user1 ?? '', user2];
    ids.sort();
    return ids.join('_');
  }

  String _formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  void _deleteMessage(int index) {
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
              setState(() => _messages.removeAt(index));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
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
              child: Icon(Icons.person, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 8),
            Text(widget.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: AppTheme.primary,
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              _showCallScreen('audio');
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              _showCallScreen('video');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
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

  void _showCallScreen(String callType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          userId: widget.userId,
          userName: widget.name,
          callType: callType,
        ),
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
          color: msg['isMe']
              ? AppTheme.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
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
            Text(
              msg['text'],
              style: TextStyle(
                color: msg['isMe'] ? Colors.white : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg['time'],
              style: TextStyle(
                color: msg['isMe'] ? Colors.white70 : Colors.grey[500],
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
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: AppTheme.primary),
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.grey[500]),
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
}

// ==================== CALL SCREEN ====================
class CallScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String callType;
  
  const CallScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.callType,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _callDuration++);
        _startTimer();
      }
    });
  }

  String _formatDuration() {
    int minutes = _callDuration ~/ 60;
    int seconds = _callDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey[900]!, Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    widget.callType == 'video' ? Icons.videocam : Icons.call,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Calling ${widget.userName}...",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(
                    icon: Icons.mic,
                    color: Colors.white70,
                  ),
                  _controlButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    isEndCall: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  if (widget.callType == 'video')
                    _controlButton(
                      icon: Icons.videocam,
                      color: Colors.white70,
                    ),
                  if (widget.callType == 'audio')
                    _controlButton(
                      icon: Icons.volume_up,
                      color: Colors.white70,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    bool isEndCall = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        width: isEndCall ? 70 : 55,
        height: isEndCall ? 70 : 55,
        decoration: BoxDecoration(
          color: isEndCall ? Colors.red : Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: isEndCall ? 32 : 24),
      ),
    );
  }
}