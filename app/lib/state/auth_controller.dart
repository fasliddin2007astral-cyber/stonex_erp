import 'package:flutter/foundation.dart';

import '../data/repositories.dart';
import '../domain/models.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repo);
  final AuthRepository _repo;

  AppUser? user;
  bool loading = false;
  String? error;

  Future<void> login(String username, String password, Role role) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      // Rolni tanlash hech narsa bermaydi: server haqiqiy akkaunt va rolni tekshiradi.
      user = await _repo.login(username, password, role);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _repo.logout();
    user = null;
    notifyListeners();
  }
}
