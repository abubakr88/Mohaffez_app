import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/theme_extensions.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _autoValidate = false;
  String _selectedRole = 'student';
  String _selectedGender = 'male';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _autoValidate = true;
    });
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      role: _selectedRole,
      gender: _selectedGender,
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
          content: Text('تم إنشاء الحساب بنجاح'),
          backgroundColor: AppThemeConstants.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final isLoading = state.isLoading;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إنشاء حساب جديد'),
          backgroundColor: AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.onPrimary,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
            child: Form(
              key: _formKey,
              autovalidateMode: _autoValidate
                  ? AutovalidateMode.onUnfocus
                  : AutovalidateMode.disabled,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                    decoration: const BoxDecoration(
                      color: AppThemeConstants.surface,
                      borderRadius: AppThemeConstants.borderRadiusXl,
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeConstants.shadow,
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'الاسم الكامل',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: AppThemeConstants.borderRadiusMd,
                            ),
                            filled: true,
                            fillColor: AppThemeConstants.background,
                          ),
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
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: AppThemeConstants.borderRadiusMd,
                            ),
                            filled: true,
                            fillColor: AppThemeConstants.background,
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
                              borderRadius: AppThemeConstants.borderRadiusMd,
                            ),
                            filled: true,
                            fillColor: AppThemeConstants.background,
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
                        const SizedBox(height: AppThemeConstants.spaceLg),
                        Row(
                          children: [
                            Expanded(
                              child: _GenderCard(
                                title: _selectedRole == 'student' ? 'طالب' : 'معلم',
                                color: AppThemeConstants.primary,
                                isSelected: _selectedGender == 'male',
                                onTap: () {
                                  setState(() {
                                    _selectedGender = 'male';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(
                              width: AppThemeConstants.spaceMd -
                                  AppThemeConstants.spaceXs,
                            ),
                            Expanded(
                              child: _GenderCard(
                                title: _selectedRole == 'student' ? 'طالبة' : 'معلمة',
                                color: AppThemeConstants.secondary,
                                isSelected: _selectedGender == 'female',
                                onTap: () {
                                  setState(() {
                                    _selectedGender = 'female';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppThemeConstants.spaceLg),
                        const Text(
                          'اختر نوع الحساب',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(
                          height: AppThemeConstants.spaceMd -
                              AppThemeConstants.spaceXs,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _RoleCard(
                                icon: Icons.school,
                                title: 'محفّظ',
                                subtitle: 'معلم القرآن',
                                color: AppThemeConstants.primary,
                                isSelected: _selectedRole == 'mohaffez',
                                onTap: () {
                                  setState(() {
                                    _selectedRole = 'mohaffez';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(
                              width: AppThemeConstants.spaceMd -
                                  AppThemeConstants.spaceXs,
                            ),
                            Expanded(
                              child: _RoleCard(
                                icon: Icons.person,
                                title: 'طالب',
                                subtitle: 'دارس القرآن',
                                color: AppThemeConstants.secondary,
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
                        Spacing.vLg,
                        SizedBox(
                          width: double.infinity,
                          height: AppThemeConstants.buttonHeightLarge,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeConstants.primary,
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppThemeConstants.borderRadiusMd,
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppThemeConstants.onPrimary,
                                    ),
                                  )
                                : const Text(
                                    'إنشاء حساب',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppThemeConstants.spaceMd),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('لديك حساب بالفعل؟ تسجيل الدخول'),
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
    );
  }
}

class _GenderCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    this.icon,
    required this.title,
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
          color:
              isSelected ? color.withValues(alpha: 0.1) : AppThemeConstants.background,
          borderRadius: AppThemeConstants.borderRadiusMd,
          border: Border.all(
            color: isSelected ? color : AppThemeConstants.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 48,
                color: isSelected ? color : AppThemeConstants.textDisabled,
              ),
              Spacing.vSm,
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : AppThemeConstants.textSecondary,
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
        padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.1) : AppThemeConstants.background,
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
              style: const TextStyle(
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
