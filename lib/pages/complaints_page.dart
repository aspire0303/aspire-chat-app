import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_user.dart';
import '../util.dart';

const Color _teal = Color(0xFF0F766E);

const List<String> kComplaintCategories = <String>[
  'Teacher or class',
  'Fee',
  'Transport',
  'Academics',
  'Discipline',
  'Facilities',
  'Other',
];

DateTime? _asDate(dynamic v) => v is Timestamp ? v.toDate() : null;

String _when(dynamic v) {
  final t = _asDate(v);
  return t == null ? 'just now' : '${dayLabel(t)}, ${timeLabel(t)}';
}

String _statusLabel(String s) {
  switch (s) {
    case 'in_progress':
      return 'In progress';
    case 'resolved':
      return 'Resolved';
    default:
      return 'Open';
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'in_progress':
      return const Color(0xFFF59E0B);
    case 'resolved':
      return const Color(0xFF16A34A);
    default:
      return const Color(0xFFDC2626);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(12)),
      child: Text(_statusLabel(status),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ------------------------------------------------------------------ list

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key, required this.me});

  final AppUser me;

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final col = FirebaseFirestore.instance.collection('v2_complaints');
    _stream = widget.me.isAdmin
        ? col.snapshots()
        : col.where('parentUid', isEqualTo: widget.me.uid).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final isAdmin = me.isAdmin;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: Text(isAdmin ? 'Complaints' : 'My complaints'),
      ),
      floatingActionButton: me.role == 'parent'
          ? FloatingActionButton.extended(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New complaint'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => NewComplaintPage(me: me)),
                );
              },
            )
          : null,
      body: Column(
        children: [
          if (isAdmin)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final f in const <String>['all', 'open', 'in_progress', 'resolved'])
                    ChoiceChip(
                      label: Text(f == 'all' ? 'All' : _statusLabel(f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load complaints.\n${snap.error}', textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs.toList();
                docs.sort((a, b) {
                  final ta = _asDate(a.data()['updatedAt']);
                  final tb = _asDate(b.data()['updatedAt']);
                  if (ta == null && tb == null) return 0;
                  if (ta == null) return -1;
                  if (tb == null) return 1;
                  return tb.compareTo(ta);
                });
                final shown = docs.where((d) => _filter == 'all' || d.data()['status'] == _filter).toList();
                if (shown.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        isAdmin
                            ? 'No complaints here.'
                            : 'You have not raised any complaint yet.\nTap "New complaint" to tell the school about a problem.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final d = shown[i];
                    final x = d.data();
                    final status = (x['status'] as String?) ?? 'open';
                    final attention = x['needsAttention'] == true;
                    final who = isAdmin
                        ? '${(x['parentName'] as String?) ?? ''}'
                            '${((x['studentName'] as String?) ?? '').isEmpty ? '' : ' · ${x['studentName']}'}'
                        : ((x['studentName'] as String?) ?? '').isEmpty
                            ? 'General'
                            : '${x['studentName']}';
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFE2E8EC)),
                      ),
                      child: ListTile(
                        title: Text((x['subject'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${(x['category'] as String?) ?? ''} · $who\n${_when(x['updatedAt'])}'),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _StatusPill(status),
                            if (isAdmin && attention)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text('Needs reply',
                                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => ComplaintDetailPage(me: me, id: d.id)),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ new

class NewComplaintPage extends StatefulWidget {
  const NewComplaintPage({super.key, required this.me});

  final AppUser me;

  @override
  State<NewComplaintPage> createState() => _NewComplaintPageState();
}

class _NewComplaintPageState extends State<NewComplaintPage> {
  final _subject = TextEditingController();
  final _text = TextEditingController();
  String _childId = '';
  String _category = kComplaintCategories.first;
  bool _busy = false;
  String? _error;
  final Map<String, Map<String, String>> _kids = <String, Map<String, String>>{};
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _kidStream;

  @override
  void initState() {
    super.initState();
    _kidStream = FirebaseFirestore.instance
        .collection('v2_students')
        .where('parentUids', arrayContains: widget.me.uid)
        .snapshots();
  }

  @override
  void dispose() {
    _subject.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final text = _text.text.trim();
    if (subject.isEmpty) {
      setState(() => _error = 'Please write a short subject.');
      return;
    }
    if (text.length < 10) {
      setState(() => _error = 'Please describe the problem in a little more detail.');
      return;
    }
    final kid = _kids[_childId];
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance.collection('v2_complaints').add({
        'parentUid': widget.me.uid,
        'parentName': widget.me.name,
        'studentId': _childId,
        'studentName': kid == null ? '' : kid['name']!,
        'classId': kid == null ? '' : kid['classId']!,
        'category': _category,
        'subject': subject,
        'text': text,
        'status': 'open',
        'needsAttention': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 20));
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Your complaint has been sent to the school.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not send. Check your internet connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: const Text('New complaint'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _kidStream,
        builder: (context, snap) {
          if (snap.hasData) {
            _kids.clear();
            for (final d in snap.data!.docs) {
              final x = d.data();
              _kids[d.id] = <String, String>{
                'name': (x['name'] as String?) ?? '',
                'classId': (x['classId'] as String?) ?? '',
              };
            }
          }
          final items = <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(value: '', child: Text('General (not about one child)')),
            for (final e in _kids.entries)
              DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value['classId']!.isEmpty ? e.value['name']! : '${e.value['name']} (${e.value['classId']})'),
              ),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Your complaint goes privately to the school owner and admin. Teachers do not see it.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _kids.containsKey(_childId) || _childId.isEmpty ? _childId : '',
                items: items,
                decoration: const InputDecoration(labelText: 'About', border: OutlineInputBorder()),
                onChanged: _busy ? null : (v) => setState(() => _childId = v ?? ''),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                items: [
                  for (final c in kComplaintCategories) DropdownMenuItem<String>(value: c, child: Text(c)),
                ],
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                onChanged: _busy ? null : (v) => setState(() => _category = v ?? kComplaintCategories.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _subject,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _text,
                maxLength: 3000,
                minLines: 5,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Describe the problem',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_busy ? 'Sending...' : 'Send complaint'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- detail

class ComplaintDetailPage extends StatefulWidget {
  const ComplaintDetailPage({super.key, required this.me, required this.id});

  final AppUser me;
  final String id;

  @override
  State<ComplaintDetailPage> createState() => _ComplaintDetailPageState();
}

class _ComplaintDetailPageState extends State<ComplaintDetailPage> {
  final _reply = TextEditingController();
  bool _busy = false;
  late final DocumentReference<Map<String, dynamic>> _ref;

  @override
  void initState() {
    super.initState();
    _ref = FirebaseFirestore.instance.collection('v2_complaints').doc(widget.id);
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _send(String currentStatus) async {
    final text = _reply.text.trim();
    if (text.isEmpty || _busy) return;
    final me = widget.me;
    setState(() => _busy = true);
    try {
      await _ref.collection('replies').add({
        'byUid': me.uid,
        'byName': me.name,
        'byRole': me.role,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 20));
      final update = <String, dynamic>{
        'needsAttention': !me.isAdmin,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (me.isAdmin && currentStatus == 'open') update['status'] = 'in_progress';
      await _ref.update(update).timeout(const Duration(seconds: 20));
      _reply.clear();
    } catch (e) {
      if (mounted) _toast('Could not send the reply. Check your internet connection.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _setStatus(String status) async {
    try {
      await _ref.update({
        'status': status,
        'needsAttention': status == 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 20));
    } catch (e) {
      if (mounted) _toast('Could not change the status.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: const Text('Complaint'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Could not load.\n${snap.error}', textAlign: TextAlign.center));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final x = snap.data!.data();
          if (x == null) return const Center(child: Text('This complaint is no longer available.'));
          final status = (x['status'] as String?) ?? 'open';
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFE2E8EC)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text((x['subject'] as String?) ?? '',
                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                ),
                                _StatusPill(status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                (x['category'] as String?) ?? '',
                                if (me.isAdmin && ((x['parentName'] as String?) ?? '').isNotEmpty) '${x['parentName']}',
                                if (((x['studentName'] as String?) ?? '').isNotEmpty)
                                  '${x['studentName']}${((x['classId'] as String?) ?? '').isEmpty ? '' : ' (${x['classId']})'}',
                              ].join(' · '),
                              style: const TextStyle(color: Colors.black54, fontSize: 13),
                            ),
                            const SizedBox(height: 10),
                            Text((x['text'] as String?) ?? '', style: const TextStyle(fontSize: 15)),
                            const SizedBox(height: 8),
                            Text('Sent ${_when(x['createdAt'])}',
                                style: const TextStyle(color: Colors.black45, fontSize: 12)),
                            if (me.isAdmin) ...[
                              const SizedBox(height: 12),
                              const Text('Set status', style: TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final s in const <String>['open', 'in_progress', 'resolved'])
                                    ChoiceChip(
                                      label: Text(_statusLabel(s)),
                                      selected: status == s,
                                      onSelected: (_) => _setStatus(s),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _ref.collection('replies').orderBy('createdAt').snapshots(),
                      builder: (context, rs) {
                        if (rs.hasError) {
                          return Text('Could not load replies.\n${rs.error}');
                        }
                        if (!rs.hasData) return const SizedBox.shrink();
                        return Column(
                          children: [
                            for (final d in rs.data!.docs) _ReplyBubble(data: d.data(), mine: d.data()['byUid'] == me.uid),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: SafeArea(
                  top: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 3000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: me.isAdmin ? 'Reply to the parent' : 'Add a message',
                            filled: true,
                            fillColor: const Color(0xFFF1F4F5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _busy ? null : () => _send(status),
                        icon: const Icon(Icons.send_rounded),
                        style: IconButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReplyBubble extends StatelessWidget {
  const _ReplyBubble({required this.data, required this.mine});

  final Map<String, dynamic> data;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final role = (data['byRole'] as String?) ?? '';
    final label = role == 'parent' ? 'Parent' : 'School';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFD9F2EC) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${(data['byName'] as String?) ?? ''} ($label)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _teal)),
            const SizedBox(height: 2),
            Text((data['text'] as String?) ?? '', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(_when(data['createdAt']), style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }
}
