import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_user.dart';
import '../auth_service.dart';
import '../change_password.dart';
import '../models.dart';
import '../read_store.dart';
import '../util.dart';
import 'broadcast_page.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key, required this.me, this.initialTab = 0});

  final AppUser me;
  final int initialTab;

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  static const Color teal = Color(0xFF0F766E);

  ReadStore? _store;
  String _query = '';
  List<ChatInfo> _announceTargets = <ChatInfo>[];
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('v2_chats')
        .where('memberUids', arrayContains: widget.me.uid)
        .snapshots();
    ReadStore.open(widget.me.uid).then((s) {
      if (mounted) setState(() => _store = s);
    });
  }

  IconData _iconFor(ChatInfo c) {
    if (c.isAnnouncement) return Icons.campaign_outlined;
    if (c.kind == 'office') return Icons.support_agent;
    return Icons.person_outline;
  }

  bool _unread(ChatInfo c) {
    final last = c.lastAt;
    final store = _store;
    if (last == null || store == null) return false;
    if (c.lastSender.isNotEmpty && c.lastSender == widget.me.name) return false;
    final seen = store.seenAt(c.id);
    return seen == null || last.isAfter(seen);
  }

  List<ChatInfo> _filtered(List<ChatInfo> all, int tab) {
    final q = _query.trim().toLowerCase();
    return all.where((c) {
      if (tab == 1 && !c.isAnnouncement) return false;
      if (tab == 2 && c.isAnnouncement) return false;
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.subtitle.toLowerCase().contains(q) ||
          c.lastText.toLowerCase().contains(q);
    }).toList();
  }

  Widget _list(List<ChatInfo> items, String emptyText) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyText, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
      itemBuilder: (context, i) {
        final c = items[i];
        final unread = _unread(c);
        final preview = c.lastText.isNotEmpty
            ? (c.lastSender.isNotEmpty && c.isAnnouncement ? '${c.lastSender}: ${c.lastText}' : c.lastText)
            : c.subtitle;
        return ListTile(
          tileColor: Colors.white,
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFD9F2EC),
            child: Icon(_iconFor(c), color: teal),
          ),
          title: Text(
            c.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600),
          ),
          subtitle: Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unread ? Colors.black87 : Colors.black54,
              fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (c.lastAt != null)
                Text(listTime(c.lastAt!),
                    style: TextStyle(
                        fontSize: 12,
                        color: unread ? teal : Colors.black54,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w400)),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: teal, shape: BoxShape.circle),
                ),
            ],
          ),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatPage(me: widget.me, chat: c, store: _store),
              ),
            );
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return DefaultTabController(
      initialIndex: widget.initialTab,
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          title: const Text('Aspire Chat'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'logout') AuthService.signOut();
                if (v == 'password') showChangePasswordDialog(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(value: 'password', child: Text('Change password')),
                PopupMenuItem<String>(value: 'logout', child: Text('Sign out')),
              ],
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFB7E4DC),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Announcements'),
              Tab(text: 'Chats'),
            ],
          ),
        ),
        floatingActionButton: me.isStaff
            ? FloatingActionButton.extended(
                backgroundColor: teal,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.campaign),
                label: const Text('New announcement'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BroadcastPage(me: me, targets: _announceTargets),
                    ),
                  );
                },
              )
            : null,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFD9F2EC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('${me.name} · ${me.roleLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, child or message',
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
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Could not load chats.\n${snap.error}', textAlign: TextAlign.center),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snap.data!.docs.map((d) => ChatInfo.fromDoc(d, me)).toList();
                  all.sort((a, b) {
                    final ta = a.lastAt;
                    final tb = b.lastAt;
                    if (ta != null && tb != null) return tb.compareTo(ta);
                    if (ta != null) return -1;
                    if (tb != null) return 1;
                    return a.title.compareTo(b.title);
                  });
                  _announceTargets = all.where((c) => c.isAnnouncement).toList();
                  return TabBarView(
                    children: [
                      _list(_filtered(all, 0), 'No chats yet. The school office will set up your chats.'),
                      _list(_filtered(all, 1), 'No announcement groups yet.'),
                      _list(_filtered(all, 2), 'No private chats yet.'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
