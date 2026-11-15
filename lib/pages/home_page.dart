import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_user.dart';
import '../auth_service.dart';
import '../change_password.dart';
import '../data_utils.dart';
import '../models.dart';
import '../read_store.dart';
import 'broadcast_page.dart';
import 'chat_list_page.dart';
import 'complaints_page.dart';
import 'student_detail_page.dart';
import 'students_page.dart';

const String kAppVersion = '1.2.0';
const Color _teal = Color(0xFF0F766E);

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.me});

  final AppUser me;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ReadStore? _store;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _chatStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _childStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _attentionStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _feeStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _cardStream;
  String? _childId;
  List<Map<String, String>> _kids = <Map<String, String>>[];
  List<ChatInfo> _announceTargets = <ChatInfo>[];

  @override
  void initState() {
    super.initState();
    final me = widget.me;
    final db = FirebaseFirestore.instance;
    _chatStream = db.collection('v2_chats').where('memberUids', arrayContains: me.uid).snapshots();
    if (me.role == 'parent') {
      _childStream = db.collection('v2_students').where('parentUids', arrayContains: me.uid).snapshots();
    }
    if (me.isAdmin) {
      _attentionStream = db.collection('v2_complaints').where('needsAttention', isEqualTo: true).snapshots();
    }
    ReadStore.open(me.uid).then((s) {
      if (mounted) setState(() => _store = s);
    });
  }

  void _selectChild(String id) {
    final db = FirebaseFirestore.instance;
    _childId = id;
    _feeStream = db.collection('v2_fees').doc(id).snapshots();
    _cardStream = db.collection('v2_cards').doc(id).snapshots();
  }

  bool _unread(ChatInfo c) {
    final last = c.lastAt;
    final store = _store;
    if (last == null || store == null) return false;
    if (c.lastSender.isNotEmpty && c.lastSender == widget.me.name) return false;
    final seen = store.seenAt(c.id);
    return seen == null || last.isAfter(seen);
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openModule(String section) {
    Map<String, String>? kid;
    for (final k in _kids) {
      if (k['id'] == _childId) kid = k;
    }
    if (kid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No child is linked to your account yet. Please contact the school office.')),
      );
      return;
    }
    _push(StudentDetailPage(
      me: widget.me,
      studentId: kid['id']!,
      name: kid['name']!,
      subtitle: kid['sub']!,
      section: section,
    ));
  }

  Widget _withChildren(Widget Function() builder) {
    final cs = _childStream;
    if (cs == null) return builder();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: cs,
      builder: (context, snap) {
        final kids = <Map<String, String>>[];
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final x = d.data();
            final cls = (x['classId'] as String?) ?? '';
            final sec = (x['section'] as String?) ?? '';
            kids.add(<String, String>{
              'id': d.id,
              'name': (x['name'] as String?) ?? '',
              'sub': [if (cls.isNotEmpty) 'Class $cls', if (sec.isNotEmpty) 'Section $sec'].join(' · '),
            });
          }
          kids.sort((a, b) => a['name']!.compareTo(b['name']!));
        }
        _kids = kids;
        if (kids.isNotEmpty && (_childId == null || !kids.any((k) => k['id'] == _childId))) {
          _selectChild(kids.first['id']!);
        }
        return builder();
      },
    );
  }

  Widget _withAttention(Widget Function(int n) builder) {
    final s = _attentionStream;
    if (s == null) return builder(0);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: s,
      builder: (context, snap) => builder(snap.hasData ? snap.data!.docs.length : 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F6),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatStream,
        builder: (context, chatSnap) {
          final chats = chatSnap.hasData
              ? chatSnap.data!.docs.map((d) => ChatInfo.fromDoc(d, me)).toList()
              : <ChatInfo>[];
          _announceTargets = chats.where((c) => c.isAnnouncement).toList();
          final unread = chats.where(_unread).length;
          ChatInfo? notice;
          for (final c in chats) {
            if (!c.isAnnouncement || c.lastText.isEmpty || c.lastAt == null) continue;
            if (notice == null || c.lastAt!.isAfter(notice.lastAt!)) notice = c;
          }
          return _withChildren(() => _withAttention((attention) => _page(context, unread, notice, attention)));
        },
      ),
    );
  }

  Widget _page(BuildContext context, int unread, ChatInfo? notice, int attention) {
    final me = widget.me;
    final isParent = me.role == 'parent';
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _header(context),
        if (isParent) _summary(),
        if (notice != null) _noticeCard(notice),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: isParent ? _parentTiles(unread) : _staffTiles(unread, attention),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('Aspire Chat $kAppVersion',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ header

  Widget _header(BuildContext context) {
    final me = widget.me;
    final top = MediaQuery.of(context).padding.top;
    final isParent = me.role == 'parent';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 14, 8, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.school_rounded, color: _teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('The Aspire School', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(me.name.isEmpty ? 'Welcome' : me.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (v) {
                  if (v == 'password') showChangePasswordDialog(context);
                  if (v == 'logout') AuthService.signOut();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(value: 'password', child: Text('Change password')),
                  PopupMenuItem<String>(value: 'logout', child: Text('Sign out')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Text(isParent ? 'Parent' : me.roleLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          if (isParent && _kids.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final k in _kids)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectChild(k['id']!)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: k['id'] == _childId ? Colors.white : const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            k['name']!,
                            style: TextStyle(
                              color: k['id'] == _childId ? _teal : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Builder(builder: (context) {
              String sub = '';
              for (final k in _kids) {
                if (k['id'] == _childId) sub = k['sub']!;
              }
              return Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 12));
            }),
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------------- summary

  Widget _summary() {
    final fs = _feeStream;
    final cs = _cardStream;
    if (fs == null || cs == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No child is linked to your account yet. Please contact the school office.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs,
      builder: (context, feeSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: cs,
          builder: (context, cardSnap) {
            final feeData = feeSnap.data?.data();
            final cardData = cardSnap.data?.data();
            final balance = asNum(asMap(feeData?['fees'])['balance']);
            final due = (balance ?? 0) > 0;
            final feeValue = feeData == null ? '-' : (due ? rs(balance) : 'No dues');
            final attPct = asNum(asMap(cardData?['attendance'])['percent']);
            final exams = asList(cardData?['exams']);
            final resultPct =
                exams.isEmpty ? null : asNum(asMap(asMap(exams.first)['result'])['percent']);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Fee',
                      value: feeValue,
                      color: feeData == null ? Colors.black87 : (due ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                      onTap: () => _openModule('fee'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Attendance',
                      value: pct(attPct),
                      color: Colors.black87,
                      onTap: () => _openModule('attendance'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Last result',
                      value: pct(resultPct),
                      color: Colors.black87,
                      onTap: () => _openModule('results'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _noticeCard(ChatInfo n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: const Color(0xFFFFF6DD),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _push(ChatListPage(me: widget.me, initialTab: 1)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.campaign, color: Color(0xFFB45309)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Latest notice', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        n.lastSender.isEmpty ? n.lastText : '${n.lastSender}: ${n.lastText}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- tiles

  List<Widget> _parentTiles(int unread) {
    final me = widget.me;
    return [
      _ModuleTile(
        title: 'Chat',
        subtitle: 'Teachers and school office',
        icon: Icons.chat_bubble_outline,
        color: const Color(0xFF0F766E),
        badge: unread,
        onTap: () => _push(ChatListPage(me: me)),
      ),
      _ModuleTile(
        title: 'Announcements',
        subtitle: 'School notices',
        icon: Icons.campaign_outlined,
        color: const Color(0xFFB45309),
        onTap: () => _push(ChatListPage(me: me, initialTab: 1)),
      ),
      _ModuleTile(
        title: 'Fee',
        subtitle: 'Dues and receipts',
        icon: Icons.payments_outlined,
        color: const Color(0xFFF59E0B),
        onTap: () => _openModule('fee'),
      ),
      _ModuleTile(
        title: 'Attendance',
        subtitle: 'Daily record',
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF16A34A),
        onTap: () => _openModule('attendance'),
      ),
      _ModuleTile(
        title: 'Marks',
        subtitle: 'Class tests',
        icon: Icons.edit_note,
        color: const Color(0xFF6366F1),
        onTap: () => _openModule('tests'),
      ),
      _ModuleTile(
        title: 'Results',
        subtitle: 'Exam results',
        icon: Icons.emoji_events_outlined,
        color: const Color(0xFFEC4899),
        onTap: () => _openModule('results'),
      ),
      _ModuleTile(
        title: 'Date Sheet',
        subtitle: 'Exam schedule',
        icon: Icons.event_note_outlined,
        color: const Color(0xFF0EA5E9),
        onTap: () => _openModule('schedule'),
      ),
      _ModuleTile(
        title: 'Complaints',
        subtitle: 'Raise and track',
        icon: Icons.report_gmailerrorred_outlined,
        color: const Color(0xFFDC2626),
        onTap: () => _push(ComplaintsPage(me: me)),
      ),
    ];
  }

  List<Widget> _staffTiles(int unread, int attention) {
    final me = widget.me;
    return [
      _ModuleTile(
        title: 'Chat',
        subtitle: 'Parents and groups',
        icon: Icons.chat_bubble_outline,
        color: const Color(0xFF0F766E),
        badge: unread,
        onTap: () => _push(ChatListPage(me: me)),
      ),
      _ModuleTile(
        title: 'Announcements',
        subtitle: 'School notices',
        icon: Icons.campaign_outlined,
        color: const Color(0xFFB45309),
        onTap: () => _push(ChatListPage(me: me, initialTab: 1)),
      ),
      _ModuleTile(
        title: 'New announcement',
        subtitle: 'Send to classes or all',
        icon: Icons.send_outlined,
        color: const Color(0xFF6366F1),
        onTap: () => _push(BroadcastPage(me: me, targets: _announceTargets)),
      ),
      _ModuleTile(
        title: 'Students',
        subtitle: me.role == 'teacher' ? 'Your classes' : 'Fee, attendance, marks',
        icon: Icons.school_outlined,
        color: const Color(0xFF16A34A),
        onTap: () => _push(StudentsPage(me: me)),
      ),
      if (me.isAdmin)
        _ModuleTile(
          title: 'Complaints',
          subtitle: 'From parents',
          icon: Icons.report_gmailerrorred_outlined,
          color: const Color(0xFFDC2626),
          badge: attention,
          onTap: () => _push(ComplaintsPage(me: me)),
        ),
    ];
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color, required this.onTap});

  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8EC)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  if (badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(subtitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}
