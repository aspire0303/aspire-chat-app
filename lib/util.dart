const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String timeLabel(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayLabel(DateTime t) {
  final now = DateTime.now();
  if (sameDay(t, now)) return 'Today';
  if (sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  return '${t.day} ${_months[t.month - 1]} ${t.year}';
}

String listTime(DateTime t) {
  if (sameDay(t, DateTime.now())) return timeLabel(t);
  if (sameDay(t, DateTime.now().subtract(const Duration(days: 1)))) return 'Yesterday';
  return '${t.day} ${_months[t.month - 1]}';
}

String fmtIso(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  return '${t.day} ${_months[t.month - 1]} ${t.year}';
}

String monthLabelYm(String ym) {
  final t = DateTime.tryParse('$ym-01');
  if (t == null) return ym;
  return '${_months[t.month - 1]} ${t.year}';
}

const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String fmtIsoWithDay(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  return '${_weekdays[t.weekday - 1]}, ${t.day} ${_months[t.month - 1]}';
}

/// "09:30" -> "9:30 AM"
String clock(String t) {
  final p = t.split(':');
  if (p.length != 2) return t;
  final h = int.tryParse(p[0]);
  if (h == null) return t;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${p[1]} ${h >= 12 ? 'PM' : 'AM'}';
}
