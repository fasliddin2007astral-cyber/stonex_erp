import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';

/// Foydalanuvchi sessiyasini lokal xotirada saqlash.
/// Dastur qayta ochilganda har safar login talab qilmaydi.
class LocalSessionStore {
  static File _getFile() {
    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    final dir = Directory('$appData/stonex_erp');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return File('${dir.path}/session.json');
  }

  static void saveSession({required String token, required AppUser user}) {
    try {
      final f = _getFile();
      final data = {
        'token': token,
        'user': user.toJson(),
        'saved_at': DateTime.now().toIso8601String(),
      };
      f.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  static ({String token, AppUser user})? loadSession() {
    try {
      final f = _getFile();
      if (!f.existsSync()) return null;
      final text = f.readAsStringSync();
      if (text.trim().isEmpty) return null;
      final data = jsonDecode(text) as Map<String, dynamic>;
      final token = data['token'] as String?;
      final userMap = data['user'] as Map<String, dynamic>?;
      if (token != null && token.isNotEmpty && userMap != null) {
        return (token: token, user: AppUser.fromJson(userMap));
      }
    } catch (_) {}
    return null;
  }

  static void clearSession() {
    try {
      final f = _getFile();
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {}
  }
}
