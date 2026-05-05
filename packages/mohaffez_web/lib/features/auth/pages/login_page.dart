import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/design_system.dart';
import '../auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;
    ref.read(authProvider.notifier).signIn(email, password);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, next) {
      if (!mounted) return;
      if (next.step == AuthStep.done && next.role != null) {
        switch (next.role) {
          case 'mohaffez': context.go('/t');
          case 'admin':    context.go('/admin');
          default:         context.go('/s');
        }
      }
    });

    final isLoading = auth.step == AuthStep.loading;

    return Scaffold(
      backgroundColor: DSColors.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DSSpacing.xl),
          child: Container(
            width: 440,
            decoration: BoxDecoration(
              color: DSColors.surface,
              borderRadius: DSRadius.xlAll,
              boxShadow: DSElevation.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                const Divider(height: 1, color: DSColors.border),
                Padding(
                  padding: const EdgeInsets.all(DSSpacing.xxl),
                  child: _buildForm(context, auth, isLoading),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DSSpacing.xxl, DSSpacing.xxl, DSSpacing.xxl, DSSpacing.lg,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: DSColors.primary,
              borderRadius: DSRadius.lgAll,
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: DSSpacing.lg),
          Text('المحفظ', style: DSText.display(context, color: DSColors.primary)),
          const SizedBox(height: DSSpacing.xs),
          Text(
            'منصة تحفيظ القرآن الكريم',
            style: DSText.body(context, color: DSColors.text2),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, AuthState auth, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('تسجيل الدخول', style: DSText.h2(context)),
        const SizedBox(height: DSSpacing.xs),
        Text(
          'أدخل بريدك الإلكتروني وكلمة المرور',
          style: DSText.body(context, color: DSColors.text2),
        ),
        const SizedBox(height: DSSpacing.xl),
        DSTextField(
          controller: _emailCtrl,
          label: 'البريد الإلكتروني',
          hint: 'example@email.com',
          keyboardType: TextInputType.emailAddress,
          leading: const Icon(Icons.email_outlined, size: 18, color: DSColors.text3),
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: DSSpacing.md),
        DSTextField(
          controller: _passwordCtrl,
          label: 'كلمة المرور',
          hint: '••••••••',
          obscureText: _obscure,
          leading: const Icon(Icons.lock_outline, size: 18, color: DSColors.text3),
          trailing: IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18,
              color: DSColors.text3,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (auth.errorMessage != null) ...[
          const SizedBox(height: DSSpacing.md),
          DSBanner(
            message: auth.errorMessage!,
            variant: DSBannerVariant.error,
          ),
        ],
        const SizedBox(height: DSSpacing.xl),
        DSButton(
          label: isLoading ? 'جارٍ تسجيل الدخول...' : 'تسجيل الدخول',
          fullWidth: true,
          size: DSButtonSize.lg,
          onPressed: isLoading ? null : _submit,
        ),
        const SizedBox(height: DSSpacing.lg),
        Center(
          child: Text(
            'بتسجيل الدخول توافق على شروط الاستخدام وسياسة الخصوصية',
            style: DSText.caption(context, color: DSColors.text3),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
