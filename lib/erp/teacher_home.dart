import 'package:flutter/material.dart';

import 'change_password.dart';
import 'charts.dart';
import 'erp_api.dart';
import 'teacher_attendance.dart';
import 'teacher_marks.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);
const _purple = Color(0xFF9333EA);
const _blue = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);
const _teal = Color(0xFF0F766E);
const _classColors = [
  Color(0xFF16A34A), Color(0xFF2563EB), Color(0xFF0F766E), Color(0xFF9333EA),
  Color(0xFFE11D48), Color(0xFF0891B2), Color(0xFFEA580C), Color(0xFF65A30D),
];

int _n(dynamic v) => v is num ? v.round() : (int.tryParse('${v ?? ''}') ?? 0);
String _classTitle(String className, String section) => section.isEmpty ? className : '$className · $section';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({
    super.key,
    required this.name,
    required this.campusName,
    required this.onChat,
    required this.onLogout,
  });
  final String name;
  final String campusName;
  final VoidCallback onChat;
  final VoidCallback onLogout;

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  List<Map<String, dynamic>> get _classes =>
      ((_data?['classes'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

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
      final d = await ErpApi.teacherHome();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
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

  Future<void> _openClass(Map<String, dynamic> c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TeacherClassPage(className: '${c['className']}', section: '${c['section']}')),
    );
    if (mounted) _load();
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  Future<void> _openMarks() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeacherMarksPage()));
  }

  Future<void> _openAttendance() async {
    final classes = _classes;
    if (classes.isEmpty) {
      _soon('Attendance (no classes are assigned to you yet)');
      return;
    }
    Map<String, dynamic>? pick;
    if (classes.length == 1) {
      pick = classes.first;
    } else {
      pick = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in classes)
                ListTile(
                  leading: const Icon(Icons.class_rounded, color: _green),
                  title: Text(_classTitle('${c['className']}', '${c['section']}')),
                  subtitle: Text('${_n(c['students'])} students'),
                  trailing: Text(
                    c['marked'] == true ? 'Marked' : 'Not marked',
                    style: TextStyle(color: c['marked'] == true ? _green : _amber, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  onTap: () => Navigator.of(ctx).pop(c),
                ),
            ],
          ),
        ),
      );
    }
    final chosen = pick;
    if (chosen == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TeacherAttendancePage(className: '${chosen['className']}', section: '${chosen['section']}')),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5EE),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_header(context), ..._body(), const SizedBox(height: 28)],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final teacher = (_data?['teacher'] as Map?) ?? {};
    final campus = '${teacher['campusName'] ?? widget.campusName}';
    final name = '${teacher['name'] ?? widget.name}';
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF16A34A), Color(0xFF4ADE80)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x5516A34A), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: Colors.white.withAlpha(45), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.cast_for_education_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('$campus  ·  ${_data?['today'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 12)),
              ],
            ),
          ),
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
    );
  }

  List<Widget> _body() {
    if (_loading && _data == null) {
      return [const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))];
    }
    if (_data == null) {
      return [
        _Card(
          title: 'Could not load your classes',
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
    final classes = _classes;
    var present = 0;
    var absent = 0;
    for (final c in classes) {
      present += _n(c['present']);
      absent += _n(c['absent']);
    }
    final total = _n(_data?['totalStudents']);
    final marked = _n(_data?['classesMarked']);
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
              _Stat('My students', '$total', Icons.groups_rounded, _blue, sub: '${classes.length} class groups'),
              _Stat('Marked today', '$marked / ${classes.length}', Icons.fact_check_rounded, _green, sub: 'attendance'),
              _Stat('Present', '$present', Icons.check_circle_rounded, _teal, sub: 'today'),
              _Stat('Absent', '$absent', Icons.cancel_rounded, _red, sub: 'today'),
            ];
            return Wrap(spacing: 12, runSpacing: 12, children: [for (final c in cards) SizedBox(width: w, child: c)]);
          },
        ),
      ),
      _Card(
        title: 'Menu',
        subtitle: 'Everything for your classes',
        child: LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 12) / 2;
            final unmarked = classes.length - marked;
            final items = <Widget>[
              _Menu(
                'Attendance',
                classes.isEmpty ? 'No classes yet' : (unmarked <= 0 ? 'All marked today' : '$unmarked to mark today'),
                Icons.fact_check_rounded,
                _green,
                badge: unmarked > 0 ? unmarked : 0,
                onTap: _openAttendance,
              ),
              _Menu('Marks Entry', 'Enter exam marks', Icons.edit_note_rounded, _blue, onTap: _openMarks),
              _Menu('Evaluation', 'Coming soon', Icons.rule_rounded, _purple, onTap: () => _soon('Evaluation entry')),
              _Menu('Results', 'Coming soon', Icons.workspace_premium_rounded, _amber, onTap: () => _soon('Results')),
              _Menu('Parent Chat', 'Coming soon', Icons.forum_rounded, _teal, onTap: () => _soon('Parent chat')),
              _Menu('Diary', 'Coming soon', Icons.menu_book_rounded, _slate, onTap: () => _soon('Diary')),
            ];
            return Wrap(spacing: 12, runSpacing: 12, children: [for (final c in items) SizedBox(width: w, child: c)]);
          },
        ),
      ),
      _Card(
        title: 'My classes',
        subtitle: 'Tap a class to see its students',
        child: classes.isEmpty
            ? const Text('No classes are assigned to you yet. Ask the admin to assign your classes.', style: TextStyle(color: _muted))
            : LayoutBuilder(
                builder: (context, box) {
                  final w = (box.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < classes.length; i++)
                        SizedBox(
                          width: w,
                          child: _ClassCard(item: classes[i], color: _classColors[i % _classColors.length], onTap: () => _openClass(classes[i])),
                        ),
                    ],
                  );
                },
              ),
      ),
    ];
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

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item, required this.color, required this.onTap});
  final Map<String, dynamic> item;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final marked = item['marked'] == true;
    final title = _classTitle('${item['className']}', '${item['section']}');
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
                    const Icon(Icons.class_rounded, color: Colors.white, size: 22),
                    const SizedBox(height: 10),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('${_n(item['students'])} students', style: TextStyle(color: Colors.white.withAlpha(225), fontSize: 12)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withAlpha(marked ? 60 : 40), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        marked ? 'P ${_n(item['present'])} · A ${_n(item['absent'])}' : 'Not marked yet',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
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

class TeacherClassPage extends StatefulWidget {
  const TeacherClassPage({super.key, required this.className, required this.section});
  final String className;
  final String section;

  @override
  State<TeacherClassPage> createState() => _TeacherClassPageState();
}

class _TeacherClassPageState extends State<TeacherClassPage> {
  List<Map<String, dynamic>> _students = [];
  String? _error;
  bool _loading = true;
  String _q = '';

  static const _labels = <String, String>{
    'present': 'Present',
    'absent': 'Absent',
    'leave': 'Leave',
    'half': 'Half leave',
    'holiday': 'Holiday',
  };

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
      final d = await ErpApi.teacherStudents(widget.className, widget.section);
      if (!mounted) return;
      setState(() {
        _students = ((d['students'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Color _statusColor(String s) {
    switch (s) {
      case 'present':
        return _green;
      case 'absent':
        return _red;
      case 'leave':
        return _amber;
      case 'half':
        return _purple;
      case 'holiday':
        return _blue;
      default:
        return _slate;
    }
  }

  Widget _pill(String text, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? Colors.white.withAlpha(50) : color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: filled ? Colors.white : color)),
    );
  }

  Widget _row(Map<String, dynamic> s) {
    final st = '${s['status'] ?? ''}';
    final color = _statusColor(st);
    final father = '${s['fatherName'] ?? ''}';
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [lighten(_teal, 0.2), darken(_teal, 0.15)]),
            ),
            child: Text('${s['rollNo']}'.isEmpty ? '-' : '${s['rollNo']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                if (father.isNotEmpty) Text('Father: $father', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ),
          _pill(_labels[st] ?? 'Not marked', color),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final title = _classTitle(widget.className, widget.section);
    final counts = <String, int>{};
    for (final s in _students) {
      final k = '${s['status'] ?? ''}';
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? _students
        : _students.where((s) => '${s['name']} ${s['rollNo']} ${s['fatherName']}'.toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5EE),
      body: RefreshIndicator(
        onRefresh: _load,
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
                            Text('${_students.length} students', style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _pill('Present ${counts['present'] ?? 0}', Colors.white, filled: true),
                        _pill('Absent ${counts['absent'] ?? 0}', Colors.white, filled: true),
                        _pill('Leave ${(counts['leave'] ?? 0) + (counts['half'] ?? 0)}', Colors.white, filled: true),
                        _pill('Not marked ${counts[''] ?? 0}', Colors.white, filled: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
            if (_loading && _students.isEmpty)
              const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _students.isEmpty)
              _Card(
                title: 'Could not load students',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!, style: const TextStyle(color: _muted)),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                  ],
                ),
              )
            else if (shown.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No students found.', style: TextStyle(color: _muted))))
            else
              for (final s in shown) _row(s),
            const SizedBox(height: 28),
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
