import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';

class ChatInfo {
  ChatInfo({
    required this.id,
    required this.type,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.lastText,
    required this.lastAt,
    required this.lastSender,
  });

  final String id;
  final String type;
  final String kind;
  final String title;
  final String subtitle;
  final String lastText;
  final DateTime? lastAt;
  final String lastSender;

  bool get isAnnouncement => type == 'announcement';

  factory ChatInfo.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc, AppUser me) {
    final d = doc.data();
    final members = List<String>.from((d['memberUids'] as List?) ?? const []);
    final names = Map<String, dynamic>.from((d['memberNames'] as Map?) ?? const {});
    String nameOf(String uid) => (names[uid] as String?) ?? '';
    final kind = (d['kind'] as String?) ?? 'teacher';
    var title = (d['title'] as String?) ?? 'Chat';
    var subtitle = (d['subtitle'] as String?) ?? '';

    if (kind == 'office') {
      if (members.isNotEmpty && members.first != me.uid) {
        final n = nameOf(members.first);
        title = n.isEmpty ? 'Parent' : n;
        subtitle = 'School Office';
      }
    } else if (kind == 'teacher' && members.length >= 2) {
      if (me.uid == members[0]) {
        final n = nameOf(members[1]);
        title = n.isEmpty ? 'Parent' : n;
      } else if (me.uid == members[1]) {
        final n = nameOf(members[0]);
        title = n.isEmpty ? 'Teacher' : n;
      } else {
        title = '${nameOf(members[0])} & ${nameOf(members[1])}';
      }
    }

    final ts = d['lastAt'];
    return ChatInfo(
      id: doc.id,
      type: (d['type'] as String?) ?? 'direct',
      kind: kind,
      title: title,
      subtitle: subtitle,
      lastText: (d['lastText'] as String?) ?? '',
      lastAt: ts is Timestamp ? ts.toDate() : null,
      lastSender: (d['lastSender'] as String?) ?? '',
    );
  }
}

class Msg {
  Msg({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.type,
    required this.text,
    required this.time,
    required this.pending,
    required this.deletedForAll,
    required this.readBy,
  });

  final String id;
  final String senderUid;
  final String senderName;
  final String type;
  final String text;
  final DateTime time;
  final bool pending;
  final bool deletedForAll;
  final List<String> readBy;

  factory Msg.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['createdAt'];
    return Msg(
      id: doc.id,
      senderUid: (d['senderUid'] as String?) ?? '',
      senderName: (d['senderName'] as String?) ?? '',
      type: (d['type'] as String?) ?? 'text',
      text: (d['text'] as String?) ?? '',
      time: ts is Timestamp ? ts.toDate() : DateTime.now(),
      pending: ts == null || doc.metadata.hasPendingWrites,
      deletedForAll: d['deletedForAll'] == true,
      readBy: List<String>.from((d['readBy'] as List?) ?? const []),
    );
  }
}
