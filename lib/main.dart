import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_user.dart';
import 'auth_service.dart';
import 'firebase_config.dart';
import 'pages/home_shell.dart';
import 'pages/login_page.dart';
import 'erp/root_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: aspireFirebaseOptions);
  runApp(const AspireChatApp());
}

class AspireChatApp extends StatelessWidget {
  const AspireChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aspire Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: const Color(0xFFEFF3F4),
      ),
      home: const RootRouter(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const LoginPage();
        return ProfileGate(uid: user.uid);
      },
    );
  }
}

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('v2_users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _Notice(
            title: 'Could not load your profile',
            message: '${snap.error}',
          );
        }
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data!.data();
        if (data == null) {
          return const _Notice(
            title: 'Account not set up',
            message: 'Your account is not linked to the school yet. Please contact the school office.',
          );
        }
        final me = AppUser.fromMap(uid, data);
        if (!me.active) {
          return const _Notice(
            title: 'Account disabled',
            message: 'This account is not active. Please contact the school office.',
          );
        }
        return HomeShell(me: me);
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
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
                const SizedBox(height: 24),
                OutlinedButton(onPressed: AuthService.signOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
