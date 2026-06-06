import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authNotifierProvider.notifier)
        .resetPassword(_emailController.text.trim());

    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState.hasError) {
      ErrorHandler.showError(context, authState.error);
    } else {
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        appBar: AppBar(
          backgroundColor: AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.onPrimary,
          elevation: 0,
          title: const Text(
            'نسيت كلمة المرور',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _sent ? _successState() : _formState(isLoading),
          ),
        ),
      ),
    );
  }

  Widget _formState(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppThemeConstants.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            size: 40,
            color: AppThemeConstants.primary,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'استعادة كلمة المرور',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'البريد الإلكتروني',
              labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: AppThemeConstants.primary,
                size: 22,
              ),
              filled: true,
              fillColor: AppThemeConstants.white,
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
                  color: AppThemeConstants.primary,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppThemeConstants.error, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppThemeConstants.error, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'الرجاء إدخال البريد الإلكتروني';
              final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
              if (!emailRegex.hasMatch(v.trim())) return 'البريد الإلكتروني غير صحيح';
              return null;
            },
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeConstants.primary,
              foregroundColor: AppThemeConstants.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppThemeConstants.onPrimary,
                      ),
                    ),
                  )
                : const Text(
                    'إرسال رابط الاستعادة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
          child: const Text(
            'العودة لتسجيل الدخول',
            style: TextStyle(
              color: AppThemeConstants.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _successState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppThemeConstants.secondary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 44,
            color: AppThemeConstants.secondary,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'تم إرسال الرابط!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'تم إرسال رابط إعادة تعيين كلمة المرور إلى\n${_emailController.text.trim()}\n\nتفقّد بريدك الإلكتروني واتبع التعليمات.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.7,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeConstants.primary,
              foregroundColor: AppThemeConstants.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'العودة لتسجيل الدخول',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
