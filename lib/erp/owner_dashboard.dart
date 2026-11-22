import 'package:flutter/material.dart';

import 'charts.dart';
import 'erp_api.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);
const _purple = Color(0xFF9333EA);
const _blue = Color(0xFF2563EB);
const _teal = Color(0xFF0F766E);
const _slate = Color(0xFF64748B);
const _palette = [
  Color(0xFF2563EB), Color(0xFF0F766E), Color(0xFFF59E0B), Color(0xFF9333EA),
  Color(0xFFE11D48), Color(0xFF0891B2), Color(0xFF65A30D), Color(0xFFEA580C),
];

double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);
int _i(dynamic v) => _d(v).round();
String _commas(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}
String _money(double v) => v.abs() >= 1000000 ? 'Rs ${(v / 1000000).toStringAsFixed(2)}M' : 'Rs ${_commas(v.round())}';
String _shortDate(String d) => d.length >= 10 ? '${d.substring(8, 10)}/${d.substring(5, 7)}' : d;

class _Agg {
  int students = 0, staff = 0, present = 0, absent = 0, leave = 0, half = 0, oldCount = 0;
  int marked = 0, totalClasses = 0, examN = 0;
  double netFee = 0, collected = 0, badDebt = 0, examSum = 0;
  String attDate = '';
  bool isToday = true;
  final feeStatus = <String, int>{'paid': 0, 'partial': 0, 'unpaid': 0, 'unknown': 0};
  final genders = <String, int>{'male': 0, 'female': 0, 'other': 0};
  final classes = <String, int>{};
  final classAvgSum = <String, double>{};
  final classAvgN = <String, int>{};
  final grades = <String, int>{};
  final staffByRole = <String, int>{};
  final trend = <String, List<int>>{};
  final unmarked = <String>[];
}

_Agg _aggregate(List<Map<String, dynamic>> cs) {
  final a = _Agg();
  for (final c in cs) {
    a.students += _i(c['students']);
    a.staff += _i(c['staff']);
    a.netFee += _d(c['netFee']);
    final att = (c['att'] as Map?) ?? {};
    a.present += _i(att['present']);
    a.absent += _i(att['absent']);
    a.leave += _i(att['leave']);
    a.half += _i(att['half']);
    a.marked += _i(att['marked']);
    a.totalClasses += _i(att['totalClasses']);
    if (att['isToday'] == false) a.isToday = false;
    final ad = '${att['date'] ?? ''}';
    if (ad.compareTo(a.attDate) > 0) a.attDate = ad;
    for (final u in ((att['unmarked'] as List?) ?? [])) {
      a.unmarked.add('$u');
    }
    for (final t in ((att['trend'] as List?) ?? [])) {
      final m = t as Map;
      final row = a.trend.putIfAbsent('${m['date']}', () => [0, 0, 0, 0]);
      row[0] += _i(m['present']);
      row[1] += _i(m['absent']);
      row[2] += _i(m['leave']);
      row[3] += _i(m['half']);
    }
    ((c['feeStatus'] as Map?) ?? {}).forEach((k, v) => a.feeStatus['$k'] = (a.feeStatus['$k'] ?? 0) + _i(v));
    ((c['genders'] as Map?) ?? {}).forEach((k, v) => a.genders['$k'] = (a.genders['$k'] ?? 0) + _i(v));
    ((c['classes'] as Map?) ?? {}).forEach((k, v) => a.classes['$k'] = (a.classes['$k'] ?? 0) + _i(v));
    ((c['staffByRole'] as Map?) ?? {}).forEach((k, v) => a.staffByRole['$k'] = (a.staffByRole['$k'] ?? 0) + _i(v));
    final ex = (c['exams'] as Map?) ?? {};
    a.examSum += _d(ex['sum']);
    a.examN += _i(ex['n']);
    ((ex['classAvg'] as Map?) ?? {}).forEach((k, v) {
      final m = v as Map;
      a.classAvgSum['$k'] = (a.classAvgSum['$k'] ?? 0) + _d(m['s']);
      a.classAvgN['$k'] = (a.classAvgN['$k'] ?? 0) + _i(m['n']);
    });
    ((ex['grades'] as Map?) ?? {}).forEach((k, v) => a.grades['$k'] = (a.grades['$k'] ?? 0) + _i(v));
    a.collected += _d(((c['payments'] as Map?) ?? {})['collected']);
    final old = (c['oldStudents'] as Map?) ?? {};
    a.oldCount += _i(old['count']);
    a.badDebt += _d(old['badDebt']);
  }
  return a;
}
class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key, required this.onBack, required this.onLogout});
  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  int _sel = -1;
  String _owner = 'Owner';

  List<Map<String, dynamic>> get _campuses =>
      ((_data?['campuses'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

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
      final d = await ErpApi.ownerDashboard();
      final n = await ErpApi.savedName();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        if (n != null) _owner = n;
        if (_sel >= _campuses.length) _sel = -1;
      });
    } on ErpException catch (e) {
      if (e.unauthorized) {
        await ErpApi.logout();
        if (mounted) widget.onLogout();
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF0F7),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_header(context), ..._bodyWidgets(), const SizedBox(height: 28)],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final cs = _campuses;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1F4B), Color(0xFF1D4ED8), Color(0xFF38BDF8)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x551D4ED8), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: Colors.white.withAlpha(45), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.dashboard_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Owner Dashboard', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    Text('$_owner  ·  ${_data?['today'] ?? ''}', style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 12)),
                  ],
                ),
              ),
              IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
              IconButton(tooltip: 'Back to chat', onPressed: widget.onBack, icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white)),
              IconButton(
                tooltip: 'Sign out of ERP',
                onPressed: () async {
                  await ErpApi.logout();
                  widget.onLogout();
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
              ),
            ],
          ),
          if (cs.isNotEmpty) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('All campuses', _sel == -1, () => setState(() => _sel = -1)),
                  for (var i = 0; i < cs.length; i++) _chip('${cs[i]['name']}', _sel == i, () => setState(() => _sel = i)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.white.withAlpha(40),
          borderRadius: BorderRadius.circular(20),
          boxShadow: on ? const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))] : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? const Color(0xFF1D4ED8) : Colors.white)),
      ),
    );
  }

  List<Widget> _bodyWidgets() {
    if (_loading && _data == null) {
      return [const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))];
    }
    if (_data == null) {
      return [
        _Section(
          title: 'Could not load the dashboard',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_error ?? 'Unknown error', style: const TextStyle(color: _muted)),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          ),
        ),
      ];
    }

    final cs = _campuses;
    final single = _sel >= 0 && _sel < cs.length;
    final scope = single ? [cs[_sel]] : cs;
    final a = _aggregate(scope);
    final order = ((_data?['classOrder'] as List?) ?? []).map((e) => '$e').toList();
    int rank(String k) {
      final i = order.indexOf(k);
      return i < 0 ? 999 : i;
    }

    int byOrder(String x, String y) {
      final r = rank(x).compareTo(rank(y));
      return r != 0 ? r : x.compareTo(y);
    }

    final attTotal = a.present + a.absent + a.leave + a.half;
    final pct = attTotal > 0 ? (a.present * 100 / attTotal).round() : null;
    final classKeys = a.classes.keys.toList()..sort(byOrder);
    final days = a.trend.keys.toList()..sort();
    final lastDays = days.length > 14 ? days.sublist(days.length - 14) : days;
    final avgKeys = a.classAvgSum.keys.where((k) => (a.classAvgN[k] ?? 0) > 0).toList()..sort(byOrder);
    final sessions = <Map<String, dynamic>>[];
    for (final c in scope) {
      for (final s in (((c['exams'] as Map?)?['sessions'] as List?) ?? [])) {
        final m = Map<String, dynamic>.from(s as Map);
        m['_campus'] = c['name'];
        sessions.add(m);
      }
    }
    var gi = 0;
    final gradeSlices = a.grades.entries.map((e) => Slice(e.key, e.value.toDouble(), _palette[(gi++) % _palette.length])).toList();
    var ri = 0;
    final roleSlices = a.staffByRole.entries.map((e) => Slice(e.key, e.value.toDouble(), _palette[(ri++) % _palette.length])).toList();

    return [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text('Showing older data. $_error', style: const TextStyle(color: _red, fontSize: 12)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 12) / 2;
            final cards = <Widget>[
              _StatCard('Students', _commas(a.students), Icons.school_rounded, _blue, sub: 'active'),
              _StatCard('Staff', _commas(a.staff), Icons.badge_rounded, _teal, sub: a.staffByRole.entries.map((e) => '${e.value} ${e.key.toLowerCase()}').join(' · ')),
              _StatCard('Present', _commas(a.present), Icons.check_circle_rounded, _green, sub: pct == null ? 'not marked yet' : '$pct% of marked'),
              _StatCard('Absent', _commas(a.absent), Icons.cancel_rounded, _red, sub: '${a.leave} leave · ${a.half} half'),
              _StatCard('Monthly fee', _money(a.netFee), Icons.payments_rounded, _amber, sub: 'net, all students'),
              _StatCard('Collected', _money(a.collected), Icons.account_balance_wallet_rounded, _purple, sub: 'recorded payments'),
              _StatCard('Old students', _commas(a.oldCount), Icons.history_edu_rounded, _slate, sub: 'left / archived'),
              _StatCard('Bad debt', _money(a.badDebt), Icons.warning_amber_rounded, const Color(0xFFBE123C), sub: 'from old students'),
            ];
            return Wrap(spacing: 12, runSpacing: 12, children: [for (final c in cards) SizedBox(width: w, child: c)]);
          },
        ),
      ),
      if (!single && cs.length > 1) ...[
        _Section(
          title: 'Campuses and academies',
          subtitle: 'Share of students. Tap a campus below to open it.',
          child: Column(
            children: [
              DonutWithLegend(
                slices: [for (var i = 0; i < cs.length; i++) Slice('${cs[i]['name']}', _d(cs[i]['students']), _palette[i % _palette.length])],
                centerValue: _commas(a.students),
                centerLabel: 'students',
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < cs.length; i++) _campusTile(i, cs[i]),
            ],
          ),
        ),
      ],
      _Section(
        title: 'Attendance',
        subtitle: a.attDate.isEmpty ? 'No attendance marked yet' : (a.isToday ? 'Today · ${a.attDate}' : 'Latest marked · ${a.attDate}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DonutWithLegend(
              slices: [
                Slice('Present', a.present.toDouble(), _green),
                Slice('Absent', a.absent.toDouble(), _red),
                Slice('Leave', a.leave.toDouble(), _amber),
                Slice('Half leave', a.half.toDouble(), _purple),
              ],
              centerValue: pct == null ? '—' : '$pct%',
              centerLabel: 'present',
            ),
            const SizedBox(height: 12),
            Text('Classes marked: ${a.marked} of ${a.totalClasses}', style: const TextStyle(fontSize: 12, color: _muted)),
            if (single && a.unmarked.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Not marked yet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final u in a.unmarked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                      child: Text(u, style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B))),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      _Section(
        title: 'Attendance trend',
        subtitle: 'Last ${lastDays.length} marked days',
        child: lastDays.isEmpty
            ? const Text('No attendance history yet.', style: TextStyle(color: _muted))
            : TrendChart(
                labels: lastDays.map(_shortDate).toList(),
                series: [
                  LineSeries('Present', lastDays.map((d) => a.trend[d]![0].toDouble()).toList(), _green),
                  LineSeries('Absent', lastDays.map((d) => a.trend[d]![1].toDouble()).toList(), _red),
                ],
              ),
      ),
      _Section(
        title: 'Fees',
        subtitle: 'Students by fee status',
        child: Column(
          children: [
            DonutWithLegend(
              slices: [
                Slice('Paid', (a.feeStatus['paid'] ?? 0).toDouble(), _green),
                Slice('Partial', (a.feeStatus['partial'] ?? 0).toDouble(), _amber),
                Slice('Unpaid', (a.feeStatus['unpaid'] ?? 0).toDouble(), _red),
                Slice('Not set', (a.feeStatus['unknown'] ?? 0).toDouble(), _slate),
              ],
              centerValue: _commas(a.students),
              centerLabel: 'students',
            ),
            const SizedBox(height: 12),
            _row('Monthly fee (net)', _money(a.netFee)),
            _row('Collected (recorded)', _money(a.collected)),
          ],
        ),
      ),
      _Section(
        title: 'Students by class',
        child: classKeys.isEmpty
            ? const Text('No students yet.', style: TextStyle(color: _muted))
            : BarsChart(items: [for (final k in classKeys) BarItem(k, a.classes[k]!.toDouble())], color: _blue),
      ),
      if ((a.genders['male'] ?? 0) + (a.genders['female'] ?? 0) > 0)
        _Section(
          title: 'Gender',
          child: DonutWithLegend(
            slices: [
              Slice('Boys', (a.genders['male'] ?? 0).toDouble(), _blue),
              Slice('Girls', (a.genders['female'] ?? 0).toDouble(), const Color(0xFFE11D48)),
              Slice('Not set', (a.genders['other'] ?? 0).toDouble(), _slate),
            ],
            centerValue: _commas(a.students),
            centerLabel: 'students',
          ),
        ),
      _Section(
        title: 'Exam performance',
        subtitle: a.examN > 0 ? 'Overall average ${(a.examSum / a.examN).toStringAsFixed(1)}% from ${_commas(a.examN)} marks' : null,
        child: a.examN == 0
            ? const Text('No marks entered yet.', style: TextStyle(color: _muted))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Average % by class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 10),
                  BarsChart(
                    items: [
                      for (final k in avgKeys)
                        BarItem(k, a.classAvgSum[k]! / a.classAvgN[k]!, valueLabel: '${(a.classAvgSum[k]! / a.classAvgN[k]!).round()}%'),
                    ],
                    color: _teal,
                  ),
                  if (gradeSlices.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('Grades', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                    const SizedBox(height: 10),
                    DonutWithLegend(
                      slices: gradeSlices,
                      centerValue: _commas(gradeSlices.fold<int>(0, (n, s) => n + s.value.round())),
                      centerLabel: 'results',
                    ),
                  ],
                ],
              ),
      ),
      if (roleSlices.isNotEmpty)
        _Section(
          title: 'Staff',
          child: DonutWithLegend(slices: roleSlices, centerValue: _commas(a.staff), centerLabel: 'staff'),
        ),
      if (sessions.isNotEmpty)
        _Section(
          title: 'Exam sessions',
          child: Column(
            children: [
              for (final s in sessions.take(10))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.event_note_rounded, color: _blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s['name'] ?? 'Exam'}', style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                            Text(
                              '${single ? '' : '${s['_campus']} · '}${s['type'] ?? ''} · ${s['status'] ?? ''} · ${s['classes']} classes · ${s['entered']} entries',
                              style: const TextStyle(fontSize: 11, color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(fontSize: 13, color: _muted))),
            Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
          ],
        ),
      );

  Widget _campusTile(int i, Map<String, dynamic> c) {
    final att = (c['att'] as Map?) ?? {};
    final t = _i(att['present']) + _i(att['absent']) + _i(att['leave']) + _i(att['half']);
    final p = t > 0 ? '${(_i(att['present']) * 100 / t).round()}%' : '—';
    final color = _palette[i % _palette.length];
    return GestureDetector(
      onTap: () => setState(() => _sel = i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [lighten(color, 0.88), Colors.white]),
          border: Border.all(color: color.withAlpha(70)),
          boxShadow: [BoxShadow(color: color.withAlpha(40), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(color, 0.2), darken(color, 0.15)]),
              ),
              child: Icon('${c['type']}' == 'academy' ? Icons.menu_book_rounded : Icons.apartment_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                  Text(
                    '${_commas(_i(c['students']))} students · ${_i(c['staff'])} staff · present $p · collected ${_money(_d(((c['payments'] as Map?) ?? {})['collected']))}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }
}
class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon, this.color, {this.sub});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(color, 0.22), color, darken(color, 0.22)]),
        boxShadow: [BoxShadow(color: color.withAlpha(110), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(right: -18, top: -18, child: Container(width: 84, height: 84, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(36)))),
            Positioned(right: 14, bottom: -26, child: Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(22)))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                  Text(label, style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 12, fontWeight: FontWeight.w600)),
                  if (sub != null && sub!.isNotEmpty)
                    Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
            if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: const TextStyle(fontSize: 12, color: _muted))),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class OwnerLoginPage extends StatefulWidget {
  const OwnerLoginPage({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<OwnerLoginPage> createState() => _OwnerLoginPageState();
}

class _OwnerLoginPageState extends State<OwnerLoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Enter the owner email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ErpApi.ownerLogin(_email.text, _pass.text);
      if (mounted) widget.onSuccess();
    } on ErpException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B1F4B), Color(0xFF1D4ED8), Color(0xFF38BDF8)]),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 16))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Owner sign-in', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
                        const SizedBox(height: 4),
                        const Text('Aspire ERP · all campuses', style: TextStyle(color: _muted)),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(labelText: 'Owner email', prefixIcon: Icon(Icons.mail_rounded), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pass,
                          obscureText: _hide,
                          onSubmitted: (_) => _go(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(onPressed: () => setState(() => _hide = !_hide), icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded)),
                          ),
                        ),
                        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: _red, fontSize: 13))),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _go,
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: const Color(0xFF1D4ED8)),
                            child: _busy
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}