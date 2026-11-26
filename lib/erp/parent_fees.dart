import 'package:flutter/material.dart';

import 'erp_api.dart';
import 'parent_common.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);

num _num(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);
String _rs(dynamic v) => 'Rs ${_num(v).round()}';

class ParentFeesPage extends StatefulWidget {
  const ParentFeesPage({super.key, required this.studentId, required this.studentName});
  final String studentId;
  final String studentName;

  @override
  State<ParentFeesPage> createState() => _ParentFeesPageState();
}

class _ParentFeesPageState extends State<ParentFeesPage> {
  Map<String, dynamic>? _d;
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
      final d = await ErpApi.getJson('/api/mobile/parent/fees?studentId=${Uri.encodeQueryComponent(widget.studentId)}');
      if (!mounted) return;
      setState(() {
        _d = d;
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

  List<Map<String, dynamic>> _list(String key) =>
      ((_d?[key] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Widget _box(Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: child,
      );

  Widget _summary() {
    final bal = _num(_d?['balance']);
    final due = bal > 0;
    final color = due ? _red : _green;
    return _box(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(due ? 'Balance due' : (bal < 0 ? 'Advance paid' : 'No dues'), style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(_rs(bal.abs()), style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text('Billed: ${_rs(_d?['totalBilled'])}   Paid: ${_rs(_d?['totalPaid'])}', style: const TextStyle(color: _muted, fontSize: 12.5)),
      ],
    ));
  }

  Widget _invoice(Map<String, dynamic> i) {
    final lines = ((i['lines'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final disc = _num(i['discount']);
    return _box(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('${i['month'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink))),
            Text(_rs(i['net']), style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
          ],
        ),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(child: Text('${l['name'] ?? ''}', style: const TextStyle(color: _muted, fontSize: 12.5))),
                Text(_rs(l['amount']), style: const TextStyle(color: _muted, fontSize: 12.5)),
              ],
            ),
          ),
        if (disc > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Expanded(child: Text('Discount', style: TextStyle(color: _muted, fontSize: 12.5))),
                Text('- ${_rs(disc)}', style: const TextStyle(color: _muted, fontSize: 12.5)),
              ],
            ),
          ),
      ],
    ));
  }

  Widget _payment(Map<String, dynamic> p) {
    final receipt = '${p['receiptNo'] ?? ''}';
    final method = '${p['method'] ?? ''}';
    final sub = [if (receipt.isNotEmpty) 'Receipt $receipt', if (method.isNotEmpty) method].join(' - ');
    return _box(Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p['date'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
              if (sub.isNotEmpty) Text(sub, style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ),
        Text(_rs(p['amount']), style: const TextStyle(fontWeight: FontWeight.w800, color: _green)),
      ],
    ));
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink, fontSize: 15)),
      );

  @override
  Widget build(BuildContext context) {
    final inv = _list('invoices');
    final pay = _list('payments');
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4EC),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ParentHeader(title: 'Fees', subtitle: widget.studentName, onBack: () => Navigator.of(context).pop()),
            if (_loading && _d == null)
              const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _d == null)
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
            else ...[
              _summary(),
              _title('Payments'),
              if (pay.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(20, 10, 20, 0), child: Text('No payments recorded.', style: TextStyle(color: _muted))),
              ...pay.map(_payment),
              _title('Invoices'),
              if (inv.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(20, 10, 20, 0), child: Text('No invoices yet.', style: TextStyle(color: _muted))),
              ...inv.map(_invoice),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}