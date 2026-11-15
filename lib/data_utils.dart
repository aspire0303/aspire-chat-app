Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> asList(dynamic v) => v is List ? v : <dynamic>[];

String asStr(dynamic v) => v == null ? '' : v.toString();

num? asNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

/// Rs. 12,500
String rs(num? n) {
  final v = (n ?? 0).round();
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'Rs. ${v < 0 ? '-' : ''}$b';
}

String pct(num? n) {
  if (n == null) return '-';
  final r = (n * 10).round() / 10;
  return r == r.roundToDouble() ? '${r.round()}%' : '$r%';
}

String marksText(num? n) {
  if (n == null) return '-';
  return n == n.roundToDouble() ? '${n.round()}' : '$n';
}
