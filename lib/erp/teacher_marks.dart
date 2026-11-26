import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'charts.dart';
import 'erp_api.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);
const _blue = Color(0xFF2563EB);
const _teal = Color(0xFF0F766E);
const _colors = [
  Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFF9333EA),
  Color(0xFFEA580C), Color(0xFF0891B2), Color(0xFFE11D48),
];

double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);
int _n(dynamic v) => _d(v).round();
String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle, this.bottom});
  final String title;
  final String? subtitle;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 8, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF60A5FA)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x552563EB), blurRadius: 24, offset: Offset(0, 12))],
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
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 10), Padding(padding: const EdgeInsets.only(left: 8), child: bottom!)],
        ],
      ),
    );
  }
}

Widget _pill(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
  );
}

Widget _card({required Widget child}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    ),
  );
}

Widget _errorBox(String message, VoidCallback retry) {
  return _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: _muted)),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      ],
    ),
  );
}

// ---------------------------------------------------------------- 1. choose the exam

class TeacherMarksPage extends StatefulWidget {
  const TeacherMarksPage({super.key});

  @override
  State<TeacherMarksPage> createState() => _TeacherMarksPageState();
}

class _TeacherMarksPageState extends State<TeacherMarksPage> {
  List<Map<String, dynamic>> _exams = [];
  List<String> _classes = [];
  String? _error;
  bool _loading = true;

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
      final d = await ErpApi.marksExams();
      if (!mounted) return;
      setState(() {
        _exams = ((d['exams'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _classes = ((d['classes'] as List?) ?? []).map((e) => '$e').toList();
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

  Widget _examCard(Map<String, dynamic> e, int i) {
    final color = _colors[i % _colors.length];
    final locked = e['locked'] == true;
    final start = '${e['startDate'] ?? ''}';
    final end = '${e['endDate'] ?? ''}';
    final dates = [if (start.isNotEmpty) start, if (end.isNotEmpty) end].join(' to ');
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ExamClassPage(exam: e, classes: _classes))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(color, 0.22), color, darken(color, 0.22)]),
          boxShadow: [BoxShadow(color: color.withAlpha(110), blurRadius: 16, offset: const Offset(0, 9))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e['name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  if (dates.isNotEmpty) Text(dates, style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _pill('${e['status']}'),
                if (locked) const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.lock_rounded, color: Colors.white, size: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF0FA),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _Header(title: 'Marks Entry', subtitle: 'Choose an exam'),
            if (_loading && _exams.isEmpty)
              const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _exams.isEmpty)
              _errorBox(_error!, _load)
            else if (_classes.isEmpty)
              const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No classes are assigned to you yet. Ask the admin to assign your classes.', textAlign: TextAlign.center, style: TextStyle(color: _muted))))
            else if (_exams.isEmpty)
              const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No exams are open for your classes yet.', style: TextStyle(color: _muted))))
            else
              for (var i = 0; i < _exams.length; i++) _examCard(_exams[i], i),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 2. choose class and subject

class _ExamClassPage extends StatefulWidget {
  const _ExamClassPage({required this.exam, required this.classes});
  final Map<String, dynamic> exam;
  final List<String> classes;

  @override
  State<_ExamClassPage> createState() => _ExamClassPageState();
}

class _ExamClassPageState extends State<_ExamClassPage> {
  String _cls = '';
  List<String> _subjects = [];
  Map<String, dynamic> _progress = {};
  bool _locked = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cls = widget.classes.isEmpty ? '' : widget.classes.first;
    if (_cls.isEmpty) {
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ErpApi.marksSubjects('${widget.exam['id']}', _cls);
      if (!mounted) return;
      setState(() {
        _subjects = ((d['subjects'] as List?) ?? []).map((e) => '$e').toList();
        _progress = Map<String, dynamic>.from((d['progress'] as Map?) ?? {});
        _locked = d['locked'] == true;
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

  void _pickClass(String c) {
    if (c == _cls) return;
    setState(() {
      _cls = c;
      _subjects = [];
      _progress = {};
    });
    _load();
  }

  Future<void> _open(String subject) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MarksEntryPage(examId: '${widget.exam['id']}', examName: '${widget.exam['name']}', className: _cls, subject: subject),
      ),
    );
    if (mounted) _load();
  }

  Widget _tile(String sj, int i) {
    final pr = (_progress[sj] as Map?) ?? {};
    final entered = _n(pr['entered']);
    final total = _n(pr['total']);
    final frac = total > 0 ? entered / total : 0.0;
    final color = _colors[i % _colors.length];
    return GestureDetector(
      onTap: () => _open(sj),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(color, 0.2), darken(color, 0.15)]),
                boxShadow: [BoxShadow(color: color.withAlpha(90), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sj, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: frac, minHeight: 6, color: color, backgroundColor: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 4),
                  Text('$entered of $total students entered', style: const TextStyle(fontSize: 11, color: _muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF0FA),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _Header(title: '${widget.exam['name']}', subtitle: 'Choose class and subject'),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Class', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in widget.classes)
                        ChoiceChip(label: Text(c), selected: c == _cls, selectedColor: lighten(_blue, 0.7), onSelected: (_) => _pickClass(c)),
                    ],
                  ),
                ],
              ),
            ),
            if (_locked)
              _card(
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded, color: _amber),
                    SizedBox(width: 10),
                    Expanded(child: Text('This exam is published. Marks can be viewed but not changed. Ask an admin to reopen it.', style: TextStyle(color: _muted, fontSize: 12))),
                  ],
                ),
              ),
            if (_loading && _subjects.isEmpty)
              const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _subjects.isEmpty)
              _errorBox(_error!, _load)
            else if (_subjects.isEmpty)
              const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No subjects are open for you in this class and exam.', textAlign: TextAlign.center, style: TextStyle(color: _muted))))
            else
              for (var i = 0; i < _subjects.length; i++) _tile(_subjects[i], i),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 3. enter the marks

class _MarksEntryPage extends StatefulWidget {
  const _MarksEntryPage({required this.examId, required this.examName, required this.className, required this.subject});
  final String examId;
  final String examName;
  final String className;
  final String subject;

  @override
  State<_MarksEntryPage> createState() => _MarksEntryPageState();
}

class _MarksEntryPageState extends State<_MarksEntryPage> {
  List<Map<String, dynamic>> _rows = [];
  final Map<String, TextEditingController> _ctl = {};
  final Map<String, bool> _abs = {};
  final TextEditingController _total = TextEditingController();
  bool _locked = false;
  bool _totalFixed = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    _total.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ErpApi.marksSheet(widget.examId, widget.className, widget.subject);
      final rows = ((d['rows'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      for (final r in rows) {
        final id = '${r['studentId']}';
        final ob = r['obtained'];
        final text = ob is num ? _num(ob.toDouble()) : '';
        final c = _ctl[id];
        if (c == null) {
          _ctl[id] = TextEditingController(text: text);
        } else {
          c.text = text;
        }
        _abs[id] = r['absent'] == true;
      }
      final total = d['total'];
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _locked = d['locked'] == true;
        _totalFixed = total is num;
        if (total is num) _total.text = _num(total.toDouble());
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

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    final total = _parse(_total.text);
    if (total == null || total <= 0) {
      _snack('Enter the total marks first.');
      return;
    }
    final rows = <Map<String, dynamic>>[];
    var bad = 0;
    for (final r in _rows) {
      final id = '${r['studentId']}';
      final absent = _abs[id] == true;
      final t = (_ctl[id]?.text ?? '').trim();
      if (absent) {
        rows.add({'studentId': id, 'obtained': null, 'absent': true});
      } else if (t.isEmpty) {
        rows.add({'studentId': id, 'obtained': null, 'absent': false});
      } else {
        final v = _parse(t);
        if (v == null || v < 0 || v > total) {
          bad++;
          continue;
        }
        rows.add({'studentId': id, 'obtained': v, 'absent': false});
      }
    }
    if (bad > 0) {
      _snack('$bad student(s) have marks outside 0 to ${_num(total)}. Fix the red boxes.');
      return;
    }
    setState(() => _saving = true);
    try {
      final d = await ErpApi.saveMarks(
        examId: widget.examId,
        className: widget.className,
        subject: widget.subject,
        total: total,
        rows: rows,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      final errs = ((d['errors'] as List?) ?? []).map((e) => '$e').toList();
      if (errs.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Some marks were not saved'),
            content: SingleChildScrollView(child: Text(errs.join('\n'))),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
          ),
        );
        return;
      }
      _snack('Marks saved.');
      if (mounted) Navigator.of(context).pop(true);
    } on ErpException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.message);
    }
  }

  Widget _row(Map<String, dynamic> r) {
    final id = '${r['studentId']}';
    final c = _ctl[id] ?? TextEditingController();
    final absent = _abs[id] == true;
    final total = _parse(_total.text);
    final v = _parse(c.text);
    final over = !absent && v != null && total != null && (v > total || v < 0);
    final father = '${r['fatherName'] ?? ''}';
    final roll = '${r['rollNo'] ?? ''}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Row(
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
                Text('${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                if (father.isNotEmpty) Text('Father: $father', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            child: TextField(
              controller: c,
              enabled: !absent && !_locked,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: absent ? 'Abs' : '—',
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: over ? _red : const Color(0xFFCBD5E1), width: over ? 2 : 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _locked
                ? null
                : () => setState(() {
                      _abs[id] = !absent;
                      if (!absent) c.clear();
                    }),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: absent ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(_red, 0.2), darken(_red, 0.15)]) : null,
                color: absent ? null : _red.withAlpha(25),
              ),
              child: Text('Abs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: absent ? Colors.white : _red)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var entered = 0;
    var absent = 0;
    var blank = 0;
    for (final r in _rows) {
      final id = '${r['studentId']}';
      if (_abs[id] == true) {
        absent++;
      } else if ((_ctl[id]?.text ?? '').trim().isEmpty) {
        blank++;
      } else {
        entered++;
      }
    }
    final canSave = !_loading && !_locked && _rows.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFEAF0FA),
      bottomNavigationBar: canSave
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x220F172A), blurRadius: 14, offset: Offset(0, -4))]),
                child: Row(
                  children: [
                    Expanded(child: Text(blank > 0 ? '$blank student(s) left blank' : 'All students have marks.', style: TextStyle(fontSize: 12, color: blank > 0 ? _amber : _muted, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(backgroundColor: _blue, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: const Text('Save marks'),
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
            _Header(
              title: widget.subject,
              subtitle: '${widget.examName}  ·  ${widget.className}',
              bottom: Wrap(spacing: 8, runSpacing: 6, children: [_pill('Entered $entered'), _pill('Absent $absent'), _pill('Blank $blank')]),
            ),
            if (_loading && _rows.isEmpty)
              const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _rows.isEmpty)
              _errorBox(_error!, _load)
            else if (_rows.isEmpty)
              const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No students take this subject in this class.', style: TextStyle(color: _muted))))
            else ...[
              if (_locked)
                _card(
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, color: _amber),
                      SizedBox(width: 10),
                      Expanded(child: Text('This exam is published, so marks are read only. Ask an admin to reopen it.', style: TextStyle(color: _muted, fontSize: 12))),
                    ],
                  ),
                ),
              _card(
                child: Row(
                  children: [
                    const Expanded(child: Text('Total marks', style: TextStyle(fontWeight: FontWeight.w800, color: _ink))),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _total,
                        enabled: !_totalFixed && !_locked,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(isDense: true, hintText: 'e.g. 50', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),
              ),
              if (_totalFixed)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Text('Total marks come from the date sheet. An admin can change them there.', style: TextStyle(fontSize: 11, color: _muted)),
                ),
              for (final r in _rows) _row(r),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
