import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import '../state/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Role _role = Role.values.first;
  bool _hidePassword = true;
  bool _isSurging = false;

  late final AnimationController _surgeController;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _videoError = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();

    _surgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _initVideo();
  }

  void _initVideo() {
    try {
      final ctrl = VideoPlayerController.asset('assets/videos/login_video.mp4');
      _videoController = ctrl;
      ctrl.initialize().then((_) {
        if (!mounted) return;
        ctrl.setLooping(true);
        ctrl.setVolume(0.0);
        ctrl.play();
        setState(() {
          _isVideoInitialized = true;
          _videoError = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _videoError = true;
          _isVideoInitialized = false;
        });
      });
    } catch (_) {
      _videoError = true;
      _isVideoInitialized = false;
    }
  }

  void _toggleMute() {
    if (!_isVideoInitialized || _videoController == null) return;
    final nextMuted = !_isMuted;
    _videoController!.setVolume(nextMuted ? 0.0 : 1.0);
    setState(() {
      _isMuted = nextMuted;
    });
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _surgeController.dispose();
    _videoController?.dispose();
    _videoController = null;
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isSurging) return;

    setState(() {
      _isSurging = true;
    });
    await _surgeController.forward(from: 0);

    if (!mounted) return;
    await context.read<AuthController>().login(
          _user.text.trim(),
          _pass.text,
          _role,
        );

    if (mounted) {
      setState(() {
        _isSurging = false;
      });
    }
  }

  void _fillDemo(String username, String pass, Role role) {
    setState(() {
      _user.text = username;
      _pass.text = pass;
      _role = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 920;

          if (isDesktop) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Orqa fonda to'liq video (Butun ekran bo'ylab jonli video o'ynaydi)
                Positioned.fill(
                  child: _buildVideoBackground(isMobile: false),
                ),

                // 2. Videoga umumiy qoramtirlik berish (video chuqur, kinomatografik tus oladi)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.42),
                    ),
                  ),
                ),

                // 3. Chap tomondagi nozik qo'shimcha gradient soya (matnlar tiniq o'qilishi uchun)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [0.0, 0.45, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Chap tomondagi yanada tiniqroq qoramtir shisha (Glassmorphism) karta
                SafeArea(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            width: 440,
                            constraints: BoxConstraints(
                              maxWidth: 440,
                              maxHeight: constraints.maxHeight - 48,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C1017).withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.50),
                                  blurRadius: 40,
                                  offset: const Offset(0, 16),
                                ),
                                BoxShadow(
                                  color: AppColors.neonLime.withValues(alpha: 0.12),
                                  blurRadius: 30,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              child: _buildForm(auth),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobil va planshet ekrani: Orqa fonda toza video, ustida shaffof qoramtir shisha karta
          return Stack(
            fit: StackFit.expand,
            children: [
              // Orqa fonda toza video
              _buildVideoBackground(isMobile: true),

              // Qoraytirish qatlami (videoni umumiy qoramtir qiladi)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),

              // Mobil forma kartasi (tiniq qoramtir shisha effektli)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                          constraints: const BoxConstraints(maxWidth: 480),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C1017).withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.50),
                                blurRadius: 36,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: AppColors.neonLime.withValues(alpha: 0.10),
                                blurRadius: 28,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: _buildForm(auth),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Toza video fon vidjeti (video ustida hech qanday ortiqcha yozuvlar yo'q)
  Widget _buildVideoBackground({required bool isMobile}) {
    if (_isVideoInitialized && !_videoError && _videoController != null) {
      final ctrl = _videoController!;
      return Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video o'zi (proporsiyani saqlab butun maydonni to'liq qoplaydi)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: ctrl.value.size.width > 0 ? ctrl.value.size.width : 16,
                height: ctrl.value.size.height > 0 ? ctrl.value.size.height : 9,
                child: VideoPlayer(ctrl),
              ),
            ),
          ),

          // 2. Faqat burchakdagi kichik, nozik ovoz tugmasi (yozuvsiz, faqat ikona)
          Positioned(
            top: 24,
            right: 24,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleMute,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Video hali joylanmagan bo'lsa xatosiz ko'rinadigan qora zaxira foni
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.2, -0.2),
              radius: 1.2,
              colors: [
                Color(0xFF161C24),
                Color(0xFF0F141A),
                Color(0xFF090C0F),
              ],
            ),
          ),
        ),
        CustomPaint(
          painter: _GridBackgroundPainter(),
        ),
      ],
    );
  }

  // Video fonidagi ranglarga moslashtirilgan kirish formasi
  Widget _buildForm(AuthController auth) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Sarlavha
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.neonLime,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonLime.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.token_rounded, color: Color(0xFF0C1015), size: 24),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STONEX',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'ERP & Vault Platform',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          const Text(
            'Tizimga kirish',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ish faoliyatingizni davom ettirish uchun hisobingizga kiring.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
          ),

          const SizedBox(height: 24),

          // Login maydoni
          const Text('Login', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFE2E8F0))),
          const SizedBox(height: 6),
          TextFormField(
            controller: _user,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF141A23).withValues(alpha: 0.60),
              hintText: 'Foydalanuvchi nomi',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.neonLime, width: 1.6),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Loginni kiriting' : null,
          ),
          const SizedBox(height: 16),

          // Parol maydoni
          const Text('Parol', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFE2E8F0))),
          const SizedBox(height: 6),
          TextFormField(
            controller: _pass,
            obscureText: _hidePassword,
            onFieldSubmitted: (_) => _login(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF141A23).withValues(alpha: 0.60),
              hintText: 'Parolingiz',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
              suffixIcon: IconButton(
                icon: Icon(
                  _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: const Color(0xFF94A3B8),
                ),
                onPressed: () {
                  setState(() {
                    _hidePassword = !_hidePassword;
                  });
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.neonLime, width: 1.6),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Parolni kiriting' : null,
          ),
          const SizedBox(height: 16),

          // Rol tanlash
          const Text('Rol', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFE2E8F0))),
          const SizedBox(height: 6),
          DropdownButtonFormField<Role>(
            value: _role,
            dropdownColor: const Color(0xFF161C24),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            iconEnabledColor: AppColors.neonLime,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF141A23).withValues(alpha: 0.60),
              prefixIcon: const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.neonLime, width: 1.6),
              ),
            ),
            items: Role.values
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.label, style: const TextStyle(color: Colors.white)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _role = v;
                });
              }
            },
          ),

          // Xatolik xabari
          if (auth.error != null && auth.error!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D1214),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF5E1B21)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.error!,
                      style: const TextStyle(color: Color(0xFFF87171), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Kirish tugmasi
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (auth.loading || _isSurging) ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonLime,
                foregroundColor: const Color(0xFF0A0E13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 4,
                shadowColor: AppColors.neonLime.withValues(alpha: 0.4),
              ),
              child: (auth.loading || _isSurging)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF0A0E13)),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Tizimga kirish', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),

          // Demo hisoblar
          if (AppConfig.useMock) ...[
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF222B36)),
            const SizedBox(height: 10),
            const Text(
              'TEZKOR DEMO HISOB BILAN KIRISH:',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  backgroundColor: const Color(0xFF141A23).withValues(alpha: 0.60),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  avatar: const Icon(Icons.admin_panel_settings_rounded, size: 15, color: AppColors.neonLime),
                  label: const Text('Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  onPressed: () => _fillDemo('admin', 'admin123', Role.admin),
                ),
                ActionChip(
                  backgroundColor: const Color(0xFF141A23).withValues(alpha: 0.60),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  avatar: const Icon(Icons.point_of_sale_rounded, size: 15, color: Color(0xFF38BDF8)),
                  label: const Text('Kassir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  onPressed: () => _fillDemo('kassir', 'kassir123', Role.kassir),
                ),
                ActionChip(
                  backgroundColor: const Color(0xFF141A23).withValues(alpha: 0.60),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  avatar: const Icon(Icons.handyman_rounded, size: 15, color: Color(0xFFFBBF24)),
                  label: const Text('Ishchi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  onPressed: () => _fillDemo('ishchi', 'ishchi123', Role.ishchi),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Orqa fon nozik cyber to'r chizuvchi (zaxira foni uchun)
class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF16191D)
      ..strokeWidth = 0.8;

    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
