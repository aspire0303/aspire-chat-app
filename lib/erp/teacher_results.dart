import 'package:flutter/material.dart';

import 'erp_api.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);
const _teal = Color(0xFF0F766E);

String _fmt(dynamic v) {
  final n = v is num ? v : num.tryParse('${v ?? ''}');
  if (n == null) return '-';
  return n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);
}

List<Map<String, dynamic>> _list(dynamic v) =>
    ((v as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class TeacherResultsPage extends StatefulWidget {
  const TeacherResultsPage({super.key});

  @override
  State<TeacherResultsPage> createState() => _TeacherResultsPageState();
}

class _TeacherResultsPageState extends State<TeacherResultsPage> {
  List<Map<String, dynamic>> _exams = [];
  List<String> _classes = [];
  String _examId = '';
  String _cls = '';
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ErpApi.getJson('/api/mobile/teacher/results');
      if (!mounted) return;
      final exams = _list(d['exams']);
      final classes = ((d['classes'] as List?) ?? []).map((e) => '$e').toList();
      setState(() {
        _exams = exams;
        _classes = classes;
        if (_examId.isEmpty && exams.isNotEmpty) _examId = '${exams.first['id']}';
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
    if (_examId.isEmpty || _cls.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await ErpApi.getJson('/api/mobile/teacher/results?examId=${Uri.encodeQueryComponent(_examId)}&cls=${Uri.encodeQueryComponent(_cls)}');
      if (!mounted) return;
      setState(() {
        _rows = _list(d['results']);
        _stats = Map<String, dynamic>.from((d['stats'] as Map?) ?? {});
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

  Widget _chips(String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: chips),
          ],
        ),
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _row(Map<String, dynamic> r) {
    final res = '${r['result'] ?? ''}';
    final color = res == 'Pass' ? _green : (res == 'Fail' ? _red : _amber);
    final label = res == 'Fail' ? 'Needs work' : res;
    final pos = r['position'];
    final grade = '${r['grade'] ?? ''}'.trim();
    final pct = r['percent'] == null ? '-' : '${_fmt(r['percent'])}%';
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
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(14)),
            child: Text('${r['rollNo']}'.isEmpty ? '-' : '${r['rollNo']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                Text('${_fmt(r['obtainedMarks'])} / ${_fmt(r['totalMarks'])}  -  $pct  -  Grade ${grade.isEmpty ? '-' : grade}', style: const TextStyle(fontSize: 12, color: _muted)),
                if (pos != null) Text('Position $pos', style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ),
          if (label.isNotEmpty) _pill(label, color),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty ? _rows : _rows.where((r) => '${r['name']} ${r['rollNo']}'.toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5EE),
      body: RefreshIndicator(
        onRefresh: _loadMeta,
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
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                  const Expanded(child: Text('Results', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
                ],
              ),
            ),
            if (_loading && _exams.isEmpty)
              const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _exams.isEmpty)
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
            else if (_exams.isEmpty)
              const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No exams found for your classes.', style: TextStyle(color: _muted))))
            else ...[
              _chips('EXAM', [
                for (final e in _exams)
                  ChoiceChip(
                    label: Text('${e['name']} (${e['status']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    selected: _examId == '${e['id']}',
                    onSelected: (_) {
                      setState(() => _examId = '${e['id']}');
                      _loadRows();
                    },
                  ),
              ]),
              _chips('CLASS', [
                for (final c in _classes)
                  ChoiceChip(
                    label: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    selected: _cls == c,
                    onSelected: (_) {
                      setState(() => _cls = c);
                      _loadRows();
                    },
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _pill('Students ${_fmt(_stats['students'])}', _teal),
                    _pill('Passed ${_fmt(_stats['passed'])}', _green),
                    _pill('Average ${_stats['average'] == null ? '-' : '${_fmt(_stats['average'])}%'}', _amber),
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
                const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _red)))
              else if (shown.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No results yet for this exam and class.', style: TextStyle(color: _muted))))
              else
                for (final r in shown) _row(r),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}