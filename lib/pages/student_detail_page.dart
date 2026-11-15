import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_user.dart';
import '../data_utils.dart';
import '../util.dart';

const Color _teal = Color(0xFF0F766E);
const Color _green = Color(0xFF16A34A);
const Color _red = Color(0xFFDC2626);
const Color _amber = Color(0xFFF59E0B);
const Color _indigo = Color(0xFF6366F1);

class StudentDetailPage extends StatelessWidget {
  const StudentDetailPage({
    super.key,
    required this.me,
    required this.studentId,
    required this.name,
    required this.subtitle,
  });

  final AppUser me;
  final String studentId;
  final String name;
  final String subtitle;

  bool get _canSeeFees => me.isAdmin || me.role == 'parent';

  String _updated(dynamic ts) {
    if (ts is Timestamp) {
      final t = ts.toDate();
      return '${dayLabel(t)}, ${timeLabel(t)}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cards = FirebaseFirestore.instance.collection('v2_cards').doc(studentId).snapshots();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (subtitle.isNotEmpty)
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_canSeeFees) _FeeSection(studentId: studentId),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: cards,
            builder: (context, snap) {
              if (snap.hasError) {
                return _InfoBox('Could not load records.\n${snap.error}');
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final d = snap.data!.data();
              if (d == null) {
                return const _InfoBox('No attendance or marks have been synced for this student yet.');
              }
              final att = asMap(d['attendance']);
              final exams = asList(d['exams']);
              final tests = asMap(d['tests']);
              final upcoming = asList(d['upcoming']);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AttendanceCard(att: att),
                  if (upcoming.isNotEmpty) _UpcomingCard(rows: upcoming),
                  if (exams.isEmpty)
                    const _CardShell(
                      title: 'Marks and results',
                      icon: Icons.grading,
                      color: Color(0xFFEC4899),
                      child: Text('No published results yet.'),
                    ),
                  for (final e in exams) _ExamCard(exam: asMap(e)),
                  if (tests.isNotEmpty) _TestsCard(tests: tests),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _updated(d['updatedAt']).isEmpty
                          ? 'Synced from school records'
                          : 'Synced from school records: ${_updated(d['updatedAt'])}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFF1F4F5),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ---------------------------------------------------------------- fees

class _FeeSection extends StatelessWidget {
  const _FeeSection({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance.collection('v2_fees').doc(studentId).snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _CardShell(
            title: 'Fee',
            icon: Icons.payments_outlined,
            color: _amber,
            child: Text('Could not load fee details.\n${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final d = snap.data!.data();
        if (d == null) {
          return const _CardShell(
            title: 'Fee',
            icon: Icons.payments_outlined,
            color: _amber,
            child: Text('Fee details are not available yet.'),
          );
        }
        final fees = asMap(d['fees']);
        final balance = asNum(fees['balance']) ?? 0;
        final unpaid = asList(fees['unpaid']);
        final last = asList(fees['last']);
        final due = balance > 0;
        return _CardShell(
          title: 'Fee',
          icon: Icons.payments_outlined,
          color: _amber,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                due ? rs(balance) : 'No dues',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: due ? _red : _green),
              ),
              Text(due ? 'is due' : 'All fees are cleared',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Stat('Charged', rs(asNum(fees['charged'])))),
                  Expanded(child: _Stat('Paid', rs(asNum(fees['paid'])))),
                ],
              ),
              if (unpaid.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Unpaid months', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final u in unpaid)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text(monthLabelYm(asStr(asMap(u)['month'])))),
                        Text(rs(asNum(asMap(u)['balance'])),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: _red)),
                      ],
                    ),
                  ),
              ],
              if (last.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Recent payments', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final p in last)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${fmtIso(asStr(asMap(p)['date']))} · Receipt ${asStr(asMap(p)['receiptNo'])}'
                            '${asStr(asMap(p)['method']).isEmpty ? '' : ' · ${asStr(asMap(p)['method'])}'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(rs(asNum(asMap(p)['amount'])),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: _green)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ---------------------------------------------------------- attendance

Color _statusColor(String s) {
  switch (s) {
    case 'present':
      return _green;
    case 'absent':
      return _red;
    case 'leave':
      return _amber;
    case 'half':
      return _indigo;
    default:
      return Colors.grey;
  }
}

String _statusLetter(String s) {
  switch (s) {
    case 'present':
      return 'P';
    case 'absent':
      return 'A';
    case 'leave':
      return 'L';
    case 'half':
      return 'H';
    default:
      return '-';
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.att});

  final Map<String, dynamic> att;

  @override
  Widget build(BuildContext context) {
    if (att.isEmpty) {
      return const _CardShell(
        title: 'Attendance',
        icon: Icons.check_circle_outline,
        color: _green,
        child: Text('No attendance has been marked yet.'),
      );
    }
    final today = asStr(att['today']);
    final todayText = today.isEmpty
        ? 'Not marked yet today'
        : today == 'holiday'
            ? 'Holiday today'
            : 'Today: ${today[0].toUpperCase()}${today.substring(1)}';
    final percent = asNum(att['percent']);
    final recent = asList(att['recent']);
    return _CardShell(
      title: 'Attendance · ${monthLabelYm(asStr(att['month']))}',
      icon: Icons.check_circle_outline,
      color: _green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(percent == null ? '-' : pct(percent),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text('this month', style: TextStyle(color: Colors.black54)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill('Present ${asStr(att['present'])}', _green),
              _Pill('Absent ${asStr(att['absent'])}', _red),
              _Pill('Leave ${asStr(att['leave'])}', _amber),
              if ((asNum(att['half']) ?? 0) > 0) _Pill('Half ${asStr(att['half'])}', _indigo),
            ],
          ),
          const SizedBox(height: 10),
          Text(todayText, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Recent days', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in recent)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${DateTime.tryParse(asStr(asMap(r)['date']))?.day ?? ''}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: _statusColor(asStr(asMap(r)['status'])),
                        child: Text(
                          _statusLetter(asStr(asMap(r)['status'])),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- marks

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam});

  final Map<String, dynamic> exam;

  @override
  Widget build(BuildContext context) {
    final res = asMap(exam['result']);
    final subjects = asList(res['subjects']);
    final result = asStr(res['result']);
    final resultColor = result == 'Pass'
        ? _green
        : result == 'Fail'
            ? _red
            : Colors.grey;
    final position = asNum(res['position']);
    final classSize = asNum(exam['classSize']);
    final summary = <String>[
      '${marksText(asNum(res['obtainedMarks']))}/${marksText(asNum(res['totalMarks']))}',
      pct(asNum(res['percent'])),
      if (asStr(res['grade']).isNotEmpty && asStr(res['grade']) != '-') 'Grade ${asStr(res['grade'])}',
    ];
    return _CardShell(
      title: asStr(exam['name']),
      icon: Icons.grading,
      color: const Color(0xFFEC4899),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(summary.join(' · '),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (result.isNotEmpty) _Pill(result, resultColor),
            ],
          ),
          if (position != null && classSize != null && classSize > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Position ${position.round()} of ${classSize.round()}',
                  style: const TextStyle(color: Colors.black54)),
            ),
          if (asStr(res['remark']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(asStr(res['remark']), style: const TextStyle(color: Colors.black54)),
            ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          for (final s in subjects) _SubjectRow(s: asMap(s)),
          if ((asNum(res['pendingCount']) ?? 0) > 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Some subjects are still being marked.',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.s});

  final Map<String, dynamic> s;

  @override
  Widget build(BuildContext context) {
    final total = asNum(s['total']) ?? 0;
    final failed = s['pass'] == false;
    final color = failed ? _red : Colors.black87;
    final pending = total == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(asStr(s['subject']), style: TextStyle(color: color))),
          SizedBox(
            width: 84,
            child: Text(
              pending ? 'pending' : '${marksText(asNum(s['obtained']))}/${marksText(total)}',
              textAlign: TextAlign.right,
              style: TextStyle(color: pending ? Colors.black45 : color),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(pending ? '' : pct(asNum(s['percent'])),
                textAlign: TextAlign.right, style: TextStyle(color: color)),
          ),
          SizedBox(
            width: 36,
            child: Text(pending ? '' : asStr(s['grade']),
                textAlign: TextAlign.right,
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TestsCard extends StatelessWidget {
  const _TestsCard({required this.tests});

  final Map<String, dynamic> tests;

  @override
  Widget build(BuildContext context) {
    final recent = asList(tests['recent']);
    return _CardShell(
      title: 'Class tests',
      icon: Icons.edit_note,
      color: _indigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${pct(asNum(tests['testPercent']))} average · ${asStr(tests['count'])} tests',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final t in recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${fmtIso(asStr(asMap(t)['date']))} · ${asStr(asMap(t)['exam'])}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    '${marksText(asNum(asMap(t)['obtained']))}/${marksText(asNum(asMap(t)['total']))}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.rows});

  final List<dynamic> rows;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Upcoming exam schedule',
      icon: Icons.event_note,
      color: _teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(fmtIsoWithDay(asStr(asMap(r)['date'])),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(asStr(asMap(r)['subject']),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          [
                            if (asStr(asMap(r)['startTime']).isNotEmpty)
                              '${clock(asStr(asMap(r)['startTime']))}'
                                  '${asStr(asMap(r)['endTime']).isEmpty ? '' : ' - ${clock(asStr(asMap(r)['endTime']))}'}',
                            if (asStr(asMap(r)['room']).isNotEmpty) 'Room ${asStr(asMap(r)['room'])}',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
