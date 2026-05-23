import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import '../client/chat_screen.dart';  // ✅ استيراد ChatScreen الموحد

// ==================== COMMUNICATION SCREEN (قائمة المحادثات) ====================
class CommunicationScreen extends StatefulWidget {
  const CommunicationScreen({super.key});

  @override
  State<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> {
  int _selectedTab = 0;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _calls = [];
  bool _isLoading = true;
  IO.Socket? _socket;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _connectSocket();
    _fetchConversations();
    _fetchCalls();
  }

  Future<void> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('userId');
  }

  void _connectSocket() {
    _socket = IO.io(ApiConfig.baseUrl, {
      'transports': ['websocket'],
      'autoConnect': true,
    });
    _socket!.onConnect((_) {
      print('Socket connected');
      if (_currentUserId != null) _socket!.emit('join', _currentUserId);
    });
    _socket!.on('newBookingMessage', (_) => _fetchConversations());
    _socket!.on('disconnect', (_) => print('Socket disconnected'));
  }

  Future<void> _fetchConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/bookings'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final bookingsWithMessages = data.where((b) =>
            b['status'] == 'Confirmed' ||
            b['status'] == 'In Progress' ||
            (b['messages'] != null && (b['messages'] as List).isNotEmpty)).toList();
        final convs = bookingsWithMessages.map((b) {
          final lastMessage = (b['messages'] != null && (b['messages'] as List).isNotEmpty)
              ? (b['messages'] as List).last['message']
              : 'No messages yet';
          final lastTime = (b['messages'] != null && (b['messages'] as List).isNotEmpty)
              ? DateTime.parse((b['messages'] as List).last['timestamp'])
              : DateTime.parse(b['createdAt']);
          final unreadCount = (b['messages'] != null && (b['messages'] as List).isNotEmpty)
              ? (b['messages'] as List).where((m) => m['isRead'] == false && m['senderId'] != _currentUserId).length
              : 0;
          return {
            'id': b['_id'],
            'clientId': b['clientId'],
            'clientName': b['client'] ?? b['clientId']?['fullName'] ?? 'Client',
            'service': b['service'],
            'lastMessage': lastMessage,
            'lastTime': lastTime,
            'unread': unreadCount,
            'status': b['status'],
          };
        }).toList();
        convs.sort((a, b) => b['lastTime'].compareTo(a['lastTime']));
        if (mounted) setState(() {
          _conversations = convs;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (error) {
      print('Error fetching conversations: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/calls'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) setState(() {
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
      userId: userId, userName: userName, callType: callType,
    )));
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
        title: Text("Communication", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
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
          : _selectedTab == 0 ? _buildChatsList(isDark) : _buildCallsList(isDark),
    );
  }

  Widget _tabButton(String title, int index, bool isDark) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? Colors.white : Colors.transparent, width: 2)),
        ),
        child: Text(title, style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  Widget _buildChatsList(bool isDark) {
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No conversations yet", style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text("When you accept a booking, chat will appear here.", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        return _conversationTile(conv, isDark);
      },
    );
  }

  Widget _conversationTile(Map<String, dynamic> conv, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              bookingId: conv['id'],
              otherUserId: conv['clientId']?.toString() ?? '',      // ✅ clientId هو الطرف الآخر
              otherUserName: conv['clientName'],
              socket: _socket,
            ),
          ),
        ).then((_) => _fetchConversations());
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(conv['clientName'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
                      Text(_formatTime(conv['lastTime']), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text(conv['lastMessage'], style: TextStyle(color: conv['unread'] > 0 ? Colors.black87 : Colors.grey[500], fontWeight: conv['unread'] > 0 ? FontWeight.w500 : FontWeight.normal, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (conv['unread'] > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                          child: Text("${conv['unread']}", style: const TextStyle(color: Colors.white, fontSize: 10)),
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return DateFormat('MMM d').format(time);
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
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
          CircleAvatar(radius: 28, backgroundColor: AppTheme.primary.withOpacity(0.1), child: Icon(Icons.person, color: AppTheme.primary, size: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(call['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(call['type'] == 'video' ? Icons.videocam : Icons.call, size: 12, color: call['missed'] ? Colors.red : Colors.green),
                    const SizedBox(width: 4),
                    Text(call['type'] == 'video' ? "Video call" : "Voice call", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(width: 8),
                    Text(call['duration'], style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Text(call['time'], style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _startCall(call['id'].toString(), call['name'], call['type']),
            icon: Icon(call['type'] == 'video' ? Icons.videocam : Icons.call, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

// ==================== CALL SCREEN (يمكن نقله لملف منفصل لاحقاً) ====================
class CallScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String callType;
  const CallScreen({super.key, required this.userId, required this.userName, required this.callType});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  int _callDuration = 0;
  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _callDuration++);
        _startTimer();
      }
    });
  }
  @override
  void initState() { super.initState(); _startTimer(); }
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
          Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blueGrey[900]!, Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 60, backgroundColor: Colors.white24, child: Icon(widget.callType == 'video' ? Icons.videocam : Icons.call, size: 60, color: Colors.white)),
                const SizedBox(height: 24),
                Text("Calling ${widget.userName}...", style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                Text(_formatDuration(), style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
                  _controlButton(icon: Icons.mic, color: Colors.white70),
                  _controlButton(icon: Icons.call_end, color: Colors.red, isEndCall: true, onTap: () => Navigator.pop(context)),
                  if (widget.callType == 'video') _controlButton(icon: Icons.videocam, color: Colors.white70),
                  if (widget.callType == 'audio') _controlButton(icon: Icons.volume_up, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _controlButton({required IconData icon, required Color color, bool isEndCall = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        width: isEndCall ? 70 : 55,
        height: isEndCall ? 70 : 55,
        decoration: BoxDecoration(color: isEndCall ? Colors.red : Colors.white24, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: isEndCall ? 32 : 24),
      ),
    );
  }
}