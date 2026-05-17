// lib/screens/teacher/mohaffez_wallet_screen.dart
//
// Teacher wallet: balance, recent ledger entries, payout request history,
// and entry point to start a new payout.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mohaffez_core/mohaffez_core.dart';

class MohaffezWalletScreen extends ConsumerWidget {
  const MohaffezWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('حدث خطأ: $e'))),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => context.go('/login'));
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
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
                ref.invalidate(walletProvider((
                  userId: user.uid,
                  ownerType: WalletOwnerType.mohaffez,
                )));
                ref.invalidate(walletTransactionsProvider(user.uid));
                ref.invalidate(payoutRequestsProvider(user.uid));
              },
              child: ListView(
                padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                children: [
                  _BalanceCard(uid: user.uid),
                  const SizedBox(height: AppThemeConstants.spaceLg),
                  _PayoutButton(),
                  const SizedBox(height: AppThemeConstants.spaceXl),
                  const _SectionLabel(label: 'طلبات السحب'),
                  const SizedBox(height: AppThemeConstants.spaceMd),
                  _PayoutsList(uid: user.uid),
                  const SizedBox(height: AppThemeConstants.spaceXl),
                  const _SectionLabel(label: 'آخر العمليات'),
                  const SizedBox(height: AppThemeConstants.spaceMd),
                  _TxList(uid: user.uid),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppThemeConstants.textPrimary,
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  final String uid;
  const _BalanceCard({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider((
      userId: uid,
      ownerType: WalletOwnerType.mohaffez,
    )));

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
              Text('الأرباح المتاحة للسحب',
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
                  child: Text('ج.م',
                      style: TextStyle(
                        color: AppThemeConstants.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.push('/request-payout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeConstants.secondary,
          foregroundColor: AppThemeConstants.white,
          padding:
              const EdgeInsets.symmetric(vertical: AppThemeConstants.spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.account_balance),
        label: const Text(
          'طلب سحب رصيد',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _PayoutsList extends ConsumerWidget {
  final String uid;
  const _PayoutsList({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(payoutRequestsProvider(uid));
    return payoutsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('تعذر تحميل الطلبات: $e',
          style: const TextStyle(color: AppThemeConstants.error)),
      data: (payouts) {
        if (payouts.isEmpty) {
          return _emptyBox('لم تقدّم أي طلب سحب بعد');
        }
        // Show last 5; full list would be a separate screen.
        return Column(
          children: payouts.take(5).map((p) => _PayoutTile(p: p)).toList(),
        );
      },
    );
  }
}

class _PayoutTile extends StatelessWidget {
  final PayoutRequestModel p;
  const _PayoutTile({required this.p});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(p.status);
    final label = _labelFor(p.status);
    final dateStr = p.createdAt != null
        ? DateFormat('d MMM y', 'ar').format(p.createdAt!)
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                )),
          ),
          const SizedBox(width: AppThemeConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.amountEgp.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${_methodLabel(p.method)} · ${p.accountDetails}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppThemeConstants.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(dateStr,
                      style: const TextStyle(
                        color: AppThemeConstants.textSecondary,
                        fontSize: 11,
                      )),
                if (p.status == PayoutStatus.failed &&
                    p.failureReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'سبب الفشل: ${p.failureReason}',
                    style: const TextStyle(
                      color: AppThemeConstants.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(PayoutStatus s) {
    switch (s) {
      case PayoutStatus.requested:
        return AppThemeConstants.warning;
      case PayoutStatus.processing:
        return AppThemeConstants.primary;
      case PayoutStatus.completed:
        return AppThemeConstants.success;
      case PayoutStatus.failed:
        return AppThemeConstants.error;
    }
  }

  String _labelFor(PayoutStatus s) {
    switch (s) {
      case PayoutStatus.requested:
        return 'بانتظار';
      case PayoutStatus.processing:
        return 'قيد التحويل';
      case PayoutStatus.completed:
        return 'تم';
      case PayoutStatus.failed:
        return 'فشل';
    }
  }

  String _methodLabel(PayoutMethod m) {
    switch (m) {
      case PayoutMethod.instapay:
        return 'إنستاباي';
      case PayoutMethod.vodafoneCash:
        return 'فودافون كاش';
      case PayoutMethod.bankTransfer:
        return 'تحويل بنكي';
    }
  }
}

class _TxList extends ConsumerWidget {
  final String uid;
  const _TxList({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(walletTransactionsProvider(uid));
    return txsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('تعذر تحميل العمليات: $e',
          style: const TextStyle(color: AppThemeConstants.error)),
      data: (txs) {
        if (txs.isEmpty) {
          return _emptyBox('لا توجد عمليات بعد');
        }
        return Column(
          children: txs.map((t) => _TxTile(tx: t)).toList(),
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
    final dateStr = tx.createdAt != null
        ? DateFormat('d MMM · HH:mm', 'ar').format(tx.createdAt!)
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
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(_iconFor(tx.type), color: color, size: 18),
          ),
          const SizedBox(width: AppThemeConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_labelFor(tx.type),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                if (tx.reason.isNotEmpty)
                  Text(tx.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppThemeConstants.textSecondary,
                          fontSize: 12)),
                if (dateStr.isNotEmpty)
                  Text(dateStr,
                      style: const TextStyle(
                          color: AppThemeConstants.textSecondary,
                          fontSize: 11)),
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
      case WalletTxType.payout:
        return Icons.account_balance;
      case WalletTxType.payoutReversal:
        return Icons.undo;
      case WalletTxType.promoCredit:
        return Icons.card_giftcard;
      case WalletTxType.adjustment:
        return Icons.tune;
    }
  }

  String _labelFor(WalletTxType t) {
    switch (t) {
      case WalletTxType.topup:
        return 'شحن';
      case WalletTxType.sessionPayment:
        return 'دخل من جلسة';
      case WalletTxType.sessionRefund:
        return 'استرداد جلسة';
      case WalletTxType.payout:
        return 'سحب رصيد';
      case WalletTxType.payoutReversal:
        return 'إلغاء سحب';
      case WalletTxType.promoCredit:
        return 'مكافأة';
      case WalletTxType.adjustment:
        return 'تسوية';
    }
  }
}

Widget _emptyBox(String label) {
  return Container(
    padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
    decoration: BoxDecoration(
      color: AppThemeConstants.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppThemeConstants.grey300),
    ),
    child: Center(
      child: Text(
        label,
        style: const TextStyle(color: AppThemeConstants.textSecondary),
      ),
    ),
  );
}
