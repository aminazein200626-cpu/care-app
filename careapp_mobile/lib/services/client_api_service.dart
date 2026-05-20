import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

class ClientApiService {
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

  Future<List<dynamic>> searchProviders({
    String? service,
    String? location,
    String? name,
  }) async {
    final queryParams = <String, String>{};
    if (service != null) queryParams['service'] = service;
    if (location != null) queryParams['location'] = location;
    if (name != null) queryParams['name'] = name;
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/client/providers').replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
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

  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    final response = await _get('/api/client/bookings/$bookingId');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'id': data['id'] ?? data['_id'],
        'provider': data['provider'] ?? data['providerId']?['fullName'],
        'providerPhone': data['providerPhone'] ?? data['providerId']?['phoneNumber'],
        'providerAvatar': data['providerAvatar'] ?? data['providerId']?['profilePicture'],
        'service': data['service'] ?? data['serviceId']?['name'],
        'date': data['date'],
        'time': data['time'] ?? data['startTime'],
        'status': data['status'],
        'location': data['location'],
        'notes': data['notes'],
        'totalPrice': data['totalPrice'] ?? data['price'],
        'dependentId': data['dependentId'],
        'paymentStatus': data['paymentStatus'],
      };
    }
    throw Exception('Failed to load booking details');
  }

  Future<Map<String, dynamic>> getTrackingInfo(String bookingId) async {
    try {
      final response = await _get('/api/client/tracking/$bookingId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'stage': data['stage'] ?? 'Pending',
          'status': data['status'] ?? 'waiting',
          'workSteps': data['workSteps'] ?? [],
          'attachments': data['attachments'] ?? [],
          'stageTimes': data['stageTimes'] ?? {},
          'eta': data['eta'],
          'providerLat': data['providerLat'] ?? data['locationLat'],
          'providerLng': data['providerLng'] ?? data['locationLng'],
          'lastUpdate': data['lastUpdate'],
        };
      }
      throw Exception('Failed to load tracking info');
    } catch (e) {
      return {
        'stage': 'Pending',
        'status': 'waiting',
        'workSteps': [],
        'attachments': [],
        'stageTimes': {},
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

  Future<List<dynamic>> getServiceHistory() async {
    final response = await _get('/api/client/history');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) {
        return {
          ...item,
          'dependentName': item['dependentId'] != null ? item['dependentId']['fullName'] : null,
        };
      }).toList();
    }
    return [];
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

  // ✅ الدالة المعدلة: تقبل paymentDetails
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
    print('📡 createBookingRequest response status: ${response.statusCode}');
    print('📡 createBookingRequest response body: ${response.body}');
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

  // ==================== PROVIDER BOOKING REQUESTS ====================
  Future<Map<String, dynamic>> getBookingRequestDetails(String requestId) async {
    final response = await _get('/api/provider/booking-requests/$requestId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load booking request details');
  }

  Future<Map<String, dynamic>> getBookingRequestStatus(String requestId) async {
    final response = await _get('/api/client/booking-requests/$requestId/status');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get request status');
  }

    // ==================== PAY REMAINING AMOUNT ====================
  Future<Map<String, dynamic>> payRemaining(String bookingId) async {
    final response = await _post('/api/client/bookings/$bookingId/pay-remaining', {});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to pay remaining amount');
  }

  // ==================== RATE PROVIDER ====================
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
}