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

class ErpSession {
  const ErpSession({
    required this.token,
    required this.role,
    required this.name,
    this.campusId = '',
    this.campusName = '',
  });
  final String token;
  final String role;
  final String name;
  final String campusId;
  final String campusName;
}

class ErpApi {
  static const _kToken = 'erp_token';
  static const _kName = 'erp_name';
  static const _kRole = 'erp_role';
  static const _kCampus = 'erp_campus';
  static const _kCampusName = 'erp_campus_name';
  static const _unreachable = 'Cannot reach the school server. Check your internet and that the ERP is running.';

  static Future<String?> token() async => (await SharedPreferences.getInstance()).getString(_kToken);
  static Future<String?> savedName() async => (await SharedPreferences.getInstance()).getString(_kName);

  static Future<ErpSession?> session() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString(_kToken);
    if (t == null || t.isEmpty) return null;
    return ErpSession(
      token: t,
      role: p.getString(_kRole) ?? 'OWNER',
      name: p.getString(_kName) ?? '',
      campusId: p.getString(_kCampus) ?? '',
      campusName: p.getString(_kCampusName) ?? '',
    );
  }

  static Future<void> _save(ErpSession s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, s.token);
    await p.setString(_kRole, s.role);
    await p.setString(_kName, s.name);
    await p.setString(_kCampus, s.campusId);
    await p.setString(_kCampusName, s.campusName);
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [_kToken, _kName, _kRole, _kCampus, _kCampusName]) {
      await p.remove(k);
    }
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

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await http
          .post(Uri.parse('$erpBaseUrl$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));
      return _decode(r);
    } on ErpException {
      rethrow;
    } catch (_) {
      throw ErpException(_unreachable);
    }
  }

  static Future<Map<String, dynamic>> getJson(String path) async {
    final t = await token();
    if (t == null) throw ErpException('Please sign in.', unauthorized: true);
    try {
      final r = await http
          .get(Uri.parse('$erpBaseUrl$path'), headers: {'Authorization': 'Bearer $t'})
          .timeout(const Duration(seconds: 60));
      return _decode(r);
    } on ErpException {
      rethrow;
    } catch (_) {
      throw ErpException('Cannot reach the school server. Pull down to try again.');
    }
  }

  static Future<List<Map<String, dynamic>>> campuses() async {
    try {
      final r = await http.get(Uri.parse('$erpBaseUrl/api/mobile/campuses')).timeout(const Duration(seconds: 25));
      final body = _decode(r);
      return ((body['campuses'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on ErpException {
      rethrow;
    } catch (_) {
      throw ErpException(_unreachable);
    }
  }

  static Future<ErpSession> staffLogin({required String email, required String password, required String campusId}) async {
    final body = await _post('/api/mobile/staff-login', {'email': email.trim(), 'password': password, 'campus': campusId});
    final user = (body['user'] as Map?) ?? {};
    final s = ErpSession(
      token: '${body['token']}',
      role: '${user['role'] ?? 'TEACHER'}',
      name: '${user['name'] ?? ''}',
      campusId: '${user['campusId'] ?? campusId}',
      campusName: '${user['campusName'] ?? ''}',
    );
    await _save(s);
    return s;
  }

  static Future<ErpSession> parentLogin({required String loginNumber, required String password}) async {
    final body = await _post('/api/parent/login', {'loginNumber': loginNumber.trim(), 'password': password});
    final s = ErpSession(token: '${body['token']}', role: 'PARENT', name: '${body['parentName'] ?? 'Parent'}');
    await _save(s);
    return s;
  }

  static Future<void> ownerLogin(String email, String password) async {
    await staffLogin(email: email, password: password, campusId: '__owner__');
  }

  static Future<Map<String, dynamic>> ownerDashboard() => getJson('/api/mobile/owner/dashboard');
  static Future<Map<String, dynamic>> teacherHome() => getJson('/api/mobile/teacher/home');
  static Future<Map<String, dynamic>> teacherStudents(String className, String section) =>
      getJson('/api/mobile/teacher/students?class=${Uri.encodeQueryComponent(className)}&section=${Uri.encodeQueryComponent(section)}');
}