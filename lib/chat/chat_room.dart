import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../erp/erp_api.dart';
import 'chat_api.dart';

const _teal = Color(0xFF0F766E);
const _muted = Color(0xFF64748B);

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({super.key, required this.convId, required this.title, this.sub = ''});
  final String convId;
  final String title;
  final String sub;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _text = TextEditingController();
  List<Map<String, dynamic>> _msgs = [];
  Map<String, dynamic> _conv = {};
  bool _canSend = false;
  bool _canStatus = false;
  bool _member = false;
  bool _loading = true;
  bool _sending = false;
  String _viewer = '';
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final r = await ChatApi.messages(widget.convId);
      if (!mounted) return;
      setState(() {
        _conv = Map<String, dynamic>.from((r['conv'] as Map?) ?? {});
        _msgs = asList(r['msgs']);
        _canSend = r['canSend'] == true;
        _canStatus = r['canStatus'] == true;
        _member = r['member'] == true;
        _viewer = '${r['viewer'] ?? ''}';
        _loading = false;
        _error = null;
      });
    } on ErpException catch (e) {
      if (mounted && !quiet) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatApi.send(widget.convId, t);
      _text.clear();
      await _load(quiet: true);
    } on ErpException catch (e) {
      if (mounted) _toast(e.message);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _delete(Map<String, dynamic> m, String mode) async {
    try {
      await ChatApi.delete(widget.convId, '${m['id']}', mode);
      await _load(quiet: true);
    } on ErpException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _setStatus(String s) async {
    try {
      await ChatApi.setStatus(widget.convId, s);
      await _load(quiet: true);
    } on ErpException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  void _menu(Map<String, dynamic> m) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (m['deleted'] != true)
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: '${m['text']}'));
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Delete for me'),
            onTap: () {
              Navigator.pop(ctx);
              _delete(m, 'me');
            },
          ),
          if (m['canDeleteAll'] == true)
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626)),
              title: const Text('Delete for everyone'),
              onTap: () {
                Navigator.pop(ctx);
                _delete(m, 'all');
              },
            ),
        ]),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final mine = m['mine'] == true;
    final deleted = m['deleted'] == true;
    final orig = m['orig'];
    final office = _viewer == 'OFFICE';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: _member ? () => _menu(m) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: mine ? const Color(0xFFD9F2E6) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (!mine || office)
              Text('${m['fromName']} · ${m['fromRole']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _teal)),
            if (deleted)
              const Text('This message was deleted', style: TextStyle(fontStyle: FontStyle.italic, color: _muted))
            else
              Text('${m['text']}', style: const TextStyle(fontSize: 15)),
            if (deleted && orig != null)
              Text('Record: $orig', style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(chatTime('${m['at']}'), style: const TextStyle(fontSize: 10, color: _muted)),
              if (mine && !deleted) ...[
                const SizedBox(width: 3),
                Icon(Icons.done_all_rounded, size: 14, color: m['seen'] == true ? const Color(0xFF2563EB) : _muted),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = '${_conv['title'] ?? widget.title}';
    final sub = '${_conv['sub'] ?? widget.sub}';
    final complaint = _conv['kind'] == 'complaint';
    final status = '${_conv['status'] ?? ''}';
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          if (_canStatus)
            PopupMenuButton<String>(
              tooltip: 'Complaint status',
              icon: const Icon(Icons.flag_rounded),
              onSelected: _setStatus,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'open', child: Text('Mark as open')),
                PopupMenuItem(value: 'answered', child: Text('Mark as answered')),
                PopupMenuItem(value: 'closed', child: Text('Close complaint')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : Column(children: [
                  if (complaint)
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFFF7ED),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text('Complaint · ${_conv['subject'] ?? ''} · ${status.isEmpty ? 'open' : status}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
                    ),
                  Expanded(
                    child: _msgs.isEmpty
                        ? const Center(child: Text('No messages yet.', style: TextStyle(color: _muted)))
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _msgs.length,
                            itemBuilder: (_, i) => _bubble(_msgs[_msgs.length - 1 - i]),
                          ),
                  ),
                  if (_canSend)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Expanded(
                            child: TextField(
                              controller: _text,
                              minLines: 1,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Type a message',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          CircleAvatar(
                            backgroundColor: _teal,
                            child: IconButton(
                              onPressed: _sending ? null : _send,
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ]),
                      ),
                    )
                  else
                    SafeArea(
                      top: false,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFFE2E8F0),
                        child: Text(
                          _member ? 'This complaint is closed.' : 'Read-only record (office view).',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted),
                        ),
                      ),
                    ),
                ]),
    );
  }
}