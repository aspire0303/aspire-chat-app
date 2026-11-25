import 'package:flutter/material.dart';

import 'erp_api.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);
const _purple = Color(0xFF9333EA);
const _blue = Color(0xFF2563EB);
const _bg = Color(0xFFEAF5EE);

String _two(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
DateTime _parse(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
String _nice(String ymd) {
  final d = _parse(ymd);
  return '${_dayNames[d.weekday - 1]}, ${_two(d.day)}-${_two(d.month)}-${d.year}';
}

String _classTitle(String c, String s) => s.isEmpty ? c : '$c - $s';
List<Map<String, dynamic>> _list(dynamic v) =>
    ((v as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

Widget _gradHeader(BuildContext context, String title, String sub, {List<Widget> actions = const []}) {
  final top = MediaQuery.of(context).padding.top;
  return Container(
    padding: EdgeInsets.fromLTRB(8, top + 8, 8, 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF064E3B), Color(0xFF16A34A), Color(0xFF4ADE80)]),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      boxShadow: [BoxShadow(color: Color(0x5516A34A), blurRadius: 24, offset: Offset(0, 12))],
    ),
    child: Row(
      children: [
        IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 12)),
            ],
          ),
        ),
        ...actions,
      ],
    ),
  );
}

void _toast(BuildContext context, String msg, {bool bad = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: bad ? _red : _green, behavior: SnackBarBehavior.floating),
  );
}

// ---------------------------------------------------------------------------
// Class hub: what a teacher can do for one class
// ---------------------------------------------------------------------------
class TeacherClassHub extends StatelessWidget {
  const TeacherClassHub({super.key, required this.className, required this.section, required this.studentsPage});
  final String className;
  final String section;
  final Widget studentsPage;

  Widget _tile(BuildContext context, IconData icon, Color color, String title, String sub, Widget page) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 14, offset: Offset(0, 7))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: _muted)),
        trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _gradHeader(context, 'Class ${_classTitle(className, section)}', 'What would you like to do?'),
          _tile(context, Icons.fact_check_rounded, _green, 'Attendance', 'Mark today\'s attendance', TeacherAttendancePage(className: className, section: section)),
          _tile(context, Icons.menu_book_rounded, _blue, 'Diary', 'Write the class diary and homework', TeacherDiaryPage(className: className, section: section)),
          _tile(context, Icons.groups_rounded, _purple, 'Students', 'See the students of this class', studentsPage),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attendance
// ---------------------------------------------------------------------------
class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({super.key, required this.className, required this.section});
  final String className;
  final String section;

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  bool _loading = true;
  bool _saving = false;
  bool _holiday = false;
  bool _saved = false;
  String? _error;
  String _today = '';
  String _markedBy = '';
  String _q = '';
  List<Map<String, dynamic>> _roster = [];
  final Map<String, String> _status = {};
  final Map<String, String> _time = {};
  final Map<String, String> _reason = {};

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
      final roster = _list(d['roster']);
      final entries = (d['entries'] as Map?) ?? {};
      final adv = (d['advance'] as Map?) ?? {};
      _status.clear();
      _time.clear();
      _reason.clear();
      var holidays = 0;
      for (final s in roster) {
        final id = '${s['studentId']}';
        final e = entries[id];
        if (e is Map) {
          final st = '${e['status'] ?? ''}';
          if (st == 'holiday') {
            holidays++;
          } else {
            _status[id] = st;
            _time[id] = '${e['leaveTime'] ?? ''}';
            _reason[id] = '${e['reason'] ?? ''}';
          }
        } else if (adv[id] is Map) {
          _status[id] = 'leave';
          _reason[id] = '${(adv[id] as Map)['reason'] ?? ''}';
        }
      }
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _today = '${d['today'] ?? ''}';
        _saved = d['saved'] == true;
        _markedBy = '${d['markedBy'] ?? ''}';
        _holiday = roster.isNotEmpty && holidays == roster.length;
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

  void _set(String id, String status) {
    setState(() => _status[id] = status);
  }

  Future<void> _pickHalf(String id) async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0), helpText: 'Time the student left');
    if (t == null) return;
    setState(() {
      _status[id] = 'half';
      _time[id] = '${_two(t.hour)}:${_two(t.minute)}';
    });
  }

  void _allPresent() {
    setState(() {
      for (final s in _roster) {
        final id = '${s['studentId']}';
        if ((_status[id] ?? '').isEmpty) _status[id] = 'present';
      }
    });
  }

  int _count(String st) => _roster.where((s) => (_status['${s['studentId']}'] ?? '') == st).length;

  Future<void> _save() async {
    final entries = <String, dynamic>{};
    var missing = 0;
    for (final s in _roster) {
      final id = '${s['studentId']}';
      final st = _status[id] ?? '';
      if (st.isEmpty) {
        missing++;
        continue;
      }
      if (st == 'half' && (_time[id] ?? '').isEmpty) {
        _toast(context, 'Choose the leaving time for ${s['name']}.', bad: true);
        return;
      }
      final reason = (_reason[id] ?? '').trim();
      entries[id] = {
        'status': st,
        if (st == 'half') 'leaveTime': _time[id],
        if (st == 'leave' && reason.isNotEmpty) 'reason': reason,
      };
    }
    if (missing > 0) {
      _toast(context, '$missing student(s) are not marked yet. Mark every student, or tap "All present" first.', bad: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await ErpApi.saveTeacherAttendance(widget.className, widget.section, entries);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
        _markedBy = '${r['markedBy'] ?? ''}';
      });
      _toast(context, 'Attendance saved.');
    } on ErpException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(context, e.message, bad: true);
    }
  }

  Widget _chip(String id, String value, String label, Color color) {
    final on = (_status[id] ?? '') == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? Colors.white : color)),
        selected: on,
        showCheckmark: false,
        selectedColor: color,
        backgroundColor: color.withAlpha(25),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => value == 'half' ? _pickHalf(id) : _set(id, value),
      ),
    );
  }

  Widget _row(Map<String, dynamic> s) {
    final id = '${s['studentId']}';
    final father = '${s['fatherName'] ?? ''}';
    final half = (_status[id] ?? '') == 'half' && (_time[id] ?? '').isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFF0F766E), borderRadius: BorderRadius.circular(12)),
                child: Text('${s['rollNo']}'.isEmpty ? '-' : '${s['rollNo']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                    if (father.isNotEmpty) Text('Father: $father', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            children: [
              _chip(id, 'present', 'Present', _green),
              _chip(id, 'absent', 'Absent', _red),
              _chip(id, 'leave', 'Leave', _amber),
              _chip(id, 'half', half ? 'Half ${_time[id]}' : 'Half', _purple),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty ? _roster : _roster.where((s) => '${s['name']} ${s['rollNo']} ${s['fatherName']}'.toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: (_loading || _error != null || _holiday || _roster.isEmpty)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(vertical: 15)),
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
                  label: Text(_saved ? 'Save changes' : 'Save attendance', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _gradHeader(context, 'Attendance - ${_classTitle(widget.className, widget.section)}', _today.isEmpty ? '' : _nice(_today)),
            if (_loading && _roster.isEmpty)
              const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _red)),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                  ],
                ),
              )
            else if (_roster.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No students in this class.', style: TextStyle(color: _muted))))
            else if (_holiday)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Today is marked as a holiday for this class.', textAlign: TextAlign.center, style: TextStyle(color: _muted))))
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill('Present ${_count('present')}', _green),
                    _Pill('Absent ${_count('absent')}', _red),
                    _Pill('Leave ${_count('leave') + _count('half')}', _amber),
                    _Pill('Not marked ${_roster.length - _count('present') - _count('absent') - _count('leave') - _count('half')}', _muted),
                    OutlinedButton.icon(onPressed: _allPresent, icon: const Icon(Icons.done_all_rounded, size: 18), label: const Text('All present')),
                  ],
                ),
              ),
              if (_saved)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text('Already saved${_markedBy.isEmpty ? '' : ' by $_markedBy'}. You can change it and save again.', style: const TextStyle(fontSize: 12, color: _muted)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name or roll number',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              for (final s in shown) _row(s),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ---------------------------------------------------------------------------
// Diary
// ---------------------------------------------------------------------------
class TeacherDiaryPage extends StatefulWidget {
  const TeacherDiaryPage({super.key, required this.className, required this.section});
  final String className;
  final String section;

  @override
  State<TeacherDiaryPage> createState() => _TeacherDiaryPageState();
}

class _TeacherDiaryPageState extends State<TeacherDiaryPage> {
  String _date = _ymd(DateTime.now());
  bool _loading = true;
  String? _error;
  List<String> _subjects = [];
  List<Map<String, dynamic>> _entries = [];

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
      final d = await ErpApi.teacherDiary(widget.className, widget.section, _date);
      if (!mounted) return;
      setState(() {
        _subjects = ((d['subjects'] as List?) ?? []).map((e) => '$e').toList();
        _entries = _list(d['entries']);
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

  void _shift(int days) {
    setState(() => _date = _ymd(_parse(_date).add(Duration(days: days))));
    _load();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _parse(_date), firstDate: DateTime(2024), lastDate: DateTime(2035));
    if (d == null) return;
    setState(() => _date = _ymd(d));
    _load();
  }

  Future<void> _edit({Map<String, dynamic>? entry, String subject = ''}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DiaryForm(subjects: _subjects, entry: entry, subject: subject),
    );
    if (result == null) return;
    try {
      await ErpApi.teacherDiarySave({
        ...result,
        'date': _date,
        'className': widget.className,
        'section': widget.section,
        if (entry != null) 'id': entry['id'],
      });
      if (!mounted) return;
      _toast(context, 'Diary saved.');
      _load();
    } on ErpException catch (e) {
      if (mounted) _toast(context, e.message, bad: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete diary entry?'),
        content: Text('${e['subject']} - ${_nice(_date)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ErpApi.teacherDiaryDelete('${e['id']}');
      if (mounted) _load();
    } on ErpException catch (x) {
      if (mounted) _toast(context, x.message, bad: true);
    }
  }

  Widget _field(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _muted, letterSpacing: .6)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: _ink, height: 1.35)),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> e) {
    final mine = e['mine'] == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 14, offset: Offset(0, 7))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: _blue.withAlpha(30), borderRadius: BorderRadius.circular(14)),
                child: Text('${e['subject']}', style: const TextStyle(color: _blue, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const Spacer(),
              if (mine) IconButton(visualDensity: VisualDensity.compact, onPressed: () => _edit(entry: e), icon: const Icon(Icons.edit_rounded, size: 20, color: _muted)),
              if (mine) IconButton(visualDensity: VisualDensity.compact, onPressed: () => _delete(e), icon: const Icon(Icons.delete_outline_rounded, size: 20, color: _red)),
            ],
          ),
          _field('Topic', '${e['topic']}'),
          _field('Classwork', '${e['classwork']}'),
          _field('Homework', '${e['homework']}'),
          _field('Note to parents', '${e['note']}'),
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Written by ${e['by']}', style: const TextStyle(fontSize: 11, color: _muted))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final have = _entries.map((e) => '${e['subject']}'.toLowerCase()).toSet();
    final missing = _subjects.where((s) => !have.contains(s.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Write diary', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _gradHeader(context, 'Diary - ${_classTitle(widget.className, widget.section)}', _nice(_date)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  IconButton.filledTonal(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(_nice(_date), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  IconButton.filledTonal(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
                ],
              ),
            ),
            if (_loading && _entries.isEmpty)
              const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _red)),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                  ],
                ),
              )
            else ...[
              if (missing.isNotEmpty && _subjects.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Not written yet:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _red)),
                      for (final s in missing) ActionChip(label: Text('$s +', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), onPressed: () => _edit(subject: s), visualDensity: VisualDensity.compact),
                    ],
                  ),
                ),
              if (_entries.isEmpty)
                const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No diary has been written for this day.', style: TextStyle(color: _muted))))
              else
                for (final e in _entries) _card(e),
            ],
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class _DiaryForm extends StatefulWidget {
  const _DiaryForm({required this.subjects, this.entry, this.subject = ''});
  final List<String> subjects;
  final Map<String, dynamic>? entry;
  final String subject;

  @override
  State<_DiaryForm> createState() => _DiaryFormState();
}

class _DiaryFormState extends State<_DiaryForm> {
  late final TextEditingController _subject = TextEditingController(text: widget.entry != null ? '${widget.entry!['subject']}' : widget.subject);
  late final TextEditingController _topic = TextEditingController(text: widget.entry != null ? '${widget.entry!['topic']}' : '');
  late final TextEditingController _classwork = TextEditingController(text: widget.entry != null ? '${widget.entry!['classwork']}' : '');
  late final TextEditingController _homework = TextEditingController(text: widget.entry != null ? '${widget.entry!['homework']}' : '');
  late final TextEditingController _note = TextEditingController(text: widget.entry != null ? '${widget.entry!['note']}' : '');
  String? _err;

  @override
  void dispose() {
    _subject.dispose();
    _topic.dispose();
    _classwork.dispose();
    _homework.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (_subject.text.trim().isEmpty) {
      setState(() => _err = 'Enter or choose the subject.');
      return;
    }
    if (_topic.text.trim().isEmpty && _classwork.text.trim().isEmpty && _homework.text.trim().isEmpty && _note.text.trim().isEmpty) {
      setState(() => _err = 'Write the topic, classwork, homework or a note.');
      return;
    }
    Navigator.pop(context, {
      'subject': _subject.text.trim(),
      'topic': _topic.text.trim(),
      'classwork': _classwork.text.trim(),
      'homework': _homework.text.trim(),
      'note': _note.text.trim(),
    });
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), isDense: true);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.entry == null ? 'Write diary' : 'Edit diary', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 12),
            TextField(controller: _subject, enabled: widget.entry == null, decoration: _dec('Subject *')),
            if (widget.entry == null && widget.subjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final s in widget.subjects) ActionChip(label: Text(s, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => _subject.text = s), visualDensity: VisualDensity.compact),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            TextField(controller: _topic, decoration: _dec('Topic covered')),
            const SizedBox(height: 10),
            TextField(controller: _classwork, minLines: 2, maxLines: 4, decoration: _dec('Classwork')),
            const SizedBox(height: 10),
            TextField(controller: _homework, minLines: 2, maxLines: 4, decoration: _dec('Homework')),
            const SizedBox(height: 10),
            TextField(controller: _note, minLines: 1, maxLines: 3, decoration: _dec('Note to parents (optional)')),
            if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: _red, fontSize: 12))),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: _submit, style: FilledButton.styleFrom(backgroundColor: _blue), child: const Text('Save'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick action cards for the teacher home screen
// ---------------------------------------------------------------------------
class TeacherQuickActions extends StatelessWidget {
  const TeacherQuickActions({super.key, required this.classes, required this.onChat});
  final List<Map<String, dynamic>> classes;
  final VoidCallback onChat;

  Future<void> _pick(BuildContext context, String what, Widget Function(String c, String s) page) async {
    if (classes.isEmpty) {
      _toast(context, 'No classes are assigned to you yet. Ask the admin to assign your classes.', bad: true);
      return;
    }
    Map<String, dynamic>? chosen;
    if (classes.length == 1) {
      chosen = classes.first;
    } else {
      chosen = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text('$what - choose a class', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final k in classes)
                      ListTile(
                        leading: const Icon(Icons.class_rounded, color: _green),
                        title: Text(_classTitle('${k['className']}', '${k['section']}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${k['students'] ?? ''} students'),
                        onTap: () => Navigator.pop(ctx, k),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (chosen == null || !context.mounted) return;
    final c = '${chosen['className']}';
    final s = '${chosen['section']}';
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page(c, s)));
  }

  Widget _card(IconData icon, Color color, String title, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withAlpha(235), color]),
          boxShadow: [BoxShadow(color: color.withAlpha(100), blurRadius: 14, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
          const Text('App version 1.3', style: TextStyle(fontSize: 10, color: _muted)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final w = (box.maxWidth - 12) / 2;
              final items = <Widget>[
                _card(Icons.fact_check_rounded, _green, 'Attendance', 'Mark today', () => _pick(context, 'Attendance', (c, s) => TeacherAttendancePage(className: c, section: s))),
                _card(Icons.menu_book_rounded, _blue, 'Diary', 'Write homework', () => _pick(context, 'Diary', (c, s) => TeacherDiaryPage(className: c, section: s))),
                _card(Icons.edit_note_rounded, const Color(0xFFEA580C), 'Marks', 'Tests and terms', () {
                  showDialog<void>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Marks entry'),
                      content: const Text('Test and semester marks entry is being added in the next update.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
                    ),
                  );
                }),
                _card(Icons.chat_bubble_rounded, const Color(0xFF0F766E), 'Chat', 'Parents and staff', onChat),
                _card(Icons.report_problem_rounded, _red, 'Complaints', 'See and answer', onChat),
              ];
              return Wrap(spacing: 12, runSpacing: 12, children: [for (final i in items) SizedBox(width: w, child: i)]);
            },
          ),
        ],
      ),
    );
  }
}
