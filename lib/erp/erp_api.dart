import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'erp_config.dart';

class ErpException implements Exception {
  ErpException(this.message, {this.unauthorized = false});
  final String message;
  final bool unauthorized;
  @override
  String toString() => message;
}

class ErpApi {
  static const _tokenKey = 'erp_token';
  static const _nameKey = 'erp_name';

  static Future<String?> token() async => (await SharedPreferences.getInstance()).getString(_tokenKey);
  static Future<String?> savedName() async => (await SharedPreferences.getInstance()).getString(_nameKey);

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_nameKey);
  }

  static Map<String, dynamic> _decode(http.Response r) {
    Map<String, dynamic> body = {};
    try {
      final j = jsonDecode(r.body);
      if (j is Map<String, dynamic>) body = j;
    } catch (_) {}
    final msg = body['error']?.toString();
    if (r.statusCode == 401) throw ErpException(msg ?? 'Please sign in again.', unauthorized: true);
    if (r.statusCode >= 400) throw ErpException(msg ?? 'Server error (${r.statusCode}).');
    return body;
  }

  static Future<void> ownerLogin(String email, String password) async {
    try {
      final r = await http
          .post(
            Uri.parse('$erpBaseUrl/api/mobile/staff-login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password, 'campus': '__owner__'}),
          )
          .timeout(const Duration(seconds: 25));
      final body = _decode(r);
      final user = (body['user'] as Map?) ?? {};
      final p = await SharedPreferences.getInstance();
      await p.setString(_tokenKey, '${body['token']}');
      await p.setString(_nameKey, '${user['name'] ?? 'Owner'}');
    } on ErpException {
      rethrow;
    } catch (_) {
      throw ErpException('Cannot reach the school server. Check your internet and that the ERP is running.');
    }
  }

  static Future<Map<String, dynamic>> ownerDashboard() async {
    final t = await token();
    if (t == null) throw ErpException('Please sign in.', unauthorized: true);
    try {
      final r = await http
          .get(Uri.parse('$erpBaseUrl/api/mobile/owner/dashboard'), headers: {'Authorization': 'Bearer $t'})
          .timeout(const Duration(seconds: 40));
      return _decode(r);
    } on ErpException {
      rethrow;
    } catch (_) {
      throw ErpException('Cannot reach the school server. Pull down to try again.');
    }
  }
}