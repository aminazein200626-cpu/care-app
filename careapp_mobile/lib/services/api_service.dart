import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Map<String, String> _getHeaders({bool hasToken = true}) {
    return {
      'Content-Type': 'application/json',
      if (hasToken) 'Authorization': 'Bearer ${_getToken()}',
    };
  }

  // ==================== البحث عن المزودين ====================
  Future<dynamic> searchProviders({
    String? wilaya,
    String? municipality,
    String? serviceId,
    double? rating,
    double? hourlyRate,
    String sortBy = 'rating',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final params = {
        if (wilaya != null) 'wilaya': wilaya,
        if (municipality != null) 'municipality': municipality,
        if (serviceId != null) 'serviceId': serviceId,
        if (rating != null) 'rating': rating.toString(),
        if (hourlyRate != null) 'hourlyRate': hourlyRate.toString(),
        'sortBy': sortBy,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/search/providers').replace(queryParameters: params);
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to search providers: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== البحث عن الخدمات ====================
  Future<dynamic> searchServices({
    String? search,
    String? categoryId,
    String sortBy = 'newest',
  }) async {
    try {
      final params = {
        if (search != null) 'search': search,
        if (categoryId != null) 'categoryId': categoryId,
        'sortBy': sortBy,
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/search/services').replace(queryParameters: params);
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to search services: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== تفاصيل المزود ====================
  Future<dynamic> getProviderDetails(String providerId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/search/providers/$providerId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get provider details');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== التوفرية ====================
  Future<dynamic> getProviderAvailability(String providerId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/search/providers/$providerId/availability'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get availability');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== إنشاء حجز ====================
  Future<dynamic> createBooking({
    required String providerId,
    required String serviceId,
    required String date,
    required String startTime,
    required String endTime,
    String? dependentId,
    String? notes,
    String? location,
    List<Map<String, dynamic>>? clientTasks,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        'providerId': providerId,
        'serviceId': serviceId,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        if (dependentId != null) 'dependentId': dependentId,
        if (notes != null) 'notes': notes,
        if (location != null) 'location': location,
        if (clientTasks != null) 'clientTasks': clientTasks,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create booking');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== الحصول على الحجوزات ====================
  Future<dynamic> getBookings({String? status, String role = 'client'}) async {
    try {
      final token = await _getToken();
      final params = {
        if (status != null) 'status': status,
        'role': role,
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/bookings').replace(queryParameters: params);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get bookings');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== تفاصيل الحجز ====================
  Future<dynamic> getBookingDetails(String bookingId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings/$bookingId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get booking details');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== قبول/رفض الحجز ====================
  Future<dynamic> respondToBooking({
    required String bookingId,
    required String action,
    String? reason,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        'action': action,
        if (reason != null) 'reason': reason,
      };

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings/$bookingId/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to respond to booking');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== تحديث المهام ====================
  Future<dynamic> updateBookingTasks({
    required String bookingId,
    required List<Map<String, dynamic>> clientTasks,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        'clientTasks': clientTasks,
      };

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings/$bookingId/tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update tasks');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== تحديث التقدم ====================
  Future<dynamic> updateBookingProgress({
    required String bookingId,
    required String trackingStage,
    List<Map<String, dynamic>>? workSteps,
    Map<String, dynamic>? location,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        'trackingStage': trackingStage,
        if (workSteps != null) 'workSteps': workSteps,
        if (location != null) 'location': location,
      };

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings/$bookingId/progress'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update progress');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== تقييم الخدمة ====================
  Future<dynamic> rateBooking({
    required String bookingId,
    required double rating,
    String? feedback,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        'rating': rating,
        if (feedback != null) 'feedback': feedback,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/bookings/$bookingId/rate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to rate booking');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== الإشعارات ====================
  Future<dynamic> getNotifications({
    bool unread = false,
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final token = await _getToken();
      final params = {
        'unread': unread.toString(),
        'limit': limit.toString(),
        'page': page.toString(),
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/notifications').replace(queryParameters: params);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get notifications');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> markNotificationAsRead(String notificationId) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== توفرية المزود ====================
  Future<dynamic> updateProviderAvailability(
    Map<String, List<Map<String, dynamic>>> dateSlots,
  ) async {
    try {
      final token = await _getToken();
      final body = {
        'dateSlots': dateSlots,
      };

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/provider/availability'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update availability');
      }
    } catch (e) {
      rethrow;
    }
  }
}
