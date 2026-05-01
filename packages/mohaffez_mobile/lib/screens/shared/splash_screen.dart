// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/theme/theme_extensions.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _maxWait = Duration(seconds: 5);

  late final AnimationController _ctrl;

  // Logo
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // Title
  late final Animation<double> _titleFade;
  late final Animation<double> _titleSlide;

  // Ornament + subtitle
  late final Animation<double> _ornamentFade;
  late final Animation<double> _subtitleFade;

  // Spinner
  late final Animation<double> _spinnerFade;

  bool _timedOut = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<double>(begin: 28.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );
    _ornamentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.55, 0.8, curve: Curves.easeOut),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.62, 0.88, curve: Curves.easeOut),
      ),
    );
    _spinnerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.78, 1.0, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward();
    _scheduleTimeout();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _scheduleTimeout() {
    Future.delayed(_maxWait, () {
      if (mounted) {
        setState(() {
          _timedOut = true;
          _errorMsg = 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.';
        });
      }
    });
  }

  void _retry() {
    setState(() {
      _timedOut = false;
      _errorMsg = null;
    });
    _ctrl.forward(from: 0.0);
    _scheduleTimeout();
    ref.invalidate(authStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    if (_timedOut && authAsync.isLoading) {
      return _buildTimeoutScreen();
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppThemeConstants.tealGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Big logo with glow ──
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: _buildLogo(),
                ),
              ),

              const SizedBox(height: AppThemeConstants.spaceXl),

              // ── App name ──
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, child) => Opacity(
                  opacity: _titleFade.value,
                  child: Transform.translate(
                    offset: Offset(0, _titleSlide.value),
                    child: child,
                  ),
                ),
                child: Text(
                  'محفظ',
                  style: context.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.white,
                    letterSpacing: 4,
                  ),
                ),
              ),

              const SizedBox(height: AppThemeConstants.spaceMd),

              // ── Gold ornamental divider ──
              FadeTransition(
                opacity: _ornamentFade,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppThemeConstants.space3xl),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppThemeConstants.transparent,
                                AppThemeConstants.secondary
                                    .withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.star_rounded,
                          color: AppThemeConstants.secondary,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppThemeConstants.secondary
                                    .withValues(alpha: 0.8),
                                AppThemeConstants.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppThemeConstants.spaceMd),

              // ── Subtitle ──
              FadeTransition(
                opacity: _subtitleFade,
                child: Text(
                  'تطبيق تحفيظ القرآن الكريم',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: AppThemeConstants.white.withValues(alpha: 0.75),
                    letterSpacing: 1,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Loading indicator / status ──
              FadeTransition(
                opacity: _spinnerFade,
                child: Column(
                  children: [
                    if (authAsync.isLoading)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppThemeConstants.white),
                        ),
                      ),
                    if (authAsync.hasError) ...[
                      const Icon(Icons.error_outline,
                          color: AppThemeConstants.white, size: 28),
                      const SizedBox(height: AppThemeConstants.spaceSm),
                      ElevatedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeConstants.white,
                          foregroundColor: AppThemeConstants.primary,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppThemeConstants.spaceXl,
                            vertical: AppThemeConstants.spaceMd,
                          ),
                        ),
                      ),
                    ],
                    if (!authAsync.hasError) ...[
                      const SizedBox(height: AppThemeConstants.spaceMd),
                      Text(
                        _statusText(authAsync),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppThemeConstants.white.withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppThemeConstants.space2xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppThemeConstants.white,
        boxShadow: [
          BoxShadow(
            color: AppThemeConstants.secondary.withValues(alpha: 0.45),
            blurRadius: 40,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: AppThemeConstants.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppThemeConstants.secondary.withValues(alpha: 0.55),
          width: 2.5,
        ),
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Image.asset(
            'assets/images/icon.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.school,
              size: 80,
              color: AppThemeConstants.primary,
            ),
          ),
        ),
      ),
    );
  }

  static String _statusText(AsyncValue<dynamic> authAsync) {
    if (authAsync.isLoading) return 'جاري التحميل...';
    if (authAsync.hasError) return 'حدث خطأ في تسجيل الدخول';
    if (authAsync.value == null) return 'جاري التحقق...';
    return 'مرحباً بك';
  }

  Widget _buildTimeoutScreen() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppThemeConstants.tealGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppThemeConstants.spaceXl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppThemeConstants.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeConstants.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      size: AppThemeConstants.icon2xl,
                      color: AppThemeConstants.warning,
                    ),
                  ),
                  const SizedBox(height: AppThemeConstants.spaceXl),
                  Text(
                    'مشكلة في الاتصال',
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppThemeConstants.spaceMd),
                  Text(
                    _errorMsg ?? 'حدث خطأ في الاتصال',
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: AppThemeConstants.white.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(
                      height: AppThemeConstants.spaceXl +
                          AppThemeConstants.spaceSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeConstants.white,
                          foregroundColor: AppThemeConstants.primary,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppThemeConstants.spaceLg,
                            vertical: AppThemeConstants.spaceMd,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppThemeConstants.spaceMd),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.login),
                        label: const Text('تسجيل الدخول'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppThemeConstants.white,
                          side: const BorderSide(color: AppThemeConstants.white, width: 2),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppThemeConstants.spaceLg,
                            vertical: AppThemeConstants.spaceMd,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
