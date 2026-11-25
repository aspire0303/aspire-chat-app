import 'dart:async';

import 'package:flutter/material.dart';

import '../erp/erp_api.dart';
import 'chat_api.dart';
import 'chat_room.dart';

const _teal = Color(0xFF0F766E);
const _muted = Color(0xFF64748B);

bool _isOffice(String role) => role == 'OWNER' || role == 'ADMIN' || role == 'PRINCIPAL';

Color _statusColor(String s) {
  if (s == 'answered') return const Color(0xFF16A34A);
  if (s == 'closed') return const Color(0xFF64748B);
  return const Color(0xFFEA580C);
}

String _statusLabel(String s) => s == 'answered' ? 'Answered' : (s == 'closed' ? 'Closed' : 'Open');

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> with SingleTickerProviderStateMixin {
  TabController? _tc;
  String _role = '';
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final s = await ErpApi.session();
    if (!mounted) return;
    final role = s?.role ?? '';
    final n = _isOffice(role) ? 3 : (role == 'PARENT' ? 2 : 1);
    final c = TabController(length: n, vsync: this, initialIndex: widget.initialTab < n ? widget.initialTab : 0);
    c.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() {
      _role = role;
      _tc = c;
    });
  }

  @override
  void dispose() {
    _tc?.dispose();
    super.dispose();
  }

  Future<void> _openRoom(Map<String, dynamic> r) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatRoomPage(convId: '${r['id']}', title: '${r['title'] ?? ''}', sub: '${r['sub'] ?? ''}'),
    ));
    if (mounted) setState(() => _tick++);
  }

  Future<void> _newChat() async {
    final r = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => const ContactsPage()));
    if (r != null && mounted) await _openRoom(r);
  }

  Future<void> _newComplaint() async {
    final r = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => const ComplaintFormPage()));
    if (r != null && mounted) await _openRoom(r);
  }

  @override
  Widget build(BuildContext context) {
    final tc = _tc;
    if (tc == null) {
      return Scaffold(appBar: AppBar(title: const Text('Messages')), body: const Center(child: CircularProgressIndicator()));
    }
    final office = _isOffice(_role);
    final parent = _role == 'PARENT';
    Widget? fab;
    if (tc.index == 0) {
      fab = FloatingActionButton.extended(
        onPressed: _newChat,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New chat'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
      );
    } else if (parent && tc.index == 1) {
      fab = FloatingActionButton.extended(
        onPressed: _newComplaint,
        icon: const Icon(Icons.report_problem_rounded),
        label: const Text('New complaint'),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        bottom: TabBar(
          controller: tc,
          tabs: [
            const Tab(text: 'Chats'),
            if (office || parent) const Tab(text: 'Complaints'),
            if (office) const Tab(text: 'All records'),
          ],
        ),
      ),
      floatingActionButton: fab,
      body: TabBarView(
        controller: tc,
        children: [
          ConvListTab(key: ValueKey('c$_tick'), kind: 'direct', onOpen: _openRoom),
          if (office || parent) ConvListTab(key: ValueKey('k$_tick'), kind: 'complaint', onOpen: _openRoom),
          if (office) const RecordsTab(),
        ],
      ),
    );
  }
}

class ConvListTab extends StatefulWidget {
  const ConvListTab({super.key, required this.kind, required this.onOpen});
  final String kind;
  final Future<void> Function(Map<String, dynamic>) onOpen;

  @override
  State<ConvListTab> createState() => _ConvListTabState();
}

class _ConvListTabState extends State<ConvListTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final r = await ChatApi.conversations();
      if (!mounted) return;
      setState(() {
        _items = asList(r['conversations']).where((c) => c['kind'] == widget.kind).toList();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _load(), child: const Text('Try again')),
          ]),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.kind == 'complaint' ? 'No complaints yet.' : 'No chats yet. Tap New chat to start one.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (_, i) {
          final c = _items[i];
          final unread = (c['unread'] as num?)?.toInt() ?? 0;
          final title = '${c['title'] ?? ''}';
          final complaint = widget.kind == 'complaint';
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: complaint ? const Color(0xFFFEE2E2) : const Color(0xFFCCFBF1),
              child: complaint
                  ? const Icon(Icons.report_problem_rounded, color: Color(0xFFDC2626))
                  : Text(title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(), style: const TextStyle(color: _teal, fontWeight: FontWeight.w800)),
            ),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600)),
            subtitle: Text(
              '${(c['lastText'] ?? '').toString().isEmpty ? c['sub'] : c['lastText']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(chatTime('${c['lastAt'] ?? ''}'), style: const TextStyle(fontSize: 11, color: _muted)),
                const SizedBox(height: 4),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(10)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  )
                else if (complaint)
                  Text(_statusLabel('${c['status']}'), style: TextStyle(fontSize: 11, color: _statusColor('${c['status']}'), fontWeight: FontWeight.w700)),
              ],
            ),
            onTap: () async {
              await widget.onOpen(c);
              if (mounted) _load(quiet: true);
            },
          );
        },
      ),
    );
  }
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Map<String, dynamic>> _all = [];
  String _q = '';
  bool _loading = true;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ChatApi.contacts();
      if (!mounted) return;
      setState(() {
        _all = asList(r['contacts']);
        _loading = false;
      });
    } on ErpException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _pick(Map<String, dynamic> c) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final r = await ChatApi.open('${c['id']}');
      if (mounted) Navigator.of(context).pop({'id': r['id'], 'title': c['name'], 'sub': c['sub']});
    } on ErpException catch (e) {
      if (mounted) {
        setState(() => _opening = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = _all.where((c) => q.isEmpty || '${c['name']} ${c['sub']}'.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Start a chat')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      onChanged: (v) => setState(() => _q = v),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search name, class or student', border: OutlineInputBorder()),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(child: Text('Nobody found.', style: TextStyle(color: _muted)))
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                            itemBuilder: (_, i) {
                              final c = list[i];
                              final kind = '${c['kind']}';
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFCCFBF1),
                                  child: Icon(kind == 'teacher' ? Icons.school_rounded : (kind == 'office' ? Icons.apartment_rounded : Icons.family_restroom_rounded), color: _teal),
                                ),
                                title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${c['sub']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                                onTap: () => _pick(c),
                              );
                            },
                          ),
                  ),
                ]),
    );
  }
}

class ComplaintFormPage extends StatefulWidget {
  const ComplaintFormPage({super.key});

  @override
  State<ComplaintFormPage> createState() => _ComplaintFormPageState();
}

class _ComplaintFormPageState extends State<ComplaintFormPage> {
  final _subject = TextEditingController();
  final _msg = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _msg.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = _subject.text.trim();
    final m = _msg.text.trim();
    if (s.length < 3 || m.isEmpty) {
      setState(() => _error = 'Write a subject and describe your complaint.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ChatApi.open('office', kind: 'complaint', subject: s);
      await ChatApi.send('${r['id']}', m);
      if (mounted) Navigator.of(context).pop({'id': r['id'], 'title': s, 'sub': 'Complaint'});
    } on ErpException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New complaint')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _subject, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(
            controller: _msg,
            minLines: 5,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Describe your complaint', alignLabelWithHint: true, border: OutlineInputBorder()),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send to the school office'),
            ),
          ),
        ]),
      ),
    );
  }
}

class RecordsTab extends StatefulWidget {
  const RecordsTab({super.key});

  @override
  State<RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<RecordsTab> {
  final _q = TextEditingController();
  String _kind = 'all';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ChatApi.records(_q.text, _kind);
      if (!mounted) return;
      setState(() {
        _items = asList(r['records']);
        _loading = false;
        _error = null;
      });
    } on ErpException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _q,
          onSubmitted: (_) => _load(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search names, subjects or messages',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward_rounded)),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(spacing: 8, children: [
          for (final k in const [['all', 'All'], ['direct', 'Chats'], ['complaint', 'Complaints']])
            ChoiceChip(
              label: Text(k[1]),
              selected: _kind == k[0],
              onSelected: (_) {
                setState(() => _kind = k[0]);
                _load();
              },
            ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                : _items.isEmpty
                    ? const Center(child: Text('No records found.', style: TextStyle(color: _muted)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = _items[i];
                            final complaint = r['kind'] == 'complaint';
                            final title = complaint ? 'Complaint: ${r['subject']}' : '${r['aName']}  ↔  ${r['bName']}';
                            final sub = complaint ? '${r['aName']} · ${r['aSub']}' : '${r['aSub']}  |  ${r['bSub']}';
                            return ListTile(
                              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('$sub\n${r['lastText']}', maxLines: 3, overflow: TextOverflow.ellipsis),
                              isThreeLine: true,
                              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(chatTime('${r['lastAt'] ?? ''}'), style: const TextStyle(fontSize: 11, color: _muted)),
                                Text('${r['count']} msgs', style: const TextStyle(fontSize: 11, color: _muted)),
                                if (complaint) Text(_statusLabel('${r['status']}'), style: TextStyle(fontSize: 11, color: _statusColor('${r['status']}'), fontWeight: FontWeight.w700)),
                              ]),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ChatRoomPage(convId: '${r['id']}', title: title, sub: sub),
                              )),
                            );
                          },
                        ),
                      ),
      ),
    ]);
  }
}