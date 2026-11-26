import 'package:flutter/material.dart';

import 'erp_api.dart';
import 'parent_common.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _orange = Color(0xFFEA580C);

class ParentDiaryPage extends StatefulWidget {
  const ParentDiaryPage({super.key, required this.studentId, required this.studentName});
  final String studentId;
  final String studentName;

  @override
  State<ParentDiaryPage> createState() => _ParentDiaryPageState();
}

class _ParentDiaryPageState extends State<ParentDiaryPage> {
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
      final d = await ErpApi.getJson('/api/mobile/parent/diary?studentId=${Uri.encodeQueryComponent(widget.studentId)}');
      if (!mounted) return;
      setState(() {
        _items = ((d['entries'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Widget _entry(Map<String, dynamic> e) {
    final teacher = '${e['teacher'] ?? ''}'.trim();
    final rows = <Widget>[];
    void add(String label, String key) {
      final t = '${e[key] ?? ''}'.trim();
      if (t.isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted)),
            const SizedBox(height: 2),
            Text(t, style: const TextStyle(color: Color(0xFF334155), height: 1.4)),
          ],
        ),
      ));
    }

    add('Topic', 'topic');
    add('Classwork', 'classwork');
    add('Homework', 'homework');
    add('Note', 'note');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${e['subject'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink, fontSize: 15)),
          if (teacher.isNotEmpty) Text('Teacher: $teacher', style: const TextStyle(fontSize: 12, color: _muted)),
          ...rows,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = <Widget>[];
    var lastDate = '';
    for (final e in _items) {
      final d = '${e['date'] ?? ''}';
      if (d != lastDate) {
        lastDate = d;
        list.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(d, style: const TextStyle(fontWeight: FontWeight.w800, color: _orange, fontSize: 13)),
        ));
      }
      list.add(_entry(e));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4EC),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ParentHeader(title: 'Diary', subtitle: '${widget.studentName} - last 14 days', onBack: () => Navigator.of(context).pop()),
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
              const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No diary entries in the last 14 days.', style: TextStyle(color: _muted))))
            else
              ...list,
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}