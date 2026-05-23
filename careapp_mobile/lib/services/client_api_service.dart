import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

class ClientApiService {
  // ==================== دالة آمنة لتحويل أي بيانات إلى List<Map<String, dynamic>> ====================
  List<Map<String, dynamic>> _safeList(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found. Please login again.');
    }
    return token;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<http.Response> _get(String endpoint) async {
    final headers = await _getHeaders();
    return await http.get(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
    );
  }

  Future<http.Response> _post(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    return await http.post(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(data),
    );
  }

  Future<http.Response> _put(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    return await http.put(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(data),
    );
  }

  Future<http.Response> _delete(String endpoint) async {
    final headers = await _getHeaders();
    return await http.delete(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
    );
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final response = await _put('/api/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to change password');
    }
  }

  Future<Map<String, dynamic>> updateProfilePicture(File imageFile) async {
    final token = await _getToken();
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/client/profile/picture'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('profilePicture', imageFile.path));
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    }
    throw Exception('Failed to upload profile picture');
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await _get('/api/client/stats');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'activeBookings': 0, 'completedServices': 0, 'totalSpent': 0, 'savedProviders': 0};
    } catch (e) {
      return {'activeBookings': 0, 'completedServices': 0, 'totalSpent': 0, 'savedProviders': 0};
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _get('/api/client/profile');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load profile');
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response = await _get('/api/client/profile/$userId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load user profile');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _put('/api/client/profile', data);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to update profile');
  }

  // ==================== DEPENDENTS ====================
  Future<List<dynamic>> getDependents() async {
    final response = await _get('/api/client/dependents');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> addDependent(Map<String, dynamic> data, {List<File>? files}) async {
    final token = await _getToken();
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/client/dependents'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    
    request.fields['fullName'] = data['fullName'];
    request.fields['relationship'] = data['relationship'];
    request.fields['dateOfBirth'] = data['dateOfBirth'];
    request.fields['nationalId'] = data['nationalId'] ?? '';
    request.fields['healthNotes'] = data['healthNotes'] ?? '';
    
    if (files != null) {
      for (var file in files) {
        request.files.add(await http.MultipartFile.fromPath('files', file.path));
      }
    }
    
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode == 201) {
      return jsonDecode(responseBody);
    }
    throw Exception('Failed to add dependent: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> updateDependent(String id, Map<String, dynamic> data, {List<File>? files}) async {
    final token = await _getToken();
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}/api/client/dependents/$id'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    
    request.fields['fullName'] = data['fullName'];
    request.fields['relationship'] = data['relationship'];
    request.fields['dateOfBirth'] = data['dateOfBirth'];
    request.fields['nationalId'] = data['nationalId'] ?? '';
    request.fields['healthNotes'] = data['healthNotes'] ?? '';
    
    if (files != null) {
      for (var file in files) {
        request.files.add(await http.MultipartFile.fromPath('files', file.path));
      }
    }
    
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    }
    throw Exception('Failed to update dependent');
  }

  Future<void> deleteDependent(String id) async {
    final response = await _delete('/api/client/dependents/$id');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete dependent');
    }
  }

  Future<List<dynamic>> getAuthorizedPersons() async {
    final response = await _get('/api/client/authorized');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> addAuthorizedPerson(Map<String, dynamic> data) async {
    final response = await _post('/api/client/authorized', data);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to add authorized person');
  }

  Future<void> deleteAuthorizedPerson(String id) async {
    final response = await _delete('/api/client/authorized/$id');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete authorized person');
    }
  }

  // ==================== CATEGORIES, SERVICES, WILAYAS ====================
  Future<List<dynamic>> getCategories() async {
    final response = await _get('/api/public/categories');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<List<dynamic>> getServices() async {
    final response = await _get('/api/public/services');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<List<String>> getUniqueWilayas() async {
    final response = await _get('/api/search/wilayas');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<String>();
    }
    return [];
  }

  // ==================== SEARCH PROVIDERS ====================
  Future<List<dynamic>> searchProviders({
    String? wilaya,
    String? categoryId,
    String? serviceId,
    double? rating,
    double? hourlyRate,
    String sortBy = 'rating',
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{};
    if (wilaya != null && wilaya != 'All') queryParams['wilaya'] = wilaya;
    if (categoryId != null && categoryId != 'All') queryParams['categoryId'] = categoryId;
    if (serviceId != null && serviceId != 'All') queryParams['serviceId'] = serviceId;
    if (rating != null) queryParams['rating'] = rating.toString();
    if (hourlyRate != null) queryParams['hourlyRate'] = hourlyRate.toString();
    queryParams['sortBy'] = sortBy;
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/search/providers').replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? [];
    }
    return [];
  }

  Future<Map<String, dynamic>> getProviderDetails(String providerId) async {
    final response = await _get('/api/client/providers/$providerId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load provider details');
  }

  Future<List<dynamic>> getBookings({String? status}) async {
    String url = '/api/client/bookings';
    if (status != null && status != 'All') {
      url = '$url?status=$status';
    }
    final response = await _get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    final response = await _post('/api/client/bookings', data);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create booking');
  }

  Future<void> cancelBooking(String id) async {
    final response = await _put('/api/client/bookings/$id/cancel', {});
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel booking');
    }
  }

  // ✅ دالة getBookingDetails مصححة بالكامل (تتعامل مع String و Map)
  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    final response = await _get('/api/client/bookings/$bookingId');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      String _getString(dynamic value, {String defaultValue = ''}) {
        if (value == null) return defaultValue;
        if (value is String) return value;
        if (value is Map) {
          if (value.containsKey('_id')) return value['_id'].toString();
          if (value.containsKey('fullName')) return value['fullName'].toString();
          if (value.containsKey('name')) return value['name'].toString();
          return defaultValue;
        }
        return value.toString();
      }

      String _getId(dynamic value) {
        if (value == null) return '';
        if (value is String) return value;
        if (value is Map) return value['_id']?.toString() ?? '';
        return value.toString();
      }

      double _getDouble(dynamic value, {double defaultValue = 0.0}) {
        if (value == null) return defaultValue;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? defaultValue;
        return defaultValue;
      }

      bool _getBool(dynamic value, {bool defaultValue = false}) {
        if (value == null) return defaultValue;
        if (value is bool) return value;
        if (value is String) return value.toLowerCase() == 'true';
        return defaultValue;
      }

      return {
        'id': _getId(data['id'] ?? data['_id']),
        'provider': _getString(data['provider'] ?? data['providerId']),
        'providerId': _getId(data['providerId']),
        'providerPhone': _getString(data['providerPhone'] ?? data['providerId']),
        'providerAvatar': _getString(data['providerAvatar'] ?? data['providerId']),
        'service': _getString(data['service'] ?? data['serviceId']),
        'date': _getString(data['date']),
        'time': _getString(data['time'] ?? data['startTime']),
        'status': _getString(data['status']),
        'location': _getString(data['location']),
        'notes': _getString(data['notes']),
        'totalPrice': _getDouble(data['totalPrice'] ?? data['price']),
        'dependentId': _getId(data['dependentId']),
        'paymentStatus': _getString(data['paymentStatus']),
        'clientTasks': _safeList(data['clientTasks']),
        'remainingAmount': _getDouble(data['remainingAmount']),
        'halfPaid': _getBool(data['halfPaid']),
        'trackingStage': _getString(data['trackingStage']),
        'stageTimes': data['stageTimes'] is Map ? Map<String, dynamic>.from(data['stageTimes']) : {},
        'locationLat': _getDouble(data['locationLat'], defaultValue: 36.7538),
        'locationLng': _getDouble(data['locationLng'], defaultValue: 3.0588),
      };
    }
    throw Exception('Failed to load booking details');
  }

  // ==================== TRACKING ====================
  Future<Map<String, dynamic>> getTrackingInfo(String bookingId) async {
    print('\n========== TRACKING API CALL ==========');
    print('Booking ID: $bookingId');
    try {
      final response = await _get('/api/client/tracking/$bookingId');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Parsed stageTimes: ${data['stageTimes']}');
        print('Type of stageTimes: ${data['stageTimes'].runtimeType}');
        return {
          'stage': data['stage'] ?? 'Pending',
          'status': data['status'] ?? 'waiting',
          'workSteps': _safeList(data['workSteps']),
          'attachments': _safeList(data['attachments']),
          'stageTimes': data['stageTimes'] ?? {},
          'eta': data['eta'],
          'providerLat': data['providerLat'],
          'providerLng': data['providerLng'],
          'lastUpdate': data['lastUpdate'],
          'clientTasks': _safeList(data['clientTasks']),
        };
      }
      print('❌ Failed with status: ${response.statusCode}');
      throw Exception('Failed to load tracking info');
    } catch (e) {
      print('❌ Exception in getTrackingInfo: $e');
      return {
        'stage': 'Pending',
        'status': 'waiting',
        'workSteps': [],
        'attachments': [],
        'stageTimes': {},
        'clientTasks': [],
      };
    }
  }

  Future<List<dynamic>> getPaymentHistory() async {
    final response = await _get('/api/client/payments');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<List<dynamic>> getPendingPayments() async {
    final response = await _get('/api/client/payments/pending');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> makePayment(Map<String, dynamic> data) async {
    final response = await _post('/api/client/payments', data);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to process payment');
  }

  Future<Map<String, dynamic>> submitFeedback(Map<String, dynamic> data) async {
    final response = await _post('/api/client/feedback', data);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to submit feedback');
  }

  Future<List<dynamic>> getFeedbackHistory() async {
    final response = await _get('/api/client/feedback');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> submitComplaint(Map<String, dynamic> data) async {
    final response = await _post('/api/client/complaints', data);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to submit complaint');
  }

  Future<List<dynamic>> getComplaintHistory() async {
    final response = await _get('/api/client/complaints');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<List<dynamic>> getNotifications() async {
    final response = await _get('/api/client/notifications');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<void> markNotificationRead(String id) async {
    final response = await _put('/api/client/notifications/$id/read', {});
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  // ✅ دالة getServiceHistory المعدلة (تعيد بيانات موحدة وجاهزة للعرض)
  Future<List<Map<String, dynamic>>> getServiceHistory() async {
    final response = await _get('/api/client/history');
    print('📡 Service History Response: ${response.body}'); // للتصحيح
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final List<Map<String, dynamic>> formatted = [];

      for (var item in data) {
        if (item is Map<String, dynamic>) {
          // استخراج اسم الخدمة
          String serviceName = '';
          if (item['service'] != null && item['service'] is String) {
            serviceName = item['service'];
          } else if (item['serviceId'] != null && item['serviceId'] is Map) {
            serviceName = item['serviceId']['name']?.toString() ?? '';
          } else if (item['serviceName'] != null) {
            serviceName = item['serviceName'].toString();
          }

          // استخراج اسم المزود
          String providerName = '';
          if (item['provider'] != null && item['provider'] is String) {
            providerName = item['provider'];
          } else if (item['providerId'] != null && item['providerId'] is Map) {
            providerName = item['providerId']['fullName']?.toString() ?? '';
          } else if (item['providerName'] != null) {
            providerName = item['providerName'].toString();
          }

          // استخراج التاريخ
          String dateStr = '';
          if (item['date'] != null) {
            try {
              final date = DateTime.parse(item['date'].toString());
              dateStr = _formatDate(date);
            } catch (e) {
              dateStr = item['date'].toString();
            }
          }

          // استخراج الوقت
          String timeStr = item['startTime']?.toString() ?? item['time']?.toString() ?? '';

          // استخراج السعر
          double price = 0.0;
          if (item['totalPrice'] != null) {
            price = (item['totalPrice'] as num).toDouble();
          } else if (item['price'] != null) {
            price = (item['price'] as num).toDouble();
          }

          formatted.add({
            'id': item['_id']?.toString() ?? '',
            'service': serviceName.isNotEmpty ? serviceName : 'Service',
            'provider': providerName.isNotEmpty ? providerName : 'Provider',
            'date': dateStr,
            'time': timeStr,
            'price': price,
            'status': item['status']?.toString() ?? 'Completed',
          });
        }
      }
      return formatted;
    }
    return [];
  }

  // دالة مساعدة لتنسيق التاريخ (يمكن إزالتها إذا لم تكن موجودة)
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<List<dynamic>> getAds({
    String? wilaya,
    String? category,
    String? service,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (wilaya != null && wilaya != 'All') queryParams['wilaya'] = wilaya;
      if (category != null && category != 'All') queryParams['category'] = category;
      if (service != null && service != 'All') queryParams['service'] = service;
      queryParams['page'] = page.toString();
      queryParams['limit'] = limit.toString();
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/client/ads').replace(queryParameters: queryParams);
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching ads: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> payHalf(String bookingId, String paymentMethod, Map<String, dynamic> paymentDetails) async {
    final response = await _put('/api/client/bookings/$bookingId/pay-half', {
      'paymentMethod': paymentMethod,
      'paymentDetails': paymentDetails,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to process half payment');
  }

  Future<Map<String, dynamic>> addClientTasks(String bookingId, List<Map<String, String>> tasks) async {
    final response = await _post('/api/client/bookings/$bookingId/tasks', {
      'tasks': tasks,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to add tasks');
  }

  Future<Map<String, dynamic>> getClientTasks(String bookingId) async {
    final response = await _get('/api/client/bookings/$bookingId/tasks');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get tasks');
  }

  Future<Map<String, dynamic>> getProviderAvailability(String providerId) async {
    try {
      final response = await _get('/api/client/availability/$providerId');
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return {};
      }
      return {};
    } catch (e) {
      print('Error fetching availability: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> createBookingRequest(Map<String, dynamic> data) async {
    final response = await _post('/api/client/booking-requests', data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'Failed to create booking request');
  }

  Future<List<dynamic>> getMyBookingRequests() async {
    final response = await _get('/api/client/booking-requests');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> getBookingRequestStatus(String requestId) async {
    final response = await _get('/api/client/booking-requests/$requestId/status');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get request status');
  }

  Future<Map<String, dynamic>> payRemaining(String bookingId) async {
    final response = await _post('/api/client/bookings/$bookingId/pay-remaining', {});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to pay remaining amount');
  }
  
  Future<Map<String, dynamic>> rateProvider(String bookingId, int rating, String comment) async {
    final response = await _post('/api/client/bookings/$bookingId/rate-provider', {
      'rating': rating,
      'comment': comment,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to rate provider');
  }

  Future<Map<String, dynamic>> createBookingRequestWithFiles({
    required Map<String, String> fields,
    required List<File> files,
  }) async {
    final token = await _getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/client/booking-requests'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    fields.forEach((key, value) {
      request.fields[key] = value;
    });

    for (final file in files) {
      request.files.add(await http.MultipartFile.fromPath(
        'files',
        file.path,
        filename: file.path.split('/').last,
      ));
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(responseBody);
    }
    final error = jsonDecode(responseBody);
    throw Exception(error['message'] ?? 'Failed to create booking request with files');
  }
}