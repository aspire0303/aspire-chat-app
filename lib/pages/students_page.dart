import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_user.dart';
import 'student_detail_page.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, required this.me});

  final AppUser me;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  static const Color teal = Color(0xFF0F766E);

  String _query = '';
  String? _class;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    final me = widget.me;
    final col = FirebaseFirestore.instance.collection('v2_students');
    if (me.role == 'parent') {
      _stream = col.where('parentUids', arrayContains: me.uid).snapshots();
    } else if (me.isAdmin) {
      _stream = col.snapshots();
    } else if (me.classIds.isNotEmpty) {
      _pickClass(me.classIds.first);
    }
  }

  void _pickClass(String c) {
    _class = c;
    _stream = FirebaseFirestore.instance
        .collection('v2_students')
        .where('classId', isEqualTo: c)
        .snapshots();
  }

  Widget _body() {
    final me = widget.me;
    final stream = _stream;
    if (stream == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            me.role == 'teacher'
                ? 'No classes are assigned to you yet. Please contact the school office.'
                : 'No students found.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load students.\n${snap.error}', textAlign: TextAlign.center),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final q = _query.trim().toLowerCase();
        final items = snap.data!.docs.map((d) {
          final x = d.data();
          return <String, String>{
            'id': d.id,
            'name': (x['name'] as String?) ?? '',
            'classId': (x['classId'] as String?) ?? '',
            'section': (x['section'] as String?) ?? '',
            'rollNo': (x['rollNo'] as String?) ?? '',
          };
        }).where((m) {
          if (q.isEmpty) return true;
          return m['name']!.toLowerCase().contains(q) || m['classId']!.toLowerCase().contains(q);
        }).toList();
        items.sort((a, b) {
          final c = a['classId']!.compareTo(b['classId']!);
          return c != 0 ? c : a['name']!.compareTo(b['name']!);
        });
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No students found.', textAlign: TextAlign.center),
            ),
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, i) {
            final m = items[i];
            final parts = <String>[
              if (m['classId']!.isNotEmpty) m['classId']!,
              if (m['section']!.isNotEmpty) 'Section ${m['section']}',
              if (m['rollNo']!.isNotEmpty) 'Roll ${m['rollNo']}',
            ];
            final subtitle = parts.join(' · ');
            final initial = m['name']!.isEmpty ? '?' : m['name']!.substring(0, 1).toUpperCase();
            return ListTile(
              tileColor: Colors.white,
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFD9F2EC),
                child: Text(initial,
                    style: const TextStyle(color: teal, fontWeight: FontWeight.w700, fontSize: 18)),
              ),
              title: Text(m['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StudentDetailPage(
                      me: widget.me,
                      studentId: m['id']!,
                      name: m['name']!,
                      subtitle: subtitle,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final isParent = me.role == 'parent';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        title: Text(isParent ? 'My Children' : 'Students'),
      ),
      body: Column(
        children: [
          if (me.role == 'teacher' && me.classIds.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFD9F2EC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButton<String>(
                value: _class,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: me.classIds
                    .map((c) => DropdownMenuItem<String>(value: c, child: Text('Class $c')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _pickClass(v));
                },
              ),
            ),
          if (!isParent)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by student name or class',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF1F4F5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
