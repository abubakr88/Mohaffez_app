import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _phoneFocus = FocusNode();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  String get _phone => _phoneCtrl.text.trim();
  String get _otp => _otpCtrl.text.trim();

  void _sendOtp() {
    if (_phone.length < 9) return;
    ref.read(authProvider.notifier).sendOtp(_phone);
  }

  void _verifyOtp() {
    if (_otp.length != 6) return;
    ref.read(authProvider.notifier).verifyOtp(_otp);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // Navigate on successful auth
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
                  child: switch (auth.step) {
                    AuthStep.loading => _buildLoading(context),
                    AuthStep.otp    => _buildOtpForm(context, auth),
                    _               => _buildPhoneForm(context, auth),
                  },
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

  Widget _buildPhoneForm(BuildContext context, AuthState auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('تسجيل الدخول', style: DSText.h2(context)),
        const SizedBox(height: DSSpacing.xs),
        Text(
          'أدخل رقم هاتفك لتلقّي رمز التحقق',
          style: DSText.body(context, color: DSColors.text2),
        ),
        const SizedBox(height: DSSpacing.xl),
        DSTextField(
          controller: _phoneCtrl,
          label: 'رقم الهاتف',
          hint: '+966XXXXXXXXX',
          keyboardType: TextInputType.phone,
          focusNode: _phoneFocus,
          leading: const Icon(Icons.phone_outlined, size: 18, color: DSColors.text3),
          onSubmitted: (_) => _sendOtp(),
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
          label: 'إرسال رمز التحقق',
          fullWidth: true,
          size: DSButtonSize.lg,
          onPressed: _sendOtp,
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

  Widget _buildOtpForm(BuildContext context, AuthState auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('رمز التحقق', style: DSText.h2(context)),
        const SizedBox(height: DSSpacing.xs),
        Text(
          'أُرسل رمز مكوّن من 6 أرقام إلى ${auth.phone ?? ''}',
          style: DSText.body(context, color: DSColors.text2),
        ),
        const SizedBox(height: DSSpacing.xl),
        TextFormField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: DSText.h1(context).copyWith(letterSpacing: 8),
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: DSText.h1(context, color: DSColors.text3).copyWith(letterSpacing: 8),
            counterText: '',
            filled: true,
            fillColor: DSColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DSSpacing.lg,
              vertical: DSSpacing.lg,
            ),
            border: const OutlineInputBorder(
              borderRadius: DSRadius.mdAll,
              borderSide: BorderSide(color: DSColors.border),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: DSRadius.mdAll,
              borderSide: BorderSide(color: DSColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: DSRadius.mdAll,
              borderSide: BorderSide(color: DSColors.primary, width: 2),
            ),
          ),
          onChanged: (v) {
            if (v.length == 6) _verifyOtp();
          },
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
          label: 'تحقق',
          fullWidth: true,
          size: DSButtonSize.lg,
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: DSSpacing.md),
        Center(
          child: TextButton(
            onPressed: () => ref.read(authProvider.notifier).backToPhone(),
            child: Text(
              'تغيير رقم الهاتف',
              style: DSText.body(context, color: DSColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: DSSpacing.xl),
        const CircularProgressIndicator(color: DSColors.primary),
        const SizedBox(height: DSSpacing.lg),
        Text('جارٍ التحقق...', style: DSText.body(context, color: DSColors.text2)),
        const SizedBox(height: DSSpacing.xl),
      ],
    );
  }
}
