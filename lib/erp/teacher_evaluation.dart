import 'package:flutter/material.dart';

import 'erp_api.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _purple = Color(0xFF9333EA);
const _bg = Color(0xFFEAF5EE);

String _two(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
DateTime _parse(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

List<Map<String, dynamic>> _list(dynamic v) =>
    ((v as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class TeacherEvaluationPage extends StatefulWidget {
  const TeacherEvaluationPage({super.key});

  @override
  State<TeacherEvaluationPage> createState() => _TeacherEvaluationPageState();
}

class _TeacherEvaluationPageState extends State<TeacherEvaluationPage> {
  bool _loading = true;
  bool _busy = false;
  bool _saving = false;
  String? _error;
  List<String> _classes = [];
  final Map<String, String> _catName = {};
  String _cls = '';
  String _level = 'class';
  String _subject = '';
  String _date = _ymd(DateTime.now());
  List<String> _subjects = [];
  List<String> _cats = [];
  String _cat = '';
  List<Map<String, dynamic>> _rows = [];
  final Map<String, Map<String, String>> _vals = {};
  final Map<String, String> _max = {};
  int _gen = 0;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  void _toast(String msg, {bool bad = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bad ? _red : _green, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ErpApi.getJson('/api/mobile/teacher/evaluation');
      if (!mounted) return;
      _catName.clear();
      for (final c in _list(d['categories'])) {
        _catName['${c['id']}'] = '${c['name']}';
      }
      final classes = ((d['classes'] as List?) ?? []).map((e) => '$e').toList();
      setState(() {
        _classes = classes;
        if (_cls.isEmpty && classes.isNotEmpty) _cls = classes.first;
        _loading = false;
      });
      await _loadRows();
    } on ErpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.unauthorized ? 'Your session expired. Go back and sign in again.' : e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadRows() async {
    if (_cls.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = '/api/mobile/teacher/evaluation?cls=${Uri.encodeQueryComponent(_cls)}&date=$_date&level=$_level&subject=${Uri.encodeQueryComponent(_subject)}';
      final d = await ErpApi.getJson(url);
      if (!mounted) return;
      final subjects = ((d['subjects'] as List?) ?? []).map((e) => '$e').toList();
      if (_level == 'subject' && _subject.isEmpty && subjects.isNotEmpty) {
        setState(() {
          _subjects = subjects;
          _subject = subjects.first;
        });
        await _loadRows();
        return;
      }
      final cats = ((d['cats'] as List?) ?? []).map((e) => '$e').toList();
      final rows = _list(d['rows']);
      _vals.clear();
      _max.clear();
      for (final c in cats) {
        var mx = '10';
        for (final r in rows) {
          final m = r['max'];
          if (m is Map && m[c] != null) {
            mx = '${(m[c] as num).round()}';
            break;
          }
        }
        _max[c] = mx;
      }
      for (final r in rows) {
        final marks = (r['marks'] is Map) ? Map<String, dynamic>.from(r['marks'] as Map) : <String, dynamic>{};
        final v = <String, String>{};
        for (final c in cats) {
          final x = marks[c];
          v[c] = x is num ? x.round().toString() : '';
        }
        _vals['${r['studentId']}'] = v;
      }
      setState(() {
        _subjects = subjects;
        _cats = cats;
        _rows = rows;
        _cat = cats.contains(_cat) ? _cat : (cats.isEmpty ? '' : cats.first);
        _gen++;
        _busy = false;
      });
    } on ErpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _rows = [];
        _busy = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _parse(_date), firstDate: DateTime(2024), lastDate: DateTime.now());
    if (d == null) return;
    setState(() => _date = _ymd(d));
    _loadRows();
  }

  void _shift(int days) {
    final nd = _parse(_date).add(Duration(days: days));
    if (nd.isAfter(DateTime.now())) {
      _toast('A future date cannot be used.', bad: true);
      return;
    }
    setState(() => _date = _ymd(nd));
    _loadRows();
  }

  Future<void> _save() async {
    final maxOut = <String, dynamic>{};
    for (final c in _cats) {
      final n = int.tryParse((_max[c] ?? '10').trim());
      if (n == null || n <= 0) {
        _toast('"Out of" for ${_catName[c] ?? c} must be a whole number above 0.', bad: true);
        return;
      }
      maxOut[c] = n;
    }
    final rows = <Map<String, dynamic>>[];
    for (final r in _rows) {
      if (r['editable'] != true) continue;
      final sid = '${r['studentId']}';
      final v = _vals[sid] ?? <String, String>{};
      final marks = <String, dynamic>{};
      for (final c in _cats) {
        final t = (v[c] ?? '').trim();
        if (t.isEmpty) {
          marks[c] = null;
          continue;
        }
        final n = int.tryParse(t);
        final mx = maxOut[c] as int;
        if (n == null || n < 0 || n > mx) {
          _toast('${r['name']}: ${_catName[c] ?? c} must be a whole number from 0 to $mx.', bad: true);
          return;
        }
        marks[c] = n;
      }
      rows.add({'studentId': sid, 'marks': marks});
    }
    if (rows.isEmpty) {
      _toast('Nothing to save.', bad: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final d = await ErpApi.postJson('/api/mobile/teacher/evaluation', {
        'className': _cls,
        'section': '*',
        'date': _date,
        'level': _level,
        'subject': _subject,
        'max': maxOut,
        'rows': rows,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      final errs = ((d['errors'] as List?) ?? []).map((e) => '$e').toList();
      if (errs.isNotEmpty) {
        _toast(errs.first, bad: true);
      } else {
        _toast('Evaluation saved.');
      }
      _loadRows();
    } on ErpException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message, bad: true);
    }
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted)),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );

  Widget _row(Map<String, dynamic> r) {
    final sid = '${r['studentId']}';
    final editable = r['editable'] == true;
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
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(13)),
            child: Text(roll.isEmpty ? '-' : roll, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                if (father.isNotEmpty) Text('Father: $father', style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ),
          if (editable && _cat.isNotEmpty)
            SizedBox(
              width: 72,
              child: TextFormField(
                key: ValueKey('$sid-$_cat-$_gen'),
                initialValue: (_vals[sid] ?? const <String, String>{})[_cat] ?? '',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), hintText: '-'),
                onChanged: (v) => (_vals[sid] ??= <String, String>{})[_cat] = v,
              ),
            )
          else
            const Text('View only', style: TextStyle(fontSize: 11, color: _muted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty ? _rows : _rows.where((r) => '${r['name']} ${r['rollNo']}'.toLowerCase().contains(q)).toList();
    final canSave = !_loading && _error == null && _rows.any((r) => r['editable'] == true);
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: canSave
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(vertical: 15)),
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
                  label: const Text('Save evaluation', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(8, top + 8, 16, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF064E3B), Color(0xFF16A34A), Color(0xFF4ADE80)]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Color(0x5516A34A), blurRadius: 24, offset: Offset(0, 12))],
            ),
            child: Row(
              children: [
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                const Expanded(child: Text('Evaluation', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
          else if (_error != null && _classes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _red)),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _loadMeta, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                ],
              ),
            )
          else if (_classes.isEmpty)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No classes are assigned to you yet. Ask the admin to assign your classes.', textAlign: TextAlign.center, style: TextStyle(color: _muted))))
          else ...[
            _section('CLASS', Wrap(spacing: 8, runSpacing: 6, children: [
              for (final c in _classes)
                ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  selected: _cls == c,
                  onSelected: (_) {
                    setState(() {
                      _cls = c;
                      _subject = '';
                    });
                    _loadRows();
                  },
                ),
            ])),
            _section('TYPE', Wrap(spacing: 8, children: [
              ChoiceChip(
                label: const Text('Class evaluation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                selected: _level == 'class',
                onSelected: (_) {
                  setState(() {
                    _level = 'class';
                    _subject = '';
                  });
                  _loadRows();
                },
              ),
              ChoiceChip(
                label: const Text('Subject evaluation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                selected: _level == 'subject',
                onSelected: (_) {
                  setState(() {
                    _level = 'subject';
                    _subject = '';
                  });
                  _loadRows();
                },
              ),
            ])),
            if (_level == 'subject')
              _section(
                'SUBJECT',
                _subjects.isEmpty
                    ? const Text('No subjects are set for this class, or none are assigned to you.', style: TextStyle(color: _muted, fontSize: 12))
                    : Wrap(spacing: 8, runSpacing: 6, children: [
                        for (final s in _subjects)
                          ChoiceChip(
                            label: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            selected: _subject == s,
                            onSelected: (_) {
                              setState(() => _subject = s);
                              _loadRows();
                            },
                          ),
                      ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  IconButton.filledTonal(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
                  Expanded(child: TextButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month_rounded), label: Text(_date))),
                  IconButton.filledTonal(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
                ],
              ),
            ),
            if (_cats.isNotEmpty)
              _section('CATEGORY', Wrap(spacing: 8, runSpacing: 6, children: [
                for (final c in _cats)
                  ChoiceChip(
                    label: Text(_catName[c] ?? c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    selected: _cat == c,
                    onSelected: (_) => setState(() {
                      _cat = c;
                      _gen++;
                    }),
                  ),
              ])),
            if (_cat.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    const Text('Out of', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        key: ValueKey('max-$_cat-$_gen'),
                        initialValue: _max[_cat] ?? '10',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        onChanged: (v) => _max[_cat] = v,
                      ),
                    ),
                  ],
                ),
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
            if (_busy)
              const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _red)))
            else if (shown.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No students to show.', style: TextStyle(color: _muted))))
            else
              for (final r in shown) _row(r),
          ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}