import 'package:firebase_auth/firebase_auth.dart';

// Same rule the ERP tools use to turn a mobile number into a login id.
String normalizeMobile(String input) {
  var d = input.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0092')) d = d.substring(2);
  if (d.startsWith('92')) return d;
  if (d.startsWith('0')) return '92${d.substring(1)}';
  if (d.length == 10) return '92$d';
  return d;
}

class AuthService {
  static const String staffDomain = 'staff.aspire-chat.app';
  static const String parentDomain = 'parent.aspire-chat.app';

  /// Returns null on success, otherwise a message to show the user.
  static Future<String?> signIn(String mobile, String password) async {
    final wa = normalizeMobile(mobile);
    if (!RegExp(r'^923\d{9}$').hasMatch(wa)) {
      return 'Enter a valid mobile number, for example 03001234567.';
    }
    if (password.isEmpty) return 'Enter your password.';
    final auth = FirebaseAuth.instance;
    for (final domain in [staffDomain, parentDomain]) {
      try {
        await auth.signInWithEmailAndPassword(email: '$wa@$domain', password: password);
        return null;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'network-request-failed') {
          return 'No internet connection. Please try again.';
        }
        if (e.code == 'too-many-requests') {
          return 'Too many attempts. Please wait a few minutes and try again.';
        }
        if (e.code == 'user-disabled') {
          return 'This account has been disabled. Please contact the school office.';
        }
      }
    }
    return 'Wrong mobile number or password.';
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();
}
