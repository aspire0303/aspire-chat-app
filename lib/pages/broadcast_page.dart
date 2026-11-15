import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_user.dart';
import '../models.dart';

class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key, required this.me, required this.targets});

  final AppUser me;
  final List<ChatInfo> targets;

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  static const Color teal = Color(0xFF0F766E);

  final _text = TextEditingController();
  final Set<String> _selected = <String>{};
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      _toast('Write your announcement first.');
      return;
    }
    if (_selected.isEmpty) {
      _toast('Choose at least one group.');
      return;
    }
    setState(() => _sending = true);
    final db = FirebaseFirestore.instance;
    var sent = 0;
    var failed = 0;
    for (final id in _selected) {
      try {
        final ref = db.collection('v2_chats').doc(id);
        await ref.collection('messages').add({
          'senderUid': widget.me.uid,
          'senderName': widget.me.name,
          'type': 'text',
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'deletedForAll': false,
          'deletedFor': <String>[],
          'readBy': <String>[widget.me.uid],
        }).timeout(const Duration(seconds: 20));
        await ref.update({
          'lastText': text.length > 80 ? text.substring(0, 80) : text,
          'lastAt': FieldValue.serverTimestamp(),
          'lastSender': widget.me.name,
        }).timeout(const Duration(seconds: 20));
        sent++;
      } catch (e) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (failed == 0) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Announcement sent to $sent group${sent == 1 ? '' : 's'}.')),
      );
    } else {
      _toast('Sent to $sent, failed for $failed. Check your internet connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = widget.targets;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        title: const Text('New announcement'),
      ),
      body: targets.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('You are not in any announcement group yet.', textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Send to', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                  'Every parent in a chosen group can read it. Parents cannot reply there; they reply in their School Office or teacher chat.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _selected
                          ..clear()
                          ..addAll(targets.map((t) => t.id));
                      }),
                      child: const Text('Select all'),
                    ),
                    TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: targets.map((t) {
                    final on = _selected.contains(t.id);
                    return FilterChip(
                      label: Text(t.title),
                      selected: on,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selected.add(t.id);
                        } else {
                          _selected.remove(t.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Text('Message', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _text,
                  minLines: 5,
                  maxLines: 12,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Write your announcement',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Sending...' : 'Send announcement'),
                ),
              ],
            ),
    );
  }
}
