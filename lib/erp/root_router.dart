import 'package:flutter/material.dart';

import '../auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_launcher.dart';

import '../main.dart' show AuthGate;
import 'erp_api.dart';
import 'erp_login.dart';
import 'owner_dashboard.dart';
import 'parent_home.dart';
import 'role_placeholder.dart';
import 'teacher_home.dart';

// Front door of the app: the ERP sign-in decides which screen opens.
// The old chat is still reachable from every screen.
class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  bool _loading = true;
  bool _chat = false;
  ErpSession? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var s = await ErpApi.session(); if (s != null) { final prefs = await SharedPreferences.getInstance(); final fu = await FirebaseAuth.instance.authStateChanges().first; if (!prefs.containsKey('erp_chat_v2') && fu == null) { await ErpApi.logout(); s = null; } }
    if (!mounted) return;
    setState(() {
      _s = s;
      _loading = false;
      _chat = false;
    });
  }

  void _openChat() => ChatLauncher.openChat(context);

  void _openLoginChat() => setState(() => _chat = true);

  void _signedOut() => setState(() {
        AuthService.signOut();
        _s = null;
        _chat = false;
      });

  Widget _chatView() {
    return Stack(
      children: [
        const AuthGate(),
        Positioned(
          left: 12,
          bottom: 96,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => setState(() => _chat = false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)]),
                  boxShadow: const [BoxShadow(color: Color(0x551D4ED8), blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dashboard_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(_s == null ? 'School sign-in' : 'Back to my screen', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_chat) return _chatView();
    final s = _s;
    if (s == null) return ErpLoginPage(onSignedIn: _load, onOpenChat: _openLoginChat);
    switch (s.role) {
      case 'OWNER':
        return OwnerDashboardPage(onBack: _openChat, onLogout: _signedOut);
      case 'PARENT':
        return ParentHomePage(name: s.name, onChat: _openChat, onLogout: _signedOut);
      case 'TEACHER':
        return TeacherHomePage(name: s.name, campusName: s.campusName, onChat: _openChat, onLogout: _signedOut);
      default:
        return RolePlaceholderPage(role: s.role, name: s.name, campusName: s.campusName, onChat: _openChat, onLogout: _signedOut);
    }
  }
}
