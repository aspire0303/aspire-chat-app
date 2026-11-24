import 'package:flutter/material.dart';

import 'erp_api.dart';
import 'parent_common.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _orange = Color(0xFFEA580C);

class ParentNoticesPage extends StatefulWidget {
  const ParentNoticesPage({super.key});

  @override
  State<ParentNoticesPage> createState() => _ParentNoticesPageState();
}

class _ParentNoticesPageState extends State<ParentNoticesPage> {
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
      final d = await ParentApi.inbox();
      if (!mounted) return;
      setState(() {
        _items = ((d['messages'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  String _when(dynamic at) {
    final s = '${at ?? ''}';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  Widget _item(Map<String, dynamic> m) {
    final unread = m['read'] != true;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
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
              if (unread) Container(width: 9, height: 9, margin: const EdgeInsets.only(right: 8), decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle)),
              Expanded(child: Text('${m['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink))),
              Text(_when(m['at']), style: const TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${m['body'] ?? ''}', style: const TextStyle(color: Color(0xFF334155), height: 1.4)),
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
            ParentHeader(title: 'Notices', subtitle: '${_items.length} messages from the school', onBack: () => Navigator.of(context).pop()),
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
              const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No notices yet.', style: TextStyle(color: _muted))))
            else
              for (final m in _items) _item(m),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
