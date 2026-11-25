import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_user.dart';
import '../pages/chat_list_page.dart';
import '../pages/complaints_page.dart';

// Opens Chat and Complaints inside the new app. The chat sign-in happens silently at ERP login.
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
        if (user == null) {
          return const _Msg(
            title: 'Chat is not ready for this account',
            message: 'Please log out and sign in again. If it still does not open, contact the school office.',
          );
        }
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