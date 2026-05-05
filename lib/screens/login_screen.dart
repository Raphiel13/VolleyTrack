import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';

// ─── Login Screen ─────────────────────────────────────────────────────────────

// Ekran logowania i rejestracji — jeden widok przełączany animacją zamiast dwóch oddzielnych ekranów
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // Przełączanie trybu z animacją — cofnięcie animacji przed zmianą stanu, by uniknąć migotania
  void _switchMode() {
    _animCtrl.reverse().then((_) {
      setState(() {
        _isLogin = !_isLogin;
        _error = null;
      });
      _animCtrl.forward();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      if (_isLogin) {
        await repo.signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await repo.signUpWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
        );
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      print('Google Sign In UI error: ${e.runtimeType}: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Tłumaczenie kodów błędów Firebase na komunikaty w języku polskim
  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') || raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Nieprawidłowy email lub hasło.';
    }
    if (raw.contains('email-already-in-use')) {
      return 'Ten email jest już zarejestrowany.';
    }
    if (raw.contains('weak-password')) return 'Hasło jest za słabe (min. 6 znaków).';
    if (raw.contains('invalid-email')) return 'Nieprawidłowy adres email.';
    if (raw.contains('network-request-failed')) return 'Brak połączenia z internetem.';
    return 'Coś poszło nie tak. Spróbuj ponownie.';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ──────────────────────────────────────────────────
                  const SizedBox(height: 8),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'VolleyManager',
                      style: AppTheme.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: t.label,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _isLogin ? 'Zaloguj się, aby kontynuować' : 'Utwórz nowe konto',
                      style: AppTheme.inter(fontSize: 15, color: t.label2),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Form ──────────────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          _Field(
                            controller: _nameCtrl,
                            hint: 'Imię i nazwisko',
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.trim().length < 2)
                                ? 'Podaj imię i nazwisko'
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _Field(
                          controller: _emailCtrl,
                          hint: 'Email',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              (v == null || !v.contains('@')) ? 'Podaj poprawny email' : null,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _passwordCtrl,
                          hint: 'Hasło',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                              color: t.label3,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Hasło musi mieć min. 6 znaków'
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // ── Error ─────────────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        _error!,
                        style: AppTheme.inter(fontSize: 13, color: AppColors.red),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Primary button ────────────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isLogin ? 'Zaloguj się' : 'Utwórz konto'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Divider ───────────────────────────────────────────────
                  Row(children: [
                    Expanded(child: Divider(color: t.separator)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('lub',
                          style: AppTheme.inter(fontSize: 13, color: t.label3)),
                    ),
                    Expanded(child: Divider(color: t.separator)),
                  ]),

                  const SizedBox(height: 16),

                  // ── Google Sign-In ────────────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: t.separator, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        foregroundColor: t.label,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google 'G' logo
                          _GoogleLogo(size: 20, dark: isDark),
                          const SizedBox(width: 10),
                          Text(
                            'Kontynuuj z Google',
                            style: AppTheme.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: t.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Switch mode ───────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? 'Nie masz konta? ' : 'Masz już konto? ',
                        style: AppTheme.inter(fontSize: 14, color: t.label2),
                      ),
                      GestureDetector(
                        onTap: _loading ? null : _switchMode,
                        child: Text(
                          _isLogin ? 'Zarejestruj się' : 'Zaloguj się',
                          style: AppTheme.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Field helper ─────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTheme.inter(fontSize: 16, color: t.label),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: t.label3),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ─── Google Logo ──────────────────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  final double size;
  final bool dark;

  const _GoogleLogo({required this.size, required this.dark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

// Rysowanie logo Google za pomocą CustomPainter — odwzorowanie barw i kształtu znaku 'G'
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    // Clip to circle
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // Background
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Draw 'G' shape via colored arcs
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75);

    paint.color = const Color(0xFFEA4335); // red
    canvas.drawArc(rect, -0.52, 1.57, true, paint);

    paint.color = const Color(0xFF34A853); // green
    canvas.drawArc(rect, 1.05, 1.57, true, paint);

    paint.color = const Color(0xFFFBBC05); // yellow
    canvas.drawArc(rect, 2.62, 0.79, true, paint);

    paint.color = const Color(0xFF4285F4); // blue
    canvas.drawArc(rect, -1.57, 1.05, true, paint);

    // Center white circle (donut shape)
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.42, paint);

    // Right bar of G
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.13, r * 0.75, r * 0.26),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
