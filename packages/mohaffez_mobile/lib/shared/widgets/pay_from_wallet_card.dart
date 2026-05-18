// lib/shared/widgets/pay_from_wallet_card.dart
//
// Reusable card that lets a student pay an accepted session request from
// their wallet balance in one tap. Renders only when [sessionRequestId] is
// non-null. If the balance is insufficient, the card shows the deficit and
// links to the top-up screen instead.
//
// Drop above the manual-transfer payment UI on direct_payment_screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

class PayFromWalletCard extends ConsumerStatefulWidget {
  final String sessionRequestId;
  final double amountEgp;
  final VoidCallback? onPaid;

  const PayFromWalletCard({
    super.key,
    required this.sessionRequestId,
    required this.amountEgp,
    this.onPaid,
  });

  @override
  ConsumerState<PayFromWalletCard> createState() =>
      _PayFromWalletCardState();
}

class _PayFromWalletCardState extends ConsumerState<PayFromWalletCard> {
  bool _submitting = false;

  Future<void> _pay() async {
    setState(() => _submitting = true);
    try {
      await ref.read(walletRepositoryProvider).payFromWallet(
            sessionRequestId: widget.sessionRequestId,
            amountEgp: widget.amountEgp,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.success,
          content: Text('تم الدفع من المحفظة وتأكيد الجلسة'),
          duration: Duration(seconds: 3),
        ),
      );
      if (widget.onPaid != null) {
        widget.onPaid!();
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('تعذر الدفع: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    // Defensive: never render an "Pay" CTA when the parent hasn't resolved
    // a real price yet. Pre-empts a misleading "balance sufficient" state.
    if (widget.amountEgp <= 0) return const SizedBox.shrink();

    final walletAsync = ref.watch(walletProvider((
      userId: user.uid,
      ownerType: user.role == 'mohaffez'
          ? WalletOwnerType.mohaffez
          : WalletOwnerType.student,
    )));

    return walletAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (w) {
        final balance = w.balanceEgp;
        final sufficient = balance >= widget.amountEgp;

        return Container(
          padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: sufficient
                  ? [
                      AppThemeConstants.deepTeal,
                      AppThemeConstants.primary,
                    ]
                  : [
                      AppThemeConstants.warning.withValues(alpha: 0.15),
                      AppThemeConstants.warning.withValues(alpha: 0.05),
                    ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(14),
            border: sufficient
                ? null
                : Border.all(
                    color: AppThemeConstants.warning.withValues(alpha: 0.3),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: sufficient
                        ? AppThemeConstants.white
                        : AppThemeConstants.warning,
                    size: 22,
                  ),
                  const SizedBox(width: AppThemeConstants.spaceSm),
                  Expanded(
                    child: Text(
                      'الدفع من المحفظة',
                      style: TextStyle(
                        color: sufficient
                            ? AppThemeConstants.white
                            : AppThemeConstants.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${balance.toStringAsFixed(2)} ج.م',
                    style: TextStyle(
                      color: sufficient
                          ? AppThemeConstants.white
                          : AppThemeConstants.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppThemeConstants.spaceSm),
              if (sufficient)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _pay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.white,
                      foregroundColor: AppThemeConstants.primary,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppThemeConstants.spaceSm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppThemeConstants.primary,
                            ),
                          )
                        : const Icon(Icons.flash_on, size: 18),
                    label: Text(
                      'ادفع ${widget.amountEgp.toStringAsFixed(2)} ج.م الآن',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الرصيد غير كافٍ — ينقصك ${(widget.amountEgp - balance).toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          color: AppThemeConstants.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/wallet-topup'),
                      icon: const Icon(Icons.add_card, size: 18),
                      label: const Text('شحن'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppThemeConstants.warning,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
