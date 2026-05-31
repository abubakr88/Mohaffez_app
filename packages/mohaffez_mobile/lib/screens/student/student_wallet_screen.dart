// lib/screens/student/student_wallet_screen.dart
//
// Student wallet: shows balance, recent ledger entries, and links to top-up.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mohaffez_core/mohaffez_core.dart';

class StudentWalletScreen extends ConsumerWidget {
  const StudentWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('حدث خطأ: $e')),
      ),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => context.go('/login'));
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final ownerType = user.role == 'mohaffez'
            ? WalletOwnerType.mohaffez
            : WalletOwnerType.student;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppThemeConstants.background,
            appBar: AppBar(
              title: const Text('محفظتي'),
              backgroundColor: AppThemeConstants.primary,
              foregroundColor: AppThemeConstants.white,
              elevation: 0,
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(walletProvider(
                    (userId: user.uid, ownerType: ownerType)));
                ref.invalidate(walletTransactionsProvider(user.uid));
              },
              child: ListView(
                padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                children: [
                  _BalanceCard(userId: user.uid, ownerType: ownerType),
                  const SizedBox(height: AppThemeConstants.spaceLg),
                  _TopUpButton(),
                  const SizedBox(height: AppThemeConstants.spaceXl),
                  const Text(
                    'آخر العمليات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppThemeConstants.spaceMd),
                  _TransactionsList(userId: user.uid),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  final String userId;
  final WalletOwnerType ownerType;
  const _BalanceCard({required this.userId, required this.ownerType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync =
        ref.watch(walletProvider((userId: userId, ownerType: ownerType)));

    return Container(
      padding: const EdgeInsets.all(AppThemeConstants.spaceXl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppThemeConstants.deepTeal, AppThemeConstants.primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppThemeConstants.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: AppThemeConstants.white, size: 28),
              const SizedBox(width: AppThemeConstants.spaceSm),
              Text('الرصيد الحالي',
                  style: TextStyle(
                    color: AppThemeConstants.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  )),
            ],
          ),
          const SizedBox(height: AppThemeConstants.spaceMd),
          walletAsync.when(
            loading: () => const SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppThemeConstants.white),
                ),
              ),
            ),
            error: (e, _) => const Text(
              'تعذر تحميل الرصيد',
              style: TextStyle(color: AppThemeConstants.white),
            ),
            data: (w) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  w.balanceEgp.toStringAsFixed(2),
                  style: const TextStyle(
                    color: AppThemeConstants.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'ج.م',
                    style: TextStyle(
                      color: AppThemeConstants.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUpButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.push('/wallet-topup'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeConstants.secondary,
          foregroundColor: AppThemeConstants.white,
          padding:
              const EdgeInsets.symmetric(vertical: AppThemeConstants.spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.add_card),
        label: const Text(
          'شحن المحفظة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _TransactionsList extends ConsumerWidget {
  final String userId;
  const _TransactionsList({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(walletTransactionsProvider(userId));
    return txsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('تعذر تحميل العمليات: $e',
            style: const TextStyle(color: AppThemeConstants.error)),
      ),
      data: (txs) {
        if (txs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
            decoration: BoxDecoration(
              color: AppThemeConstants.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeConstants.grey300),
            ),
            child: const Center(
              child: Text(
                'لا توجد عمليات بعد',
                style: TextStyle(color: AppThemeConstants.textSecondary),
              ),
            ),
          );
        }
        return Column(
          children: txs.map((tx) => _TxTile(tx: tx)).toList(),
        );
      },
    );
  }
}

class _TxTile extends StatelessWidget {
  final WalletTransactionModel tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final color = isCredit ? AppThemeConstants.success : AppThemeConstants.error;
    final sign = isCredit ? '+' : '−';
    final date = tx.createdAt;
    final dateStr = date != null
        ? DateFormat('d MMM y · HH:mm', 'ar').format(date)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppThemeConstants.spaceSm),
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeConstants.grey200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(_iconFor(tx.type), color: color, size: 20),
          ),
          const SizedBox(width: AppThemeConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labelFor(tx.type),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (tx.reason.isNotEmpty)
                  Text(
                    tx.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppThemeConstants.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: AppThemeConstants.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$sign ${tx.absAmountEgp.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(WalletTxType t) {
    switch (t) {
      case WalletTxType.topup:
        return Icons.add_card;
      case WalletTxType.sessionPayment:
        return Icons.school;
      case WalletTxType.sessionRefund:
        return Icons.undo;
      case WalletTxType.cycleSettlement:
        return Icons.event_available_outlined;
      case WalletTxType.payout:
        return Icons.account_balance;
      case WalletTxType.payoutReversal:
        return Icons.undo;
      case WalletTxType.promoCredit:
        return Icons.card_giftcard;
      case WalletTxType.directSessionCommission:
        return Icons.receipt_long_outlined;
      case WalletTxType.directSessionCommissionReversal:
        return Icons.undo;
      case WalletTxType.adjustment:
      case WalletTxType.commissionRateChange:
      case WalletTxType.penaltyApplied:
        return Icons.tune;
    }
  }

  String _labelFor(WalletTxType t) {
    switch (t) {
      case WalletTxType.topup:
        return 'شحن المحفظة';
      case WalletTxType.sessionPayment:
        return 'دفع جلسة';
      case WalletTxType.sessionRefund:
        return 'استرداد جلسة';
      case WalletTxType.cycleSettlement:
        return 'تسوية دورة';
      case WalletTxType.payout:
        return 'سحب رصيد';
      case WalletTxType.payoutReversal:
        return 'إلغاء سحب';
      case WalletTxType.promoCredit:
        return 'رصيد ترويجي';
      case WalletTxType.directSessionCommission:
        return 'عمولة جلسة مباشرة';
      case WalletTxType.directSessionCommissionReversal:
        return 'إلغاء عمولة جلسة';
      case WalletTxType.adjustment:
      case WalletTxType.commissionRateChange:
      case WalletTxType.penaltyApplied:
        return 'تسوية';
    }
  }
}
