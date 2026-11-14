import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_user.dart';
import '../auth_service.dart';
import '../models.dart';
import '../util.dart';
import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key, required this.me});

  final AppUser me;

  IconData _iconFor(ChatInfo c) {
    switch (c.kind) {
      case 'office':
        return Icons.support_agent;
      case 'class':
        return Icons.campaign_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);
    final stream = FirebaseFirestore.instance
        .collection('v2_chats')
        .where('memberUids', arrayContains: me.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        title: const Text('Aspire Chat'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') AuthService.signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFD9F2EC),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('${me.name} · ${me.roleLabel}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
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
                final chats = snap.data!.docs.map((d) => ChatInfo.fromDoc(d, me)).toList();
                chats.sort((a, b) {
                  final ta = a.lastAt;
                  final tb = b.lastAt;
                  if (ta != null && tb != null) return tb.compareTo(ta);
                  if (ta != null) return -1;
                  if (tb != null) return 1;
                  return a.title.compareTo(b.title);
                });
                if (chats.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No chats yet. The school office will set up your chats.',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                  itemBuilder: (context, i) {
                    final c = chats[i];
                    final preview = c.lastText.isNotEmpty
                        ? (c.lastSender.isNotEmpty && c.kind == 'class' ? '${c.lastSender}: ${c.lastText}' : c.lastText)
                        : c.subtitle;
                    return ListTile(
                      tileColor: Colors.white,
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFD9F2EC),
                        child: Icon(_iconFor(c), color: teal),
                      ),
                      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: c.lastAt == null
                          ? null
                          : Text(listTime(c.lastAt!),
                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => ChatPage(me: me, chat: c)),
                        );
                      },
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
