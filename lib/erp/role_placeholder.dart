import 'package:flutter/material.dart';

import 'charts.dart' show lighten, darken;
import 'erp_api.dart';

class RolePlaceholderPage extends StatelessWidget {
  const RolePlaceholderPage({
    super.key,
    required this.role,
    required this.name,
    required this.campusName,
    required this.onChat,
    required this.onLogout,
  });
  final String role;
  final String name;
  final String campusName;
  final VoidCallback onChat;
  final VoidCallback onLogout;

  String get _title {
    switch (role) {
      case 'ADMIN':
        return 'Admin';
      case 'PRINCIPAL':
        return 'Principal';
      case 'PARENT':
        return 'Parent';
      case 'STUDENT':
        return 'Student';
      default:
        return role;
    }
  }

  Color get _color {
    switch (role) {
      case 'ADMIN':
      case 'PRINCIPAL':
        return const Color(0xFF0F766E);
      case 'PARENT':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF9333EA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [darken(c, 0.5), c, lighten(c, 0.4)]),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 16))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    if (campusName.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(campusName, style: const TextStyle(color: Color(0xFF64748B)))),
                    const SizedBox(height: 14),
                    Text(
                      'You are signed in as $_title. This screen is the next one to be built. The Owner, Teacher and Parent screens are ready now.',
                      style: const TextStyle(color: Color(0xFF334155), height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onChat,
                        style: FilledButton.styleFrom(backgroundColor: c, padding: const EdgeInsets.symmetric(vertical: 14)),
                        icon: const Icon(Icons.chat_bubble_rounded),
                        label: const Text('Open chat'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await ErpApi.logout();
                          onLogout();
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
