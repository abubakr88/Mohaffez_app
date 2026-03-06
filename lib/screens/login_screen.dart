import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/theme/theme_extensions.dart';
import '../shared/widgets/offline_banner.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
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
          backgroundColor: AppThemeConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (state.hasValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الدخول بنجاح'),
          backgroundColor: AppThemeConstants.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final isLoading = state.isLoading;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppThemeConstants.primaryAmber,
                    AppThemeConstants.primaryAmberLight,
                    AppThemeConstants.surfaceWhite,
                  ],
                  stops: [0.0, 0.3, 1.0],
                ),
              ),
            ),
            const OfflineBanner(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _autoValidate
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        children: [
                          Hero(
                            tag: 'app-logo',
                            child: Container(
                              padding:
                                  const EdgeInsets.all(AppThemeConstants.spaceLg),
                              decoration: BoxDecoration(
                                color: AppThemeConstants.surfaceWhite,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/icon.png',
                                width: AppThemeConstants.icon3xl,
                                height: AppThemeConstants.icon3xl,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.school,
                                  size: AppThemeConstants.icon3xl,
                                  color: AppThemeConstants.primaryAmber,
                                ),
                              ),
                            ),
                          ),
                          Spacing.vXl,
                          Text(
                            'تسجيل الدخول',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppThemeConstants.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Spacing.vSm,
                          const Text(
                            'مرحبًا بعودتك!',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppThemeConstants.textSecondary,
                            ),
                          ),
                          const SizedBox(
                            height: AppThemeConstants.spaceXl +
                                AppThemeConstants.spaceSm,
                          ),
                          Container(
                            padding:
                                const EdgeInsets.all(AppThemeConstants.spaceLg),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.surfaceWhite,
                              borderRadius: AppThemeConstants.borderRadiusXl,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(
                                    labelText: 'البريد الإلكتروني',
                                    prefixIcon: Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          AppThemeConstants.borderRadiusMd,
                                    ),
                                    filled: true,
                                    fillColor: AppThemeConstants.backgroundLight,
                                    errorMaxLines: 2,
                                  ),
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
                                Spacing.vMd,
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'كلمة المرور',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: const OutlineInputBorder(
                                      borderRadius:
                                          AppThemeConstants.borderRadiusMd,
                                    ),
                                    filled: true,
                                    fillColor: AppThemeConstants.backgroundLight,
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
                                Spacing.vLg,
                                SizedBox(
                                  width: double.infinity,
                                  height: AppThemeConstants.buttonHeightLarge,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppThemeConstants.primaryAmber,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius:
                                            AppThemeConstants.borderRadiusMd,
                                      ),
                                      elevation: AppThemeConstants.elevationSm,
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                AppThemeConstants.surfaceWhite,
                                              ),
                                            ),
                                          )
                                        : const Text(
                                            'تسجيل الدخول',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: AppThemeConstants.spaceLg),
                                const Row(
                                  children: [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppThemeConstants.spaceMd,
                                      ),
                                      child: Text('أو'),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: AppThemeConstants.spaceLg),
                                SizedBox(
                                  width: double.infinity,
                                  height: AppThemeConstants.buttonHeightMedium,
                                  child: OutlinedButton(
                                    onPressed: () => context.push('/register'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          AppThemeConstants.primaryAmber,
                                      side: const BorderSide(
                                        color: AppThemeConstants.primaryAmber,
                                      ),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius:
                                            AppThemeConstants.borderRadiusMd,
                                      ),
                                    ),
                                    child: const Text(
                                      'إنشاء حساب جديد',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
