import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'erp_api.dart';
import 'parent_common.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);
const _blue = Color(0xFF2563EB);

String _fmt(dynamic v) {
  if (v is num) return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  final n = num.tryParse('${v ?? ''}');
  if (n == null) return '-';
  return _fmt(n);
}

double? _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}');
}

Color _pctColor(double? p) {
  if (p == null) return _muted;
  if (p >= 80) return _green;
  if (p >= 60) return _blue;
  if (p >= 40) return _amber;
  return _red;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color);
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 7;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = color.withAlpha(35);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(c, r, track);
    final sweep = 2 * math.pi * (value.clamp(0, 100) / 100);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.value != value || o.color != color;
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

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: child,
      );

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withAlpha(28), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11.5)),
      );

  Widget _bar(double p, Color c) => SizedBox(
        height: 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: c.withAlpha(32)),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: p.clamp(0, 100) / 100,
                child: Container(color: c),
              ),
            ],
          ),
        ),
      );

  Widget _trendBar(Map<String, dynamic> x) {
    final p = _num(x['percent']) ?? 0;
    final c = '${x['result']}' == 'Fail' ? _red : _pctColor(p);
    final h = 120.0 * (p.clamp(0, 100) / 100);
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          SizedBox(
            height: 146,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${_fmt(p)}%', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  width: 34,
                  height: math.max(h, 4.0),
                  decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Text('${x['name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: _muted)),
        ],
      ),
    );
  }

  Widget _trend() {
    final pts = _items.where((x) => _num(x['percent']) != null).toList().reversed.toList();
    if (pts.length < 2) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progress across exams', style: TextStyle(fontWeight: FontWeight.w800, color: _ink, fontSize: 15)),
          const SizedBox(height: 2),
          const Text('Percentage in each published exam', style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final x in pts) _trendBar(x)]),
          ),
        ],
      ),
    );
  }

  Widget _subject(Map<String, dynamic> s) {
    final absent = s['absent'] == true;
    final failed = s['pass'] == false;
    final p = _num(s['percent']);
    final grade = '${s['grade'] ?? ''}'.trim();
    final marks = absent ? 'Absent' : (p == null ? 'Pending' : '${_fmt(s['obtained'])} / ${_fmt(s['total'])}');
    final c = failed ? _red : _pctColor(p);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${s['subject'] ?? ''}', style: TextStyle(color: failed ? _red : _ink, fontWeight: FontWeight.w600))),
              Text(marks, style: TextStyle(color: failed ? _red : _muted, fontWeight: FontWeight.w700)),
              SizedBox(width: 38, child: Text(grade, textAlign: TextAlign.right, style: TextStyle(color: failed ? _red : _ink, fontWeight: FontWeight.w800))),
            ],
          ),
          if (!absent && p != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(child: _bar(p, c)),
                const SizedBox(width: 8),
                SizedBox(width: 46, child: Text('${_fmt(p)}%', textAlign: TextAlign.right, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _exam(Map<String, dynamic> x) {
    final res = '${x['result'] ?? ''}';
    final percent = _num(x['percent']);
    final color = res == 'Pass' ? _green : (res == 'Fail' ? _red : _amber);
    final ringColor = res == 'Fail' ? _red : _pctColor(percent);
    final subs = ((x['subjects'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final graded = subs.where((s) => s['absent'] != true && _num(s['percent']) != null).toList();
    final passed = graded.where((s) => s['pass'] != false).length;
    final sorted = [...graded]..sort((a, b) => (_num(a['percent']) ?? 0).compareTo(_num(b['percent']) ?? 0));
    final hasSpread = sorted.length >= 2 && (_num(sorted.first['percent']) ?? 0) != (_num(sorted.last['percent']) ?? 0);
    final grade = '${x['grade'] ?? ''}'.trim();
    final pos = x['position'];
    final cnt = x['students'];
    final remark = '${x['remark'] ?? ''}'.trim();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(size: const Size(92, 92), painter: _RingPainter(percent ?? 0, ringColor)),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(percent == null ? '-' : '${_fmt(percent)}%', style: const TextStyle(fontWeight: FontWeight.w900, color: _ink, fontSize: 16)),
                        Text(grade.isEmpty ? '' : 'Grade $grade', style: const TextStyle(fontSize: 10.5, color: _muted, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
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
                    Text('${_fmt(x['obtainedMarks'])} / ${_fmt(x['totalMarks'])} marks', style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                    if (pos != null) Text('Position: $pos${cnt == null ? '' : ' of $cnt'}', style: const TextStyle(fontSize: 12, color: _muted)),
                    if (remark.isNotEmpty) Text(remark, style: const TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
            ],
          ),
          if (graded.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('Passed $passed of ${graded.length} subjects', passed == graded.length ? _green : _amber),
                if (hasSpread) _chip('Best: ${sorted.last['subject']} (${_fmt(sorted.last['percent'])}%)', _green),
                if (hasSpread) _chip('Needs attention: ${sorted.first['subject']} (${_fmt(sorted.first['percent'])}%)', _red),
              ],
            ),
          ],
          const Divider(height: 24),
          const Text('Subject-wise performance', style: TextStyle(fontWeight: FontWeight.w800, color: _ink, fontSize: 13)),
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
            else ...[
              _trend(),
              ..._items.map(_exam),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}