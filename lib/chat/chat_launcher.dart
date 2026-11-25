import 'package:flutter/material.dart';

import 'chat_pages.dart';

// Chat and Complaints live inside the app and use the same ERP login.
class ChatLauncher {
  static void openChat(BuildContext context) => _open(context, 0);
  static void openComplaints(BuildContext context) => _open(context, 1);

  static void _open(BuildContext context, int tab) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatHomePage(initialTab: tab)));
  }
}