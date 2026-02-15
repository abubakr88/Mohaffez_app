// FILE: lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _obscurePassword = true;
  String _selectedRole = 'student';
  
  // ✅ NEW: Form validation state
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
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // ✅ Enable auto-validation after first submit attempt
    setState(() {
      _autoValidate = true;
    });

    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);

    if (_isLogin) {
      await notifier.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } else {
      await notifier.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        role: _selectedRole,
      );
    }

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
            // Gradient Background
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
            // Offline Banner
            const OfflineBanner(),
            // Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Form(
                      key: _formKey,
                      // ✅ IMPROVED: Enable auto-validation mode
                      autovalidateMode: _autoValidate
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo with Shadow
                          Hero(
                            tag: 'app-logo',
                            child: Container(
                              padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                              decoration: BoxDecoration(
                                color: AppThemeConstants.surfaceWhite,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
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
                          // Title
                          Text(
                            _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppThemeConstants.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Spacing.vSm,
                          Text(
                            _isLogin
                                ? 'مرحبًا بعودتك!'
                                : 'انضم إلى مجتمع المحفظين',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppThemeConstants.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppThemeConstants.spaceXl + AppThemeConstants.spaceSm),
                          // Form Card
                          Container(
                            padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.surfaceWhite,
                              borderRadius: AppThemeConstants.borderRadiusXl,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Name Field (Sign Up Only)
                                if (!_isLogin) ...[
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: 'الاسم الكامل',
                                      prefixIcon: const Icon(Icons.person_outline),
                                      border: OutlineInputBorder(
                                        borderRadius: AppThemeConstants.borderRadiusMd,
                                      ),
                                      filled: true,
                                      fillColor: AppThemeConstants.backgroundLight,
                                      // ✅ NEW: Error styling
                                      errorMaxLines: 2,
                                    ),
                                    // ✅ IMPROVED: Better validation messages
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'الرجاء إدخال الاسم الكامل';
                                      }
                                      if (value.trim().length < 3) {
                                        return 'الاسم يجب أن يكون 3 أحرف على الأقل';
                                      }
                                      return null;
                                    },
                                  ),
                                  Spacing.vMd,
                                ],
                                // Email Field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: TextDirection.ltr,
                                  decoration: InputDecoration(
                                    labelText: 'البريد الإلكتروني',
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: AppThemeConstants.borderRadiusMd,
                                    ),
                                    filled: true,
                                    fillColor: AppThemeConstants.backgroundLight,
                                    errorMaxLines: 2,
                                  ),
                                  // ✅ IMPROVED: Better email validation
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
                                // Password Field
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
                                    border: OutlineInputBorder(
                                      borderRadius: AppThemeConstants.borderRadiusMd,
                                    ),
                                    filled: true,
                                    fillColor: AppThemeConstants.backgroundLight,
                                    errorMaxLines: 3,
                                  ),
                                  // ✅ IMPROVED: More detailed password validation
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال كلمة المرور';
                                    }
                                    if (value.length < 8) {
                                      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                                    }
                                    if (!_isLogin && value.length < 8) {
                                      // Additional validation for signup
                                      if (!value.contains(RegExp(r'[A-Z]'))) {
                                        return 'يجب أن تحتوي على حرف كبير واحد على الأقل';
                                      }
                                      if (!value.contains(RegExp(r'[0-9]'))) {
                                        return 'يجب أن تحتوي على رقم واحد على الأقل';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                // Role Selection (Sign Up Only)
                                if (!_isLogin) ...[
                                  const SizedBox(height: AppThemeConstants.spaceLg - AppThemeConstants.spaceSm),
                                  const Text(
                                    'اختر نوع الحساب',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppThemeConstants.spaceMd - AppThemeConstants.spaceXs),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RoleCard(
                                          icon: Icons.school,
                                          title: 'محفّظ',
                                          subtitle: 'معلم القرآن',
                                          color: AppThemeConstants.primaryAmber,
                                          isSelected: _selectedRole == 'mohaffez',
                                          onTap: () {
                                            setState(() {
                                              _selectedRole = 'mohaffez';
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppThemeConstants.spaceMd - AppThemeConstants.spaceXs),
                                      Expanded(
                                        child: _RoleCard(
                                          icon: Icons.person,
                                          title: 'طالب',
                                          subtitle: 'دارس القرآن',
                                          color: AppThemeConstants.accentGreen,
                                          isSelected: _selectedRole == 'student',
                                          onTap: () {
                                            setState(() {
                                              _selectedRole = 'student';
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                Spacing.vLg,
                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  height: AppThemeConstants.buttonHeightLarge,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppThemeConstants.primaryAmber,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: AppThemeConstants.borderRadiusMd,
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
                                                      AppThemeConstants.surfaceWhite),
                                            ),
                                          )
                                        : Text(
                                            _isLogin
                                                ? 'تسجيل الدخول'
                                                : 'إنشاء حساب',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Spacing.vLg,
                          // Toggle Login/SignUp
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _nameController.clear();
                                // ✅ Reset auto-validation when switching modes
                                _autoValidate = false;
                              });
                            },
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: AppThemeConstants.textPrimary,
                                  fontSize: 15,
                                ),
                                children: [
                                  TextSpan(
                                    text: _isLogin
                                        ? 'ليس لديك حساب؟ '
                                        : 'لديك حساب بالفعل؟ ',
                                  ),
                                  TextSpan(
                                    text: _isLogin
                                        ? 'إنشاء حساب جديد'
                                        : 'تسجيل الدخول',
                                    style: const TextStyle(
                                      color: AppThemeConstants.primaryAmber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
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

// Role Selection Card
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppThemeConstants.backgroundLight,
          borderRadius: AppThemeConstants.borderRadiusMd,
          border: Border.all(
            color: isSelected ? color : AppThemeConstants.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? color : AppThemeConstants.textDisabled,
            ),
            Spacing.vSm,
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : AppThemeConstants.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppThemeConstants.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


