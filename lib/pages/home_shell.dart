import 'package:flutter/material.dart';

import '../app_user.dart';
import 'home_page.dart';

/// Entry point after login: the dashboard.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context) => HomePage(me: me);
}
