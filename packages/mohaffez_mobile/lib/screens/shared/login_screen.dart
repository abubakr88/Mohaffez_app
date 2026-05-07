import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/offline_banner.dart';

// ============================================================
// PREMIUM LOGIN THEME
// ============================================================
class _LoginTheme {
  static const Color deepTeal = Color(0xFF0B4A4A);
  static const Color midTeal = Color(0xFF0D5C5C);
  static const Color primaryTeal = Color(0xFF0B7A75);
  static const Color lightTeal = Color(0xFF14B8A6);
  static const Color softGold = Color(0xFFD4A44A);
  static const Color textPrimary = Color(0xFF1E2933);
  static const Color textMuted = Color(0xFF9CA3AF);
  
  static const List<Color> tealGradient = [
    deepTeal,
    midTeal,
    primaryTeal,
  ];
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _autoValidate = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.signInWithGoogle();

    if (!mounted) return;
    final state = ref.read(authNotifierProvider);

    if (state.hasError) {
      final error = state.error;
      if (error is NeedsRoleSelectionException) {
        context.push('/google-role-selection', extra: {
          'name': error.name,
          'email': error.email,
          'photoUrl': error.photoUrl,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _autoValidate = true;
    });
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    final state = ref.read(authNotifierProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error.toString()),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final isLoading = state.isLoading;

    final loginBody = Stack(
      children: [
        // ── Gradient Background ─────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _LoginTheme.tealGradient,
            ),
          ),
        ),

        // ── Islamic Geometric Pattern (Subtle) ──────────────
        CustomPaint(
          size: Size.infinite,
          painter: _IslamicPatternPainter(),
        ),

        const OfflineBanner(),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      // ── Logo with Soft Shadow ─────────────────
                      _buildLogo(),
                      const SizedBox(height: 32),

                      // ── Title & Subtitle ─────────────────────
                      const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppThemeConstants.onPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'مرحباً بعودتك 👋',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppThemeConstants.onPrimary.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── Login Card ────────────────────────────
                      _buildLoginCard(isLoading),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: kIsWeb
            ? Container(
                color: const Color(0xFF0B7A75), // AppThemeConstants.primary
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ClipRect(child: loginBody),
                  ),
                ),
              )
            : loginBody,
      ),
    );
  }

  Widget _buildLogo() {
    return Hero(
      tag: 'app-logo',
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppThemeConstants.surface,
          shape: BoxShape.circle,
          boxShadow: [
            const BoxShadow(
              color: AppThemeConstants.shadow,
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: _LoginTheme.softGold.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Center(
          child: ClipOval(
            child: Image.asset(
              'assets/images/icon.png',
              width: 85,
              height: 85,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_LoginTheme.primaryTeal, _LoginTheme.lightTeal],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppThemeConstants.onPrimary,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: AppThemeConstants.shadow,
            blurRadius: 40,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: AppThemeConstants.shadow,
            blurRadius: 60,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: _autoValidate
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Email Input ────────────────────────────────
            _buildTextField(
              controller: _emailController,
              label: 'البريد الإلكتروني',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'الرجاء إدخال البريد الإلكتروني';
                }
                final emailRegex = RegExp(
                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                );
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'البريد الإلكتروني غير صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            // ── Password Input ────────────────────────────
            _buildTextField(
              controller: _passwordController,
              label: 'كلمة المرور',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _LoginTheme.textMuted,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال كلمة المرور';
                }
                if (value.length < 8) {
                  return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                }
                return null;
              },
            ),
            
            // ── Forgot Password ───────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                style: TextButton.styleFrom(
                  foregroundColor: _LoginTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text(
                  'نسيت كلمة المرور؟',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // ── Primary Button ────────────────────────────
            SizedBox(
              height: 68,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.transparent,
                  shadowColor: AppThemeConstants.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        _LoginTheme.primaryTeal,
                        _LoginTheme.lightTeal,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _LoginTheme.primaryTeal.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppThemeConstants.onPrimary,
                              ),
                            ),
                          )
                        : const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppThemeConstants.onPrimary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ── Divider ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppThemeConstants.transparent,
                          _LoginTheme.textMuted.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'أو',
                    style: TextStyle(
                      fontSize: 13,
                      color: _LoginTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _LoginTheme.textMuted.withValues(alpha: 0.3),
                          AppThemeConstants.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // ── Secondary Button ──────────────────────────
            SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: () => context.push('/register'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _LoginTheme.primaryTeal,
                  side: BorderSide(
                    color: _LoginTheme.primaryTeal.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'إنشاء حساب جديد',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textDirection: keyboardType == TextInputType.emailAddress
          ? TextDirection.ltr
          : TextDirection.rtl,
      style: const TextStyle(
        fontSize: 15,
        color: _LoginTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: _LoginTheme.textMuted,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: _LoginTheme.primaryTeal,
          size: 22,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _LoginTheme.primaryTeal,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      validator: validator,
    );
  }
}

// ============================================================
// ISLAMIC GEOMETRIC PATTERN PAINTER
// ============================================================
class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppThemeConstants.surface.withValues(alpha: 0.07)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const spacing = 64.0;
    bool rowOffset = false;

    for (double y = spacing * 0.5; y < size.height + spacing; y += spacing) {
      final xStart = rowOffset ? spacing * 0.5 : 0.0;
      for (double x = xStart; x < size.width + spacing; x += spacing) {
        _drawCrescent(canvas, Offset(x, y), 12, paint);
      }
      rowOffset = !rowOffset;
    }
  }

  void _drawCrescent(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    // Outer arc: full circle
    path.addArc(
      Rect.fromCircle(center: center, radius: r),
      3.14159 * 0.25,   // start at ~bottom-left
      3.14159 * 1.5,    // sweep 270° (leaving right side open)
    );
    // Inner arc: offset circle that creates the crescent cutout
    final innerCenter = Offset(center.dx + r * 0.35, center.dy);
    path.addArc(
      Rect.fromCircle(center: innerCenter, radius: r * 0.78),
      3.14159 * 1.25,
      -3.14159 * 1.5,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
