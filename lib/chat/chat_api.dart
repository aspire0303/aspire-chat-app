import '../erp/erp_api.dart';

List<Map<String, dynamic>> asList(dynamic v) =>
    ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

String chatTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final n = DateTime.now();
  String two(int x) => x < 10 ? '0$x' : '$x';
  if (d.year == n.year && d.month == n.month && d.day == n.day) return '${two(d.hour)}:${two(d.minute)}';
  return '${two(d.day)}/${two(d.month)}';
}

class ChatApi {
  static const _p = '/api/mobile/chat';
  static Future<Map<String, dynamic>> conversations() => ErpApi.getJson('$_p?op=conversations');
  static Future<Map<String, dynamic>> contacts() => ErpApi.getJson('$_p?op=contacts');
  static Future<Map<String, dynamic>> messages(String conv) => ErpApi.getJson('$_p?op=messages&conv=${Uri.encodeQueryComponent(conv)}');
  static Future<Map<String, dynamic>> records(String q, String kind) =>
      ErpApi.getJson('$_p?op=records&q=${Uri.encodeQueryComponent(q)}&kind=$kind');
  static Future<Map<String, dynamic>> open(String withPid, {String kind = 'direct', String subject = ''}) =>
      ErpApi.postAuth(_p, {'op': 'open', 'with': withPid, 'kind': kind, 'subject': subject});
  static Future<Map<String, dynamic>> send(String conv, String text) =>
      ErpApi.postAuth(_p, {'op': 'send', 'conv': conv, 'text': text});
  static Future<Map<String, dynamic>> delete(String conv, String msg, String mode) =>
      ErpApi.postAuth(_p, {'op': 'delete', 'conv': conv, 'msg': msg, 'mode': mode});
  static Future<Map<String, dynamic>> setStatus(String conv, String status) =>
      ErpApi.postAuth(_p, {'op': 'status', 'conv': conv, 'status': status});
}