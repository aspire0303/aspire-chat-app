import 'package:flutter/material.dart';

import 'erp_api.dart';

class ParentApi {
  static Future<Map<String, dynamic>> children() => ErpApi.getJson('/api/parent/children');
  static Future<Map<String, dynamic>> inbox() => ErpApi.getJson('/api/parent/inbox');
  static Future<Map<String, dynamic>> attendance(String studentId, {String? month}) {
    final q = 'studentId=${Uri.encodeQueryComponent(studentId)}${month == null ? '' : '&month=${Uri.encodeQueryComponent(month)}'}';
    return ErpApi.getJson('/api/mobile/parent/attendance?$q');
  }
}

class ParentHeader extends StatelessWidget {
  const ParentHeader({super.key, required this.title, this.subtitle, this.onBack, this.actions = const [], this.bottom});
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(onBack == null ? 16 : 6, top + 10, 12, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7C2D12), Color(0xFFEA580C), Color(0xFFFB923C)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x55EA580C), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 12)),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 12), bottom!],
        ],
      ),
    );
  }
}
