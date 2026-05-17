// lib/screens/student/wallet_topup_screen.dart
//
// User submits a top-up request after sending money via bank/wallet.
// Admin verifies it server-side via verifyWalletTopUp; only then does the
// balance change.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

// Account details shown to the user. In a real deploy these come from
// systemConfig — hardcoded here as a placeholder until that's wired.
const _kPlatformAccounts = {
  'instapay': '01012345678',
  'vodafone_cash': '01012345678',
  'bank_transfer': 'IBAN: EG00 0000 0000 0000 0000 0000',
};

const _kMethodLabels = {
  'instapay': 'إنستاباي',
  'vodafone_cash': 'فودافون كاش',
  'bank_transfer': 'تحويل بنكي',
};

class WalletTopupScreen extends ConsumerStatefulWidget {
  const WalletTopupScreen({super.key});

  @override
  ConsumerState<WalletTopupScreen> createState() => _WalletTopupScreenState();
}

class _WalletTopupScreenState extends ConsumerState<WalletTopupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  String _method = 'instapay';
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(walletRepositoryProvider).createTopUpRequest(
            userId: user.uid,
            ownerType: user.role == 'mohaffez'
                ? WalletOwnerType.mohaffez
                : WalletOwnerType.student,
            amountEgp: double.parse(_amountCtrl.text.trim()),
            method: _method,
            referenceNumber: _referenceCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.success,
          content: Text(
              'تم إرسال طلب الشحن. سيتم تأكيد الرصيد بعد التحقق من التحويل.'),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('تعذر إرسال الطلب: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        appBar: AppBar(
          title: const Text('شحن المحفظة'),
          backgroundColor: AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Step(
                  number: '1',
                  title: 'اختر طريقة التحويل',
                  child: Column(
                    children: _kMethodLabels.entries.map((e) {
                      return RadioListTile<String>(
                        value: e.key,
                        groupValue: _method,
                        onChanged: (v) => setState(() => _method = v!),
                        title: Text(e.value),
                        activeColor: AppThemeConstants.primary,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppThemeConstants.spaceLg),
                _Step(
                  number: '2',
                  title: 'حوّل المبلغ إلى',
                  child: _AccountBox(method: _method),
                ),
                const SizedBox(height: AppThemeConstants.spaceLg),
                _Step(
                  number: '3',
                  title: 'أدخل تفاصيل التحويل',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'المبلغ (ج.م)',
                          prefixIcon: Icon(Icons.payments),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'أدخل مبلغًا صحيحًا';
                          if (n < 10) return 'الحد الأدنى 10 ج.م';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppThemeConstants.spaceMd),
                      TextFormField(
                        controller: _referenceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'رقم العملية / المرجع',
                          hintText: 'مثال: 12345678',
                          prefixIcon: Icon(Icons.confirmation_number),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().length < 4)
                                ? 'أدخل رقم العملية'
                                : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppThemeConstants.spaceXl),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.primary,
                      foregroundColor: AppThemeConstants.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppThemeConstants.white),
                          )
                        : const Text(
                            'إرسال طلب الشحن',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: AppThemeConstants.spaceMd),
                Container(
                  padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppThemeConstants.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppThemeConstants.warning, size: 20),
                      SizedBox(width: AppThemeConstants.spaceSm),
                      Expanded(
                        child: Text(
                          'سيظهر الرصيد في محفظتك بعد التحقق من التحويل من قِبل الإدارة (عادةً خلال ساعات قليلة).',
                          style: TextStyle(fontSize: 13),
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
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String title;
  final Widget child;
  const _Step({required this.number, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeConstants.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppThemeConstants.primary,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: AppThemeConstants.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: AppThemeConstants.spaceSm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemeConstants.spaceMd),
          child,
        ],
      ),
    );
  }
}

class _AccountBox extends StatelessWidget {
  final String method;
  const _AccountBox({required this.method});

  @override
  Widget build(BuildContext context) {
    final value = _kPlatformAccounts[method] ?? '';
    return Container(
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppThemeConstants.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppThemeConstants.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppThemeConstants.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            color: AppThemeConstants.primary,
            tooltip: 'نسخ',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  duration: Duration(seconds: 1),
                  content: Text('تم النسخ'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
