import 'package:flutter/material.dart';

import 'erp_api.dart';
import 'parent_common.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);

String _fmt(dynamic v) {
  if (v is num) return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  final n = num.tryParse('${v ?? ''}');
  if (n == null) return '-';
  return _fmt(n);
}

class ParentResultsPage extends StatefulWidget {
  const ParentResultsPage({super.key, required this.studentId, required this.studentName});
  final String studentId;
  final String studentName;

  @override
  State<ParentResultsPage> createState() => _ParentResultsPageState();
}

class _ParentResultsPageState extends State<ParentResultsPage> {
  List<Map<String, dynamic>> _items = [];
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
      final d = await ErpApi.getJson('/api/mobile/parent/results?studentId=${Uri.encodeQueryComponent(widget.studentId)}');
      if (!mounted) return;
      setState(() {
        _items = ((d['exams'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Widget _subject(Map<String, dynamic> s) {
    final absent = s['absent'] == true;
    final failed = s['pass'] == false;
    final grade = '${s['grade'] ?? ''}'.trim();
    final marks = absent ? 'Absent' : (s['percent'] == null ? 'Pending' : '${_fmt(s['obtained'])} / ${_fmt(s['total'])}');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text('${s['subject'] ?? ''}', style: TextStyle(color: failed ? _red : _ink, fontWeight: FontWeight.w600))),
          Text(marks, style: TextStyle(color: failed ? _red : _muted, fontWeight: FontWeight.w700)),
          SizedBox(width: 38, child: Text(grade, textAlign: TextAlign.right, style: TextStyle(color: failed ? _red : _ink, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _exam(Map<String, dynamic> x) {
    final res = '${x['result'] ?? ''}';
    final color = res == 'Pass' ? _green : (res == 'Fail' ? _red : _amber);
    final subs = ((x['subjects'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final pos = x['position'];
    final cnt = x['students'];
    final remark = '${x['remark'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${x['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink, fontSize: 15))),
              if (res.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                  child: Text(res, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_fmt(x['obtainedMarks'])} / ${_fmt(x['totalMarks'])}  -  ${x['percent'] == null ? '-' : '${_fmt(x['percent'])}%'}  -  Grade ${'${x['grade'] ?? ''}'.isEmpty ? '-' : x['grade']}',
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
          if (pos != null) Text('Position: $pos${cnt == null ? '' : ' of $cnt'}', style: const TextStyle(fontSize: 12, color: _muted)),
          if (remark.isNotEmpty) Text(remark, style: const TextStyle(fontSize: 12, color: _muted)),
          const Divider(height: 22),
          ...subs.map(_subject),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4EC),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ParentHeader(title: 'Results', subtitle: widget.studentName, onBack: () => Navigator.of(context).pop()),
            if (_loading && _items.isEmpty)
              const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: _muted)),
                    const SizedBox(height: 10),
                    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                  ],
                ),
              )
            else if (_items.isEmpty)
              const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No published results yet. They appear here once the school publishes them.', textAlign: TextAlign.center, style: TextStyle(color: _muted))))
            else
              ..._items.map(_exam),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}