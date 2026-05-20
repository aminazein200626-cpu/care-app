import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  
  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  
  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      _currentUser = User.fromJson(jsonDecode(userJson));
    }
    notifyListeners();
  }
  
  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        _token = data['token'];
        final String role = data['role'] ?? 'Client';
        _currentUser = User(
          id: data['userId'].toString(),
          fullName: data['name'].toString(),
          email: data['email'].toString(),
          phoneNumber: data['phoneNumber']?.toString() ?? '',
          role: role,
          profilePicture: data['profilePicture']?.toString(),
        );
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('userId', data['userId'].toString());
        await prefs.setString('role', role);                     // Added
        await prefs.setString('user', jsonEncode({
          'userId': data['userId'],
          'name': data['name'],
          'email': data['email'],
          'role': role,
          'phoneNumber': data['phoneNumber'] ?? '',
        }));
        
        _isLoading = false;
        notifyListeners();
        return data;
      } else {
        _isLoading = false;
        notifyListeners();
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> registerClient(Map<String, dynamic> userData) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.register}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          ...userData,
          'role': 'Client',
        }),
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return data;
      } else {
        _isLoading = false;
        notifyListeners();
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> registerProvider(Map<String, dynamic> userData) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerProvider}'),
      );
      
      userData.forEach((key, value) {
        if (value is! File) {
          request.fields[key] = value.toString();
        }
      });
      request.fields['role'] = 'Provider';
      
      if (userData['profilePicture'] != null && userData['profilePicture'] is File) {
        final file = userData['profilePicture'] as File;
        request.files.add(await http.MultipartFile.fromPath('profilePicture', file.path));
      }
      
      if (userData['idCard'] != null && userData['idCard'] is File) {
        final file = userData['idCard'] as File;
        request.files.add(await http.MultipartFile.fromPath('idCard', file.path));
      }
      
      if (userData['license'] != null && userData['license'] is File) {
        final file = userData['license'] as File;
        request.files.add(await http.MultipartFile.fromPath('license', file.path));
      }
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      
      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return data;
      } else {
        _isLoading = false;
        notifyListeners();
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final headers = await getAuthHeaders();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.changePassword}'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      
      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to change password');
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('role');
    await prefs.remove('userId');
    _token = null;
    _currentUser = null;
    notifyListeners();
  }
  
  Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }
  
  Future<void> updateProfilePicture(File imageFile) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final token = await _getToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/auth/profile-picture'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('profilePicture', imageFile.path));
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      
      if (response.statusCode == 200) {
        if (_currentUser != null) {
          _currentUser = User(
            id: _currentUser!.id,
            fullName: _currentUser!.fullName,
            email: _currentUser!.email,
            phoneNumber: _currentUser!.phoneNumber,
            role: _currentUser!.role,
            profilePicture: data['profilePicture'],
          );
        }
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception(data['message'] ?? 'Failed to update profile picture');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }
}