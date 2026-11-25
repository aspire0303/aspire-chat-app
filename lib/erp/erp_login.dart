import 'package:flutter/material.dart';

import '../auth_service.dart';

import 'charts.dart' show lighten, darken;
import 'erp_api.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _red = Color(0xFFDC2626);
const _brand = Color(0xFF1D4ED8);

class ErpLoginPage extends StatefulWidget {
  const ErpLoginPage({super.key, required this.onSignedIn, required this.onOpenChat});
  final VoidCallback onSignedIn;
  final VoidCallback onOpenChat;

  @override
  State<ErpLoginPage> createState() => _ErpLoginPageState();
}

class _ErpLoginPageState extends State<ErpLoginPage> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;
  List<Map<String, dynamic>> _choices = [];
  String? _campus;

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _resetChoice() {
    if (_choices.isNotEmpty) {
      setState(() {
        _choices = [];
        _campus = null;
      });
    }
  }

  Future<void> _go() async {
    final id = _id.text.trim();
    final pw = _pass.text;
    if (id.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Enter your email or mobile number and your password.');
      return;
    }
    if (_choices.isNotEmpty && _campus == null) {
      setState(() => _error = 'Choose your campus.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ErpApi.login(id: id, password: pw, campusId: _campus);
      if (!mounted) return;
      if (r.needsCampus) {
        setState(() {
          _choices = r.campuses;
          _campus = null;
          _busy = false;
        });
        return;
      }
      try { if (id.contains('@')) { await AuthService.signOut(); } else if (await AuthService.signIn(id, pw) != null) { await AuthService.signOut(); } } catch (_) {}
      widget.onSignedIn();
    } on ErpException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [darken(_brand, 0.55), _brand, lighten(_brand, 0.45)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Colors.white.withAlpha(70), Colors.white.withAlpha(25)]),
                      boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 18, offset: Offset(0, 10))],
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 12),
                  const Text('Aspire School', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  Text('Sign in to continue', style: TextStyle(color: Colors.white.withAlpha(220))),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 16))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _id,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          onChanged: (_) => _resetChoice(),
                          decoration: const InputDecoration(
                            labelText: 'Email or mobile number',
                            helperText: 'Staff: email. Parents: mobile number.',
                            prefixIcon: Icon(Icons.person_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _pass,
                          obscureText: _hide,
                          onChanged: (_) => _resetChoice(),
                          onSubmitted: (_) => _go(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _hide = !_hide),
                              icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                            ),
                          ),
                        ),
                        if (_choices.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('You are registered in more than one campus. Choose one:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final k in _choices)
                                ChoiceChip(
                                  label: Text('${k['name']}'),
                                  selected: _campus == '${k['id']}',
                                  selectedColor: lighten(_brand, 0.7),
                                  onSelected: (_) => setState(() => _campus = '${k['id']}'),
                                ),
                            ],
                          ),
                        ],
                        if (_error != null)
                          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: _red, fontSize: 13))),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _go,
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: _brand),
                            child: _busy
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(_choices.isEmpty ? 'Sign in' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(child: Text('Your screen opens automatically for your role.', style: TextStyle(fontSize: 11, color: _muted))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: widget.onOpenChat,
                    child: Text('Open chat (existing sign-in)', style: TextStyle(color: Colors.white.withAlpha(235))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
