import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_user.dart';
import '../auth_service.dart';
import '../pages/chat_list_page.dart';
import '../pages/complaints_page.dart';

// Opens Chat and Complaints inside the new app (no old app, no second home screen).
class ChatLauncher {
  static void openChat(BuildContext context) => _open(context, (me) => ChatListPage(me: me));
  static void openComplaints(BuildContext context) => _open(context, (me) => ComplaintsPage(me: me));

  static void _open(BuildContext context, Widget Function(AppUser me) builder) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ChatEntry(builder: builder)));
  }
}

class _ChatEntry extends StatelessWidget {
  const _ChatEntry({required this.builder});
  final Widget Function(AppUser me) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Wait();
        final user = snap.data;
        if (user == null) return const _ChatSignIn();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('v2_users').doc(user.uid).snapshots(),
          builder: (context, ps) {
            if (ps.hasError) return _Msg(title: 'Could not load your chat profile', message: '${ps.error}');
            if (!ps.hasData) return const _Wait();
            final data = ps.data!.data();
            if (data == null) {
              return const _Msg(title: 'Chat account not set up', message: 'Your chat account is not linked to the school yet. Please contact the school office.');
            }
            final me = AppUser.fromMap(user.uid, data);
            if (!me.active) {
              return const _Msg(title: 'Chat account disabled', message: 'This chat account is not active. Please contact the school office.');
            }
            return builder(me);
          },
        );
      },
    );
  }
}

class _Wait extends StatelessWidget {
  const _Wait();
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
}

class _Msg extends StatelessWidget {
  const _Msg({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 48),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// Shown once when the chat login could not be done quietly (for example staff who sign in to the ERP with email).
class _ChatSignIn extends StatefulWidget {
  const _ChatSignIn();
  @override
  State<_ChatSignIn> createState() => _ChatSignInState();
}

class _ChatSignInState extends State<_ChatSignIn> {
  final _mobile = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _mobile.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AuthService.signIn(_mobile.text, _pass.text);
    if (!mounted) return;
    if (err != null) setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat sign-in')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sign in to chat once. You will stay signed in on this phone.', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_rounded), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pass,
              obscureText: _hide,
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
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _go,
                child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Open chat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}