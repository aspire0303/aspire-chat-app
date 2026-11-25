import 'package:flutter/material.dart';

import '../chat/chat_launcher.dart';
import 'erp_api.dart';
import 'erp_login.dart';
import 'owner_dashboard.dart';
import 'parent_home.dart';
import 'role_placeholder.dart';
import 'teacher_home.dart';

// Front door of the app: the ERP sign-in decides which screen opens.
class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  bool _loading = true;
  ErpSession? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ErpApi.session();
    if (!mounted) return;
    setState(() {
      _s = s;
      _loading = false;
    });
  }

  void _openChat() => ChatLauncher.openChat(context);

  void _signedOut() => setState(() => _s = null);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final s = _s;
    if (s == null) return ErpLoginPage(onSignedIn: _load);
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