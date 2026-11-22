import 'package:flutter/material.dart';

import '../main.dart' show AuthGate;
import 'erp_api.dart';
import 'owner_dashboard.dart';

// Temporary entry point: keeps the existing chat app as it is and adds an
// "Owner Dashboard" button that opens the ERP-backed dashboard.
class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  bool _showDash = false;

  Future<void> _open() async {
    final t = await ErpApi.token();
    if (!mounted) return;
    if (t != null) {
      setState(() => _showDash = true);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => OwnerLoginPage(
          onSuccess: () {
            Navigator.of(ctx).pop();
            setState(() => _showDash = true);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showDash) {
      return OwnerDashboardPage(
        onBack: () => setState(() => _showDash = false),
        onLogout: () => setState(() => _showDash = false),
      );
    }
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
              onTap: _open,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)]),
                  boxShadow: const [BoxShadow(color: Color(0x551D4ED8), blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dashboard_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Owner Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}