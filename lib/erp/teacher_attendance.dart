import 'package:flutter/material.dart';

import 'charts.dart';
import 'erp_api.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);
const _purple = Color(0xFF9333EA);
const _teal = Color(0xFF0F766E);

String _title(String className, String section) => section.isEmpty ? className : '$className · $section';

class _Opt {
  const _Opt(this.key, this.label, this.color);
  final String key;
  final String label;
  final Color color;
}

const _opts = <_Opt>[
  _Opt('present', 'Present', _green),
  _Opt('absent', 'Absent', _red),
  _Opt('leave', 'Leave', _amber),
  _Opt('half', 'Half', _purple),
];

class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({super.key, required this.className, required this.section});
  final String className;
  final String section;

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  List<Map<String, dynamic>> _roster = [];
  final Map<String, String> _status = {};
  final Map<String, String> _time = {};
  final Map<String, String> _reason = {};
  String _today = '';
  bool _saved = false;
  bool _holiday = false;
  String _markedBy = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ErpApi.teacherAttendance(widget.className, widget.section);
      final roster = ((d['roster'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final entries = (d['entries'] as Map?) ?? {};
      final advance = (d['advance'] as Map?) ?? {};
      final saved = d['saved'] == true;
      final st = <String, String>{};
      final tm = <String, String>{};
      final rs = <String, String>{};
      var holidays = 0;
      for (final s in roster) {
        final id = '${s['studentId']}';
        final e = entries[id];
        final status = e is Map ? '${e['status'] ?? ''}' : '';
        if (status == 'holiday') {
          holidays++;
        } else if (status.isNotEmpty) {
          st[id] = status;
          if (e is Map && '${e['leaveTime'] ?? ''}'.isNotEmpty) tm[id] = '${e['leaveTime']}';
          if (e is Map && '${e['reason'] ?? ''}'.isNotEmpty) rs[id] = '${e['reason']}';
        } else if (!saved && advance[id] is Map) {
          st[id] = 'leave';
          final r = '${(advance[id] as Map)['reason'] ?? ''}';
          if (r.isNotEmpty) rs[id] = r;
        }
      }
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _today = '${d['today'] ?? ''}';
        _saved = saved;
        _holiday = saved && roster.isNotEmpty && holidays == roster.length;
        _markedBy = '${d['markedBy'] ?? ''}';
        _status
          ..clear()
          ..addAll(st);
        _time
          ..clear()
          ..addAll(tm);
        _reason
          ..clear()
          ..addAll(rs);
        _loading = false;
      });
    } on ErpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.unauthorized ? 'Your session expired. Go back and sign in again.' : e.message;
        _loading = false;
      });
    }
  }

  TimeOfDay? _parse(String? v) {
    if (v == null || v.length < 5) return null;
    final h = int.tryParse(v.substring(0, 2));
    final m = int.tryParse(v.substring(3, 5));
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _choose(String id, String key) async {
    if (key == 'half') {
      final t = await showTimePicker(context: context, initialTime: _parse(_time[id]) ?? TimeOfDay.now(), helpText: 'Time the student left');
      if (t == null || !mounted) return;
      setState(() {
        _status[id] = 'half';
        _time[id] = _fmt(t);
      });
      return;
    }
    setState(() {
      _status[id] = key;
      _time.remove(id);
      if (key != 'leave') _reason.remove(id);
    });
  }

  void _allPresent() {
    setState(() {
      for (final s in _roster) {
        final id = '${s['studentId']}';
        _status[id] = 'present';
        _time.remove(id);
        _reason.remove(id);
      }
    });
  }

  Future<void> _save() async {
    final missing = _roster.where((s) => !_status.containsKey('${s['studentId']}')).length;
    if (missing > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$missing student(s) are not marked yet. Mark every student before saving.')));
      return;
    }
    final entries = <String, dynamic>{};
    for (final s in _roster) {
      final id = '${s['studentId']}';
      final st = _status[id] ?? 'present';
      final e = <String, dynamic>{'status': st};
      if (st == 'half') e['leaveTime'] = _time[id] ?? '';
      if (st == 'leave' && (_reason[id] ?? '').isNotEmpty) e['reason'] = _reason[id];
      entries[id] = e;
    }
    setState(() => _saving = true);
    try {
      await ErpApi.saveTeacherAttendance(widget.className, widget.section, entries);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved.')));
      Navigator.of(context).pop(true);
    } on ErpException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }

  Widget _optButton(String id, _Opt o, bool last) {
    final on = _status[id] == o.key;
    return Expanded(
      child: GestureDetector(
        onTap: _saving ? null : () => _choose(id, o.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          margin: EdgeInsets.only(right: last ? 0 : 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: on ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(o.color, 0.2), darken(o.color, 0.15)]) : null,
            color: on ? null : o.color.withAlpha(25),
            boxShadow: on ? [BoxShadow(color: o.color.withAlpha(100), blurRadius: 8, offset: const Offset(0, 4))] : null,
          ),
          child: Text(o.label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: on ? Colors.white : o.color)),
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> s) {
    final id = '${s['studentId']}';
    final st = _status[id];
    final father = '${s['fatherName'] ?? ''}';
    var extra = '';
    if (st == 'half' && (_time[id] ?? '').isNotEmpty) extra = 'Left at ${_time[id]}';
    if (st == 'leave' && (_reason[id] ?? '').isNotEmpty) extra = '${_reason[id]}';
    final sub = [if (father.isNotEmpty) 'Father: $father', if (extra.isNotEmpty) extra].join('  ·  ');
    final roll = '${s['rollNo'] ?? ''}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: st == null ? Border.all(color: const Color(0xFFFCA5A5)) : null,
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(_teal, 0.2), darken(_teal, 0.15)]),
                ),
                child: Text(roll.isEmpty ? '-' : roll, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                    if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [for (var i = 0; i < _opts.length; i++) _optButton(id, _opts[i], i == _opts.length - 1)]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    var p = 0, a = 0, l = 0, h = 0;
    for (final s in _roster) {
      switch (_status['${s['studentId']}']) {
        case 'present':
          p++;
        case 'absent':
          a++;
        case 'leave':
          l++;
        case 'half':
          h++;
      }
    }
    final unmarked = _roster.length - p - a - l - h;
    final canSave = !_loading && _roster.isNotEmpty && !_holiday;
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5EE),
      bottomNavigationBar: canSave
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x220F172A), blurRadius: 14, offset: Offset(0, -4))]),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        unmarked > 0 ? '$unmarked not marked yet' : (_saved ? 'Saved by $_markedBy. You can update it today.' : 'Everyone is marked.'),
                        style: TextStyle(fontSize: 12, color: unmarked > 0 ? _red : _muted, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(_saved ? 'Update' : 'Save'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(8, top + 8, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF064E3B), Color(0xFF16A34A), Color(0xFF4ADE80)]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Color(0x5516A34A), blurRadius: 24, offset: Offset(0, 12))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Attendance', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                            Text('${_title(widget.className, widget.section)}  ·  $_today', style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _pill('Present $p'),
                        _pill('Absent $a'),
                        _pill('Leave $l'),
                        _pill('Half $h'),
                        _pill('Not marked $unmarked'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_loading && _roster.isEmpty)
              const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _roster.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
                    const SizedBox(height: 10),
                    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                  ],
                ),
              )
            else if (_roster.isEmpty)
              const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No students in this class.', style: TextStyle(color: _muted))))
            else if (_holiday)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Today is marked as a public holiday for this class. Nothing to mark.', textAlign: TextAlign.center, style: TextStyle(color: _muted))),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    const Expanded(child: Text('Choose a status for every student.', style: TextStyle(fontSize: 12, color: _muted))),
                    TextButton.icon(onPressed: _saving ? null : _allPresent, icon: const Icon(Icons.done_all_rounded, size: 18), label: const Text('All present')),
                  ],
                ),
              ),
              for (final s in _roster) _row(s),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
