import 'package:flutter/material.dart';

import 'charts.dart';
import 'erp_api.dart';
import 'parent_common.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);
const _purple = Color(0xFF9333EA);
const _blue = Color(0xFF2563EB);

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

int _n(dynamic v) => v is num ? v.round() : (int.tryParse('${v ?? ''}') ?? 0);

Color _statusColor(String s) {
  switch (s) {
    case 'present':
      return _green;
    case 'absent':
      return _red;
    case 'leave':
      return _amber;
    case 'half':
      return _purple;
    case 'holiday':
      return _blue;
    default:
      return _muted;
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'present':
      return 'Present';
    case 'absent':
      return 'Absent';
    case 'leave':
      return 'Leave';
    case 'half':
      return 'Half leave';
    case 'holiday':
      return 'Holiday';
    default:
      return s;
  }
}

class ParentAttendancePage extends StatefulWidget {
  const ParentAttendancePage({super.key, required this.studentId, required this.studentName});
  final String studentId;
  final String studentName;

  @override
  State<ParentAttendancePage> createState() => _ParentAttendancePageState();
}

class _ParentAttendancePageState extends State<ParentAttendancePage> {
  Map<String, dynamic>? _data;
  String? _month;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(null);
  }

  Future<void> _load(String? month) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ParentApi.attendance(widget.studentId, month: month);
      if (!mounted) return;
      setState(() {
        _data = d;
        _month = '${d['month']}';
        _loading = false;
      });
    } on ErpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  String _shift(int delta) {
    final cur = _month ?? '';
    final now = DateTime.now();
    final y = cur.length >= 7 ? (int.tryParse(cur.substring(0, 4)) ?? now.year) : now.year;
    final m = cur.length >= 7 ? (int.tryParse(cur.substring(5, 7)) ?? now.month) : now.month;
    final d = DateTime(y, m + delta, 1);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  bool get _canNext {
    final today = '${_data?['today'] ?? ''}';
    if (_month == null || today.length < 7) return false;
    return _month!.compareTo(today.substring(0, 7)) < 0;
  }

  String get _monthTitle {
    final cur = _month ?? '';
    if (cur.length < 7) return '';
    final m = int.tryParse(cur.substring(5, 7)) ?? 1;
    final idx = m < 1 ? 0 : (m > 12 ? 11 : m - 1);
    return '${_monthNames[idx]} ${cur.substring(0, 4)}';
  }

  String _extra(Map<String, dynamic> x) {
    final st = '${x['status']}';
    if (st == 'half' && '${x['leaveTime']}'.isNotEmpty) return 'Left at ${x['leaveTime']}';
    if (st == 'leave' && '${x['reason']}'.isNotEmpty) return '${x['reason']}';
    return '';
  }

  Widget _card(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _calendar(String month, Map<String, String> byDay) {
    final y = int.tryParse(month.substring(0, 4)) ?? DateTime.now().year;
    final m = int.tryParse(month.substring(5, 7)) ?? DateTime.now().month;
    final lead = DateTime(y, m, 1).weekday - 1;
    final daysIn = DateTime(y, m + 1, 0).day;
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysIn; d++) {
      final key = '$month-${d.toString().padLeft(2, '0')}';
      final st = byDay[key];
      final c = st == null ? null : _statusColor(st);
      cells.add(
        Container(
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: c == null ? const Color(0xFFF1F5F9) : null,
            gradient: c == null ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(c, 0.2), darken(c, 0.15)]),
            boxShadow: c == null ? null : [BoxShadow(color: c.withAlpha(80), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: Text('$d', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c == null ? _muted : Colors.white)),
        ),
      );
    }
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(
      children: [
        Row(children: [for (final n in names) Expanded(child: Center(child: Text(n, style: const TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.w700))))]),
        const SizedBox(height: 6),
        GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: cells),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final ms = (d?['monthSummary'] as Map?) ?? {};
    final ov = (d?['overall'] as Map?) ?? {};
    final days = ((d?['days'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final leaves = ((d?['upcomingLeaves'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final byDay = <String, String>{for (final x in days) '${x['date']}': '${x['status']}'};
    final pctAll = ov['percentPresent'];
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4EC),
      body: RefreshIndicator(
        onRefresh: () => _load(_month),
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ParentHeader(title: 'Attendance', subtitle: widget.studentName, onBack: () => Navigator.of(context).pop()),
            if (_loading && d == null)
              const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
            else if (d == null)
              _card(
                'Could not load attendance',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error ?? 'Unknown error', style: const TextStyle(color: _muted)),
                    const SizedBox(height: 10),
                    FilledButton.icon(onPressed: () => _load(_month), icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                  ],
                ),
              )
            else ...[
              _card(
                'Overall',
                DonutWithLegend(
                  slices: [
                    Slice('Present', _n(ov['present']).toDouble(), _green),
                    Slice('Absent', _n(ov['absent']).toDouble(), _red),
                    Slice('Leave', _n(ov['leave']).toDouble(), _amber),
                    Slice('Half leave', _n(ov['half']).toDouble(), _purple),
                  ],
                  centerValue: pctAll == null ? '—' : '$pctAll%',
                  centerLabel: 'present',
                ),
              ),
              _card(
                'Calendar',
                Column(
                  children: [
                    Row(
                      children: [
                        IconButton(onPressed: _loading ? null : () => _load(_shift(-1)), icon: const Icon(Icons.chevron_left_rounded)),
                        Expanded(child: Center(child: Text(_monthTitle, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)))),
                        IconButton(onPressed: (_loading || !_canNext) ? null : () => _load(_shift(1)), icon: const Icon(Icons.chevron_right_rounded)),
                      ],
                    ),
                    _calendar(_month ?? '${d['month']}', byDay),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _pill('Present ${_n(ms['present'])}', _green),
                        _pill('Absent ${_n(ms['absent'])}', _red),
                        _pill('Leave ${_n(ms['leave'])}', _amber),
                        _pill('Half ${_n(ms['half'])}', _purple),
                        _pill('Holiday ${_n(ms['holiday'])}', _blue),
                      ],
                    ),
                  ],
                ),
              ),
              if (leaves.isNotEmpty)
                _card(
                  'Upcoming leaves',
                  Column(
                    children: [
                      for (final l in leaves)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              const Icon(Icons.beach_access_rounded, color: _amber, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${l['from']} to ${l['to']}${'${l['reason']}'.isEmpty ? '' : ' · ${l['reason']}'}',
                                  style: const TextStyle(color: _ink, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (days.isNotEmpty)
                _card(
                  'Days this month',
                  Column(
                    children: [
                      for (final x in days.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              SizedBox(width: 56, child: Text('${x['date']}'.substring(5), style: const TextStyle(fontWeight: FontWeight.w700, color: _ink))),
                              _pill(_statusLabel('${x['status']}'), _statusColor('${x['status']}')),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_extra(x), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _muted))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
