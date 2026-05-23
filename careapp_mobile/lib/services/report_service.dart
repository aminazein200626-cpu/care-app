import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

class ReportService {
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
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

  /// إنشاء تقرير جديد (يتم إرسال بريد المُبلَّغ عنه فقط)
  Future<Map<String, dynamic>> createReport({
    required String reportedEmail,   // email2
    required String reason,
    String description = '',
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/reports'),
      headers: headers,
      body: jsonEncode({
        'email2': reportedEmail,
        'reason': reason,
        'description': description,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to create report');
    }
  }

  /// الحصول على قائمة التقارير التي أرسلها المستخدم الحالي
  Future<List<dynamic>> getMyReports() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/reports/my-reports'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reports'] ?? [];
    } else {
      return [];
    }
  }
}