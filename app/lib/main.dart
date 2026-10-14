import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player_win/video_player_win_plugin.dart';

import 'core/theme.dart';
import 'data/repositories.dart';
import 'data/repository_factory.dart';
import 'state/auth_controller.dart';
import 'state/cart_controller.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      WindowsVideoPlayer.registerWith();
    }
  } catch (_) {
    // Video player plaginini ro'yxatdan o'tkazish xatosi bo'lsa ilovani to'xtatmaslik
  }
  final repos = buildRepositories();
  runApp(StonexApp(repos: repos));
}

class StonexApp extends StatelessWidget {
  const StonexApp({super.key, required this.repos});
  final AppRepositories repos;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppRepositories>.value(value: repos),
        ChangeNotifierProvider(create: (_) => AuthController(repos.auth)),
        ChangeNotifierProvider(create: (_) => CartController(repos.sales)),
      ],
      child: MaterialApp(
        title: 'STONEX ERP',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Consumer<AuthController>(
          builder: (_, auth, __) => auth.user == null ? const LoginScreen() : HomeShell(user: auth.user!),
        ),
      ),
    );
  }
}
