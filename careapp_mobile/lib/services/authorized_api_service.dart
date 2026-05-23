import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';

class AuthorizedApiService {
  static const String baseUrl = ApiConfig.baseUrl;

  // ==================== HELPER ====================
  // دالة آمنة لتحويل أي بيانات إلى List<Map<String, dynamic>>
  List<Map<String, dynamic>> _safeList(dynamic data) {
    if (data is List) {
      return data.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }
    return [];
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ==================== PROFILE ====================
  
  Future<Map<String, dynamic>> getProfile() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/authorized/profile'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load profile');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/authorized/profile'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to update profile');
  }

  Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    final token = await _getToken();
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/authorized/profile/picture'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath(
        'profilePicture',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    }
    throw Exception('Failed to upload profile picture');
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/authorized/change-password'),
      headers: headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to change password');
    }
  }

  // ==================== SERVICES (ACTIVE BOOKINGS) ====================
  
  Future<List<dynamic>> getAuthorizedServices() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/authorized/services'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> getTrackingInfo(String serviceId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/authorized/tracking/$serviceId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load tracking info');
  }

  Future<Map<String, dynamic>> getBookingDetails(String serviceId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/authorized/tracking/$serviceId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'id': serviceId,
        'providerId': data['providerId'] ?? '',
        'provider': data['providerName'] ?? data['provider'] ?? 'Provider',
        'providerPhone': data['providerPhone'] ?? '',
        'providerAvatar': data['providerAvatar'] ?? '',
        'service': data['serviceName'] ?? data['service'] ?? 'Service',
        'status': data['status'] ?? 'Pending',
        'location': data['location'] ?? '',
        // ✅ تصحيح: استخدام _safeList بدلاً من List.from
        'clientTasks': _safeList(data['clientTasks']),
        'remainingAmount': (data['remainingAmount'] ?? 0).toDouble(),
        'halfPaid': data['halfPaid'] ?? false,
        'trackingStage': data['stage'] ?? 'Pending',
        'stageTimes': data['stageTimes'] ?? {},
        'locationLat': data['clientLat'] ?? 36.7538,
        'locationLng': data['clientLng'] ?? 3.0588,
      };
    }
    throw Exception('Failed to load booking details');
  }

  // ==================== CHAT ====================
  
  Future<List<dynamic>> getMessages(String serviceId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/authorized/chat/$serviceId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> sendMessage(String serviceId, String message) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/authorized/chat/$serviceId'),
      headers: headers,
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to send message');
  }

  // ==================== NOTIFICATIONS ====================
  
  Future<List<dynamic>> getNotifications() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/authorized/notifications'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<void> markNotificationRead(String notificationId) async {
    final headers = await _getHeaders();
    await http.put(
      Uri.parse('$baseUrl/api/authorized/notifications/$notificationId/read'),
      headers: headers,
    );
  }

  // ==================== PROVIDER PROFILE (VIEW ONLY) ====================
  
  Future<Map<String, dynamic>> getProviderProfile(String providerId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/authorized/provider/$providerId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load provider profile');
  }
}