import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, on this phone only, when each chat was last opened,
/// so the chat list can show which chats have new messages.
class ReadStore {
  ReadStore._(this._prefs, this._uid);

  final SharedPreferences _prefs;
  final String _uid;

  static Future<ReadStore> open(String uid) async {
    final p = await SharedPreferences.getInstance();
    return ReadStore._(p, uid);
  }

  String _key(String chatId) => 'seen_${_uid}_$chatId';

  DateTime? seenAt(String chatId) {
    final ms = _prefs.getInt(_key(chatId));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> markSeen(String chatId) =>
      _prefs.setInt(_key(chatId), DateTime.now().millisecondsSinceEpoch);
}
