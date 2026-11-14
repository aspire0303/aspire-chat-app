import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_user.dart';
import '../models.dart';
import '../util.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.me, required this.chat});

  final AppUser me;
  final ChatInfo chat;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final Set<String> _marked = <String>{};
  int _limit = 30;

  CollectionReference<Map<String, dynamic>> get _messages => FirebaseFirestore.instance
      .collection('v2_chats')
      .doc(widget.chat.id)
      .collection('messages');

  bool get _canWrite => !widget.chat.isAnnouncement || widget.me.isStaff;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _run(Future<void> f) {
    f.then((_) {}, onError: (Object e) {
      if (mounted) _toast('Action failed: $e');
    });
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    _messages.add({
      'senderUid': widget.me.uid,
      'senderName': widget.me.name,
      'type': 'text',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedForAll': false,
      'deletedFor': <String>[],
      'readBy': <String>[widget.me.uid],
    }).then((_) {}, onError: (Object e) {
      if (mounted) _toast('Message not sent: $e');
    });
    _run(FirebaseFirestore.instance.collection('v2_chats').doc(widget.chat.id).update({
      'lastText': text.length > 80 ? text.substring(0, 80) : text,
      'lastAt': FieldValue.serverTimestamp(),
      'lastSender': widget.me.name,
    }));
  }

  void _markRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    for (final d in docs) {
      final data = d.data();
      if (data['senderUid'] == widget.me.uid) continue;
      if (data['deletedForAll'] == true) continue;
      final readBy = List<String>.from((data['readBy'] as List?) ?? const []);
      if (readBy.contains(widget.me.uid) || _marked.contains(d.id)) continue;
      _marked.add(d.id);
      d.reference.update({
        'readBy': FieldValue.arrayUnion([widget.me.uid]),
      }).then((_) {}, onError: (Object e) {
        _marked.remove(d.id);
      });
    }
  }

  void _showActions(Msg m) {
    final mine = m.senderUid == widget.me.uid;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!m.deletedForAll && m.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: m.text));
                  Navigator.pop(ctx);
                },
              ),
            if (!m.pending)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for me'),
                onTap: () {
                  Navigator.pop(ctx);
                  _run(_messages.doc(m.id).update({
                    'deletedFor': FieldValue.arrayUnion([widget.me.uid]),
                  }));
                },
              ),
            if (mine && !m.deletedForAll && !m.pending)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                title: const Text('Delete for everyone'),
                onTap: () {
                  Navigator.pop(ctx);
                  _run(_messages.doc(m.id).update({'deletedForAll': true, 'text': ''}));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);
    final query = _messages.orderBy('createdAt', descending: true).limit(_limit);
    final chat = widget.chat;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (chat.subtitle.isNotEmpty)
              Text(chat.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load messages.\n${snap.error}', textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _markRead(docs);
                });
                final visible = docs.where((d) {
                  final del = List<String>.from((d.data()['deletedFor'] as List?) ?? const []);
                  return !del.contains(widget.me.uid);
                }).toList();
                if (visible.isEmpty) {
                  return const Center(child: Text('No messages yet. Say hello!'));
                }
                final hasMore = docs.length >= _limit;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: visible.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == visible.length) {
                      return Center(
                        child: TextButton(
                          onPressed: () => setState(() => _limit += 30),
                          child: const Text('Load older messages'),
                        ),
                      );
                    }
                    final m = Msg.fromDoc(visible[i]);
                    final older = i + 1 < visible.length ? Msg.fromDoc(visible[i + 1]) : null;
                    final showDate = older == null || !sameDay(m.time, older.time);
                    final mine = m.senderUid == widget.me.uid;
                    return Column(
                      children: [
                        if (showDate) _DateChip(label: dayLabel(m.time)),
                        _Bubble(
                          msg: m,
                          mine: mine,
                          showSender: chat.isAnnouncement && !mine,
                          announcement: chat.isAnnouncement,
                          onLongPress: () => _showActions(m),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_canWrite)
            _Composer(controller: _text, onSend: _send)
          else
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(14),
              child: const Text(
                'Only school staff can post in announcements.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDCE3E6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.msg,
    required this.mine,
    required this.showSender,
    required this.announcement,
    required this.onLongPress,
  });

  final Msg msg;
  final bool mine;
  final bool showSender;
  final bool announcement;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final bg = mine ? const Color(0xFFD9F2EC) : Colors.white;
    final deleted = msg.deletedForAll;
    final others = msg.readBy.where((u) => u != msg.senderUid).length;

    Widget status;
    if (!mine) {
      status = const SizedBox.shrink();
    } else if (msg.pending) {
      status = const Icon(Icons.access_time, size: 14, color: Colors.black45);
    } else if (announcement) {
      status = Text('Seen by $others', style: const TextStyle(fontSize: 11, color: Colors.black54));
    } else {
      status = Icon(
        others > 0 ? Icons.done_all : Icons.done,
        size: 15,
        color: others > 0 ? const Color(0xFF2563EB) : Colors.black45,
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
            border: Border.all(color: const Color(0xFFE2E8EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSender)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    msg.senderName.isEmpty ? 'Staff' : msg.senderName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                  ),
                ),
              Text(
                deleted ? 'This message was deleted' : msg.text,
                style: TextStyle(
                  fontSize: 16,
                  color: deleted ? Colors.black45 : Colors.black87,
                  fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeLabel(msg.time),
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(width: 4),
                    status,
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

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message',
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
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
