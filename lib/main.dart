import 'package:flutter/material.dart';

import 'erp/root_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AspireChatApp());
}

class AspireChatApp extends StatelessWidget {
  const AspireChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aspire School',
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