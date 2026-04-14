import 'package:shared_preferences/shared_preferences.dart';

class NoteService {
  static const _prefix = 'note_';

  static Future<String?> getNote(String listId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$listId');
  }

  static Future<void> saveNote(String listId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    if (text.isEmpty) {
      await prefs.remove('$_prefix$listId');
    } else {
      await prefs.setString('$_prefix$listId', text);
    }
  }

  static Future<bool> hasNote(String listId) async {
    final prefs = await SharedPreferences.getInstance();
    final note = prefs.getString('$_prefix$listId');
    return note != null && note.isNotEmpty;
  }
}
