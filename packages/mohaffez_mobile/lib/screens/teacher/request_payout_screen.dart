// lib/screens/teacher/request_payout_screen.dart
//
// Teacher requests a withdrawal from their wallet balance. Submitting creates
// a payoutRequest doc (status: 'requested'). No money moves until admin
// triggers startPayout.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

const _kMethodLabels = {
  PayoutMethod.instapay: 'إنستاباي',
  PayoutMethod.vodafoneCash: 'فودافون كاش',
  PayoutMethod.bankTransfer: 'تحويل بنكي',
};

class RequestPayoutScreen extends ConsumerStatefulWidget {
  const RequestPayoutScreen({super.key});

  @override
  ConsumerState<RequestPayoutScreen> createState() =>
      _RequestPayoutScreenState();
}

class _RequestPayoutScreenState extends ConsumerState<RequestPayoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  PayoutMethod _method = PayoutMethod.instapay;
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(double maxEgp) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(walletRepositoryProvider).requestPayout(
            amountEgp: double.parse(_amountCtrl.text.trim()),
            method: _method,
            accountDetails: _accountCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.success,
          content:
              Text('تم إرسال طلب السحب. سيتم التحويل خلال أيام عمل قليلة.'),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('تعذّر إرسال طلب السحب. يرجى المحاولة مرة أخرى'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('حدث خطأ. يرجى المحاولة مرة أخرى'))),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final walletAsync = ref.watch(walletProvider((
          userId: user.uid,
          ownerType: WalletOwnerType.mohaffez,
        )));
        final config = ref.watch(systemConfigProvider).valueOrNull;
        final minWithdrawEgp = config?.minimumWithdrawAmount ?? 50;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppThemeConstants.background,
            appBar: AppBar(
              title: const Text('طلب سحب'),
              backgroundColor: AppThemeConstants.primary,
              foregroundColor: AppThemeConstants.white,
              elevation: 0,
            ),
            body: walletAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('تعذّر تحميل الرصيد. يرجى المحاولة مرة أخرى')),
              data: (w) {
                final balance = w.balanceEgp;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BalanceHeader(balance: balance),
                        const SizedBox(height: AppThemeConstants.spaceLg),
                        _Card(
                          title: 'المبلغ',
                          child: TextFormField(
                            controller: _amountCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'المبلغ (ج.م)',
                              prefixIcon: const Icon(Icons.payments),
                              border: const OutlineInputBorder(),
                              suffixIcon: TextButton(
                                onPressed: () => _amountCtrl.text =
                                    balance.toStringAsFixed(2),
                                child: const Text('الكل'),
                              ),
                            ),
                            validator: (v) {
                              final n = double.tryParse(v?.trim() ?? '');
                              if (n == null || n <= 0) {
                                return 'أدخل مبلغًا صحيحًا';
                              }
                              if (n < minWithdrawEgp) {
                                return 'الحد الأدنى ${minWithdrawEgp.toStringAsFixed(0)} ج.م';
                              }
                              if (n > balance) {
                                return 'المبلغ يتجاوز الرصيد المتاح';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: AppThemeConstants.spaceLg),
                        _Card(
                          title: 'طريقة الاستلام',
                          child: Column(
                            children: _kMethodLabels.entries.map((e) {
                              return RadioListTile<PayoutMethod>(
                                value: e.key,
                                groupValue: _method,
                                onChanged: (v) =>
                                    setState(() => _method = v!),
                                title: Text(e.value),
                                activeColor: AppThemeConstants.primary,
                                contentPadding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: AppThemeConstants.spaceLg),
                        _Card(
                          title: _method == PayoutMethod.bankTransfer
                              ? 'رقم الحساب / IBAN'
                              : 'رقم المحفظة',
                          child: TextFormField(
                            controller: _accountCtrl,
                            decoration: InputDecoration(
                              labelText: _method == PayoutMethod.bankTransfer
                                  ? 'IBAN'
                                  : 'رقم الهاتف',
                              prefixIcon: const Icon(Icons.account_circle),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().length < 5) {
                                return 'أدخل بيانات صحيحة';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: AppThemeConstants.spaceXl),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _submitting
                                ? null
                                : () => _submit(balance),
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
                                    'إرسال طلب السحب',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  final double balance;
  const _BalanceHeader({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
      decoration: BoxDecoration(
        color: AppThemeConstants.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppThemeConstants.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet,
              color: AppThemeConstants.primary),
          const SizedBox(width: AppThemeConstants.spaceMd),
          const Expanded(
            child: Text('الرصيد المتاح',
                style: TextStyle(fontSize: 14, color: AppThemeConstants.textPrimary)),
          ),
          Text(
            '${balance.toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              color: AppThemeConstants.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

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
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: AppThemeConstants.spaceMd),
          child,
        ],
      ),
    );
  }
}
