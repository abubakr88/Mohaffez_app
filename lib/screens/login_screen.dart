// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../shared/constants/app_theme.dart';
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

    final state = ref.read(authNotifierProvider);

    if (mounted) {
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (state.hasValue) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الدخول بنجاح'),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/');
      }
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
                    AppTheme.primaryAmber,
                    AppTheme.lightAmber,
                    Colors.white,
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
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo with Shadow
                          Hero(
                            tag: 'app-logo',
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
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
                                width: 100,
                                height: 100,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.school,
                                  size: 100,
                                  color: AppTheme.primaryAmber,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Title
                          Text(
                            _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLogin
                                ? 'مرحبًا بعودتك!'
                                : 'انضم إلى مجتمع المحفظين',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Form Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
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
                                // Name Field (Sign Up Only)
                                if (!_isLogin) ...[
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: 'الاسم الكامل',
                                      prefixIcon: const Icon(Icons.person_outline),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'الرجاء إدخال الاسم';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
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
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال البريد الإلكتروني';
                                    }
                                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]{2,4}$')
                                        .hasMatch(value)) {
                                      return 'البريد الإلكتروني غير صحيح';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
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
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.length < 8) {
                                      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                                    }
                                    return null;
                                  },
                                ),
                                // Role Selection (Sign Up Only)
                                if (!_isLogin) ...[
                                  const SizedBox(height: 20),
                                  const Text(
                                    'اختر نوع الحساب',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RoleCard(
                                          icon: Icons.school,
                                          title: 'محفّظ',
                                          subtitle: 'معلم القرآن',
                                          color: AppTheme.primaryAmber,
                                          isSelected: _selectedRole == 'mohaffez',
                                          onTap: () {
                                            setState(() {
                                              _selectedRole = 'mohaffez';
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _RoleCard(
                                          icon: Icons.person,
                                          title: 'طالب',
                                          subtitle: 'دارس القرآن',
                                          color: AppTheme.accentGreen,
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
                                const SizedBox(height: 24),
                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryAmber,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
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
                          const SizedBox(height: 24),
                          // Toggle Login/SignUp
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _nameController.clear();
                              });
                            },
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.black87,
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
                                      color: AppTheme.primaryAmber,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? color : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
