import 'package:flutter/material.dart';

import 'change_password.dart';
import 'charts.dart';
import 'erp_api.dart';
import 'parent_attendance.dart';
import 'parent_diary.dart';
import 'parent_fees.dart';
import 'parent_results.dart';
import 'parent_common.dart';
import 'parent_notices.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _blue = Color(0xFF2563EB);
const _amber = Color(0xFFF59E0B);
const _purple = Color(0xFF9333EA);
const _teal = Color(0xFF0F766E);
const _slate = Color(0xFF64748B);
const _orange = Color(0xFFEA580C);

int _n(dynamic v) => v is num ? v.round() : (int.tryParse('${v ?? ''}') ?? 0);

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key, required this.name, required this.onChat, required this.onLogout});
  final String name;
  final VoidCallback onChat;
  final VoidCallback onLogout;

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _att;
  int _unread = 0;
  int _sel = 0;
  String? _error;
  bool _loading = true;

  List<Map<String, dynamic>> get _kids =>
      ((_data?['children'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

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
      final d = await ParentApi.children();
      var unread = 0;
      try {
        final inbox = await ParentApi.inbox();
        unread = _n(inbox['unread']);
      } on ErpException catch (_) {
        unread = 0;
      }
      if (!mounted) return;
      setState(() {
        _data = d;
        _unread = unread;
        _loading = false;
        if (_sel >= _kids.length) _sel = 0;
      });
      _loadAtt();
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

  Future<void> _loadAtt() async {
    final kids = _kids;
    if (kids.isEmpty || _sel >= kids.length) return;
    final id = '${kids[_sel]['id']}';
    try {
      final a = await ParentApi.attendance(id);
      if (!mounted || _sel >= _kids.length || '${_kids[_sel]['id']}' != id) return;
      setState(() => _att = a);
    } on ErpException catch (_) {
      // the attendance card simply stays empty
    }
  }

  void _pick(int i) {
    setState(() {
      _sel = i;
      _att = null;
    });
    _loadAtt();
  }

  // ignore: unused_element
  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  Future<void> _openNotices() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentNoticesPage()));
    if (mounted) _load();
  }

  void _openAttendance(Map<String, dynamic> k) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ParentAttendancePage(studentId: '${k['id']}', studentName: '${k['name']}')),
    );
  }

  Widget _chips() {
    final kids = _kids;
    if (kids.length < 2) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < kids.length; i++)
            GestureDetector(
              onTap: () => _pick(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _sel == i ? Colors.white : Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _sel == i ? const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))] : null,
                ),
                child: Text('${kids[i]['name']}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _sel == i ? _orange : Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _body() {
    if (_loading && _data == null) {
      return [const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))];
    }
    if (_data == null) {
      return [
        _Card(
          title: 'Could not load your children',
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
    final kids = _kids;
    if (kids.isEmpty) {
      return [const _Card(title: 'No children linked', child: Text('No active student is linked to this account. Please contact the school.', style: TextStyle(color: _muted)))];
    }
    final k = kids[_sel];
    final ov = (_att?['overall'] as Map?) ?? {};
    final ms = (_att?['monthSummary'] as Map?) ?? {};
    final pct = ov['percentPresent'];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 12) / 2;
            final cards = <Widget>[
              _Stat('Class', '${k['className']}', Icons.class_rounded, _blue, sub: '${k['name']}'),
              _Stat('Attendance', pct == null ? '—' : '$pct%', Icons.fact_check_rounded, _green, sub: 'overall'),
              _Stat('This month', 'P ${_n(ms['present'])} · A ${_n(ms['absent'])}', Icons.calendar_month_rounded, _purple, sub: 'present · absent'),
              _Stat('Notices', '$_unread', Icons.notifications_rounded, _orange, sub: 'unread'),
            ];
            return Wrap(spacing: 12, runSpacing: 12, children: [for (final c in cards) SizedBox(width: w, child: c)]);
          },
        ),
      ),
      _Card(
        title: 'Menu',
        subtitle: ('${k['classTeacher'] ?? ''}'.isEmpty ? 'For ${k['name']}' : 'For ${k['name']} - Teacher: ${k['classTeacher']}'),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 12) / 2;
            final items = <Widget>[
              _Menu('Attendance', 'Calendar and counts', Icons.fact_check_rounded, _green, onTap: () => _openAttendance(k)),
              _Menu('Notices', _unread > 0 ? '$_unread unread' : 'From the school', Icons.notifications_rounded, _blue, badge: _unread, onTap: _openNotices),
              _Menu('Fees', 'Balance and payments', Icons.payments_rounded, _amber, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ParentFeesPage(studentId: '${k['id']}', studentName: '${k['name']}')))),
              _Menu('Results', 'Published exams', Icons.workspace_premium_rounded, _purple, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ParentResultsPage(studentId: '${k['id']}', studentName: '${k['name']}')))),
              _Menu('Chat', 'Message the school', Icons.forum_rounded, _teal, onTap: widget.onChat),
              _Menu('Diary', 'Homework and classwork', Icons.menu_book_rounded, _slate, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ParentDiaryPage(studentId: '${k['id']}', studentName: '${k['name']}')))),
            ];
            return Wrap(spacing: 12, runSpacing: 12, children: [for (final c in items) SizedBox(width: w, child: c)]);
          },
        ),
      ),
    ];
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
            ParentHeader(
              title: 'Welcome, ${widget.name}',
              subtitle: 'Parent',
              bottom: _data == null ? null : _chips(),
              actions: [
                IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
                IconButton(tooltip: 'Chat', onPressed: widget.onChat, icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white)),
                IconButton(tooltip: 'Change password', onPressed: () => showChangePasswordDialog(context), icon: const Icon(Icons.lock_reset_rounded, color: Colors.white)),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () async {
                    await ErpApi.logout();
                    widget.onLogout();
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                ),
              ],
            ),
            ..._body(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, this.color, {this.sub});
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
                    Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle});
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

class _Menu extends StatelessWidget {
  const _Menu(this.label, this.sub, this.icon, this.color, {required this.onTap, this.badge = 0});
  final String label;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(color, 0.22), color, darken(color, 0.22)]),
          boxShadow: [BoxShadow(color: color.withAlpha(110), blurRadius: 16, offset: const Offset(0, 9))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(right: -16, top: -16, child: Container(width: 74, height: 74, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(36)))),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(icon, color: Colors.white, size: 26),
                        if (badge > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: Text('$badge', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
