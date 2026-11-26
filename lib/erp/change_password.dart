import 'package:flutter/material.dart';

import 'erp_api.dart';

Future<void> showChangePasswordDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _ChangePasswordDialog());
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_cur.text.isEmpty || _new.text.isEmpty || _again.text.isEmpty) {
      setState(() => _error = 'Fill in all three boxes.');
      return;
    }
    if (_new.text.length < 6) {
      setState(() => _error = 'The new password must be at least 6 characters.');
      return;
    }
    if (_new.text != _again.text) {
      setState(() => _error = 'The two new passwords do not match.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ErpApi.changePassword(_cur.text, _new.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Password changed. Use the new password next time you sign in.')));
    } on ErpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      obscureText: _hide,
      enabled: !_busy,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_cur, 'Current password'),
            const SizedBox(height: 12),
            _field(_new, 'New password (6+ characters)'),
            const SizedBox(height: 12),
            _field(_again, 'Repeat new password'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _hide = !_hide),
                icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
                label: Text(_hide ? 'Show' : 'Hide'),
              ),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
