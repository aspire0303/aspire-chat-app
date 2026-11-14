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
