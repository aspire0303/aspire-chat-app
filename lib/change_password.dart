import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> showChangePasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cur = _current.text;
    final n1 = _new1.text;
    final n2 = _new2.text;
    if (cur.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    if (n1.length < 6) {
      setState(() => _error = 'The new password must be at least 6 characters.');
      return;
    }
    if (n1 != n2) {
      setState(() => _error = 'The two new passwords do not match.');
      return;
    }
    if (n1 == cur) {
      setState(() => _error = 'Choose a password different from the current one.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      setState(() => _error = 'You are not signed in.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: cur),
      );
      await user.updatePassword(n1);
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Password changed.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Your current password is not correct.';
          break;
        case 'weak-password':
          msg = 'That password is too weak. Use at least 6 characters.';
          break;
        case 'network-request-failed':
          msg = 'No internet connection. Please try again.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please wait a few minutes.';
          break;
        default:
          msg = 'Could not change the password (${e.code}).';
      }
      setState(() {
        _busy = false;
        _error = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _current,
              obscureText: _hide,
              decoration: InputDecoration(
                labelText: 'Current password',
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _new1,
              obscureText: _hide,
              decoration: const InputDecoration(labelText: 'New password (6 or more characters)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _new2,
              obscureText: _hide,
              decoration: const InputDecoration(labelText: 'Repeat the new password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving...' : 'Change'),
        ),
      ],
    );
  }
}