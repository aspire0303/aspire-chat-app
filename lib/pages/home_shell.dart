import 'package:flutter/material.dart';

import '../app_user.dart';
import 'chat_list_page.dart';
import 'students_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.me});

  final AppUser me;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isParent = widget.me.role == 'parent';
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          ChatListPage(me: widget.me),
          StudentsPage(me: widget.me),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: isParent ? 'My Children' : 'Students',
          ),
        ],
      ),
    );
  }
}
