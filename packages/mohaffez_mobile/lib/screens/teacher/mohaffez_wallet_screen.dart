// lib/screens/teacher/mohaffez_wallet_screen.dart
//
// Unified teacher wallet. Phase C of the wallet/dues merge: this screen
// replaces both the old "محفظتي" balance view AND the legacy "مستحقات
// المنصة" screen by surfacing all three buckets in one place:
//
//   • Available balance — withdrawable, settled from prior cycles.
//   • Pending this cycle — gross online earnings minus expected commission
//     and minus any direct-payment commission owed (live estimate of what
//     will land in `available` at the next settlement).
//   • Direct dues — commission owed from cash sessions this cycle. Drained
//     against `available` at settlement; leftover rolls forward.
//
// The legacy 'مستحقات المنصة' screen is still reachable but routes here
// (see app_router.dart). When Phase B step 4 deprecates the legacy
// weeklyCommissionSummaries collection, that screen can be deleted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../shared/widgets/teacher_tier_card.dart';

DateTime _nextFixedSettlementDate([DateTime? from]) {
  final now = from ?? DateTime.now();
  final firstThisMonth = DateTime(now.year, now.month, 1, 0, 5);
  final fifteenthThisMonth = DateTime(now.year, now.month, 15, 0, 5);

  if (now.isBefore(firstThisMonth)) return firstThisMonth;
  if (now.isBefore(fifteenthThisMonth)) return fifteenthThisMonth;
  return DateTime(now.year, now.month + 1, 1, 0, 5);
}

class MohaffezWalletScreen extends ConsumerWidget {
  const MohaffezWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
          body: Center(child: Text('حدث خطأ. يرجى المحاولة مرة أخرى'))),
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
                ref.invalidate(teacherCommissionInfoProvider(user.uid));
              },
              child: ListView(
                padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                children: [
                  TeacherTierCard(teacherId: user.uid),
                  const SizedBox(height: AppThemeConstants.spaceLg),
                  _AvailableCard(uid: user.uid),
                  const SizedBox(height: AppThemeConstants.spaceMd),
                  _CycleBreakdownCard(uid: user.uid),
                  _DuesCard(uid: user.uid),
                  const SizedBox(height: AppThemeConstants.spaceLg),
                  _PayoutButton(uid: user.uid),
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

// ─────────────────────────────────────────────────────────────────────────────
// AVAILABLE BALANCE CARD
// Headline number, what the teacher can withdraw right now.
// ─────────────────────────────────────────────────────────────────────────────
class _AvailableCard extends ConsumerWidget {
  final String uid;
  const _AvailableCard({required this.uid});

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
              Text('الرصيد المتاح للسحب',
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

// ─────────────────────────────────────────────────────────────────────────────
// CYCLE BREAKDOWN CARD
// Shows the teacher how the current cycle nets out:
//   + online inflow (gross pending)
//   − estimated online commission (at the teacher's current effective rate)
//   − direct dues owed
//   = estimated net that will land in `available` at next settlement
// ─────────────────────────────────────────────────────────────────────────────
class _CycleBreakdownCard extends ConsumerWidget {
  final String uid;
  const _CycleBreakdownCard({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider((
      userId: uid,
      ownerType: WalletOwnerType.mohaffez,
    )));
    final teacherInfo =
        ref.watch(teacherCommissionInfoProvider(uid)).valueOrNull;
    final config = ref.watch(systemConfigProvider).valueOrNull;
    final starterRate = config == null
        ? 0.15
        : CommissionTierModel.starterRate(config.commissionTiers);
    final effectiveRate =
        teacherInfo?.effectiveRate(starterRate) ?? starterRate;

    return walletAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (w) {
        if (!w.hasPendingCycleEarnings && !w.hasDuesOwed) {
          // No current-cycle activity at all → don't clutter the screen.
          return const SizedBox.shrink();
        }
        final onlineGross = w.pendingCycleEgp;
        final onlineCommission = onlineGross * effectiveRate;
        final duesEgp = w.directCommissionOwedEgp; // positive
        final estimatedNet = onlineGross - onlineCommission - duesEgp;
        final nextEvalLabel =
            DateFormat('d MMM', 'ar').format(_nextFixedSettlementDate());

        return Container(
          padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
          decoration: BoxDecoration(
            color: AppThemeConstants.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppThemeConstants.primary.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.hourglass_bottom_rounded,
                      color: AppThemeConstants.primary, size: 20),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'قيد التسوية — الدورة الحالية',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppThemeConstants.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'التسوية القادمة: $nextEvalLabel',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppThemeConstants.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppThemeConstants.spaceMd),
              if (onlineGross > 0)
                _BreakdownRow(
                  sign: '+',
                  label: 'دخل أونلاين',
                  amount: onlineGross,
                  color: AppThemeConstants.success,
                ),
              if (onlineGross > 0)
                _BreakdownRow(
                  sign: '−',
                  label:
                      'عمولة المنصة المتوقعة (${_formatRate(effectiveRate)}%)',
                  amount: onlineCommission,
                  color: AppThemeConstants.textSecondary,
                ),
              if (duesEgp > 0)
                _BreakdownRow(
                  sign: '−',
                  label: 'مستحقات جلسات مباشرة',
                  amount: duesEgp,
                  color: AppThemeConstants.warning,
                ),
              const Divider(height: 24),
              _BreakdownRow(
                sign: '=',
                label: 'صافي متوقع عند التسوية',
                amount: estimatedNet < 0 ? 0 : estimatedNet,
                color: AppThemeConstants.primary,
                bold: true,
              ),
              if (estimatedNet < 0) ...[
                const SizedBox(height: AppThemeConstants.spaceSm),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppThemeConstants.warning, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'مستحقاتك على المنصة هذه الدورة أكبر من دخلك الأونلاين. سيتم خصم الفارق من رصيدك المتاح عند التسوية.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppThemeConstants.warning
                                .withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatRate(double rate) {
    final pct = rate * 100;
    return pct == pct.roundToDouble()
        ? pct.toInt().toString()
        : pct.toStringAsFixed(1);
  }
}

class _BreakdownRow extends StatelessWidget {
  final String sign;
  final String label;
  final double amount;
  final Color color;
  final bool bold;

  const _BreakdownRow({
    required this.sign,
    required this.label,
    required this.amount,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: bold ? 14 : 13,
      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
      color:
          bold ? AppThemeConstants.textPrimary : AppThemeConstants.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(sign,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: bold ? 14 : 13,
                )),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(label, style: textStyle)),
          Text('${amount.toStringAsFixed(2)} ج.م',
              style: textStyle.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DUES CARD — only visible when teacher owes platform from cash sessions.
// Replaces the standalone "مستحقات المنصة" screen for in-cycle dues.
// Historical/legacy dues (pre-Phase-B sessions) still live in the legacy
// `weeklyCommissionSummaries`-backed screen until Phase B step 4 ships.
// ─────────────────────────────────────────────────────────────────────────────
class _DuesCard extends ConsumerWidget {
  final String uid;
  const _DuesCard({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider((
      userId: uid,
      ownerType: WalletOwnerType.mohaffez,
    )));
    return walletAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (w) {
        if (!w.hasDuesOwed) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppThemeConstants.spaceMd),
          child: Container(
            padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
            decoration: BoxDecoration(
              color: AppThemeConstants.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppThemeConstants.warning.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        color: AppThemeConstants.warning, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'مستحقات المنصة (دفع مباشر)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppThemeConstants.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppThemeConstants.spaceSm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      w.directCommissionOwedEgp.toStringAsFixed(2),
                      style: const TextStyle(
                        color: AppThemeConstants.warning,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('ج.م',
                          style: TextStyle(
                            color: AppThemeConstants.warning,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: AppThemeConstants.spaceSm),
                const Text(
                  'عمولة المنصة المستحقة على الجلسات التي استلمت ثمنها نقداً هذه الدورة. تُخصم تلقائياً من رصيدك المتاح عند التسوية القادمة. ما تبقّى يُرحّل إلى الدورة التالية.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppThemeConstants.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYOUT BUTTON — disabled when available − dues ≤ 0. When the teacher owes
// the platform more than they hold, surface a "add money" CTA pointing at
// the topup flow instead so they can clear the debt.
// ─────────────────────────────────────────────────────────────────────────────
class _PayoutButton extends ConsumerWidget {
  final String uid;
  const _PayoutButton({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider((
      userId: uid,
      ownerType: WalletOwnerType.mohaffez,
    )));
    final wallet = walletAsync.valueOrNull;
    if (wallet == null) {
      return const SizedBox.shrink();
    }

    // Effective rate = base tier + cycle penalty (same math as
    // recomputeTeacherTiers / requestPayout). Needed to project the
    // cycle's pending-net.
    final config = ref.watch(systemConfigProvider).valueOrNull;
    final starterRate = config == null
        ? 0.15
        : CommissionTierModel.starterRate(config.commissionTiers);
    final teacherInfo =
        ref.watch(teacherCommissionInfoProvider(uid)).valueOrNull;
    final effectiveRate =
        teacherInfo?.effectiveRate(starterRate) ?? starterRate;

    final available = wallet.balanceEgp;
    final debt = wallet.directCommissionOwedEgp; // positive when owed
    final pendingGross = wallet.pendingCycleEgp;
    final pendingNet = pendingGross * (1 - effectiveRate);
    // Projected balance at end-of-cycle settlement. If positive, the dues
    // will be auto-cleared from this cycle's earnings and the teacher can
    // safely withdraw their current available balance.
    final projected = available + pendingNet - debt;
    final inDebt = debt > 0;
    final solventViaPending = inDebt && projected >= 0;
    final canPayout = available > 0 && projected > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inDebt) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: solventViaPending
                  ? AppThemeConstants.accentBlueLight
                  : AppThemeConstants.errorLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: solventViaPending
                      ? AppThemeConstants.accentBlue
                      : AppThemeConstants.error),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  solventViaPending
                      ? Icons.info_outline
                      : Icons.warning_amber_rounded,
                  color: solventViaPending
                      ? AppThemeConstants.accentBlue
                      : AppThemeConstants.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'عليك مستحقات للمنصة بقيمة ${debt.toStringAsFixed(2)} ج.م',
                        style: TextStyle(
                            fontSize: 13,
                            color: solventViaPending
                                ? AppThemeConstants.accentBlue
                                : AppThemeConstants.error,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        solventViaPending
                            ? 'لا داعي للقلق — صافي أرباح الدورة الحالية يغطي '
                                'المستحقات. سيُسدَّد تلقائياً عند التسوية.'
                            : 'لا يمكنك السحب حتى يتم سداد المستحقات. '
                                'يمكنك إضافة رصيد لمحفظتك لتسوية الحساب.',
                        style: TextStyle(
                            fontSize: 12,
                            color: solventViaPending
                                ? AppThemeConstants.accentBlue
                                : AppThemeConstants.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (!solventViaPending)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/wallet-topup'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppThemeConstants.error,
                  side: const BorderSide(color: AppThemeConstants.error),
                  padding: const EdgeInsets.symmetric(
                      vertical: AppThemeConstants.spaceSm),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'سداد المستحقات (إضافة رصيد)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        ElevatedButton.icon(
          onPressed: canPayout ? () => context.push('/request-payout') : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemeConstants.secondary,
            foregroundColor: AppThemeConstants.white,
            disabledBackgroundColor: AppThemeConstants.grey300,
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
      ],
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
      error: (_, __) => const Text(
          'تعذّر تحميل طلبات السحب. يرجى المحاولة مرة أخرى',
          style: TextStyle(color: AppThemeConstants.error)),
      data: (payouts) {
        if (payouts.isEmpty) {
          return _emptyBox('لم تقدّم أي طلب سحب بعد');
        }
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
      error: (_, __) => const Text(
          'تعذّر تحميل العمليات. يرجى المحاولة مرة أخرى',
          style: TextStyle(color: AppThemeConstants.error)),
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
    final infoEvent = _isInfoEvent;
    final isCredit = !infoEvent && tx.isCredit;
    final color = infoEvent
        ? (tx.type == WalletTxType.penaltyApplied
            ? AppThemeConstants.warning
            : AppThemeConstants.primary)
        : (isCredit ? AppThemeConstants.success : AppThemeConstants.error);
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
                      maxLines: 2,
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
          if (!infoEvent)
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

  bool get _isInfoEvent =>
      tx.type == WalletTxType.commissionRateChange ||
      tx.type == WalletTxType.penaltyApplied;

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
        return Icons.tune;
      case WalletTxType.commissionRateChange:
        return Icons.percent_rounded;
      case WalletTxType.penaltyApplied:
        return Icons.warning_amber_rounded;
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
      case WalletTxType.cycleSettlement:
        return 'تسوية دورة';
      case WalletTxType.payout:
        return 'سحب رصيد';
      case WalletTxType.payoutReversal:
        return 'إلغاء سحب';
      case WalletTxType.promoCredit:
        return 'مكافأة';
      case WalletTxType.directSessionCommission:
        return 'عمولة جلسة مباشرة';
      case WalletTxType.directSessionCommissionReversal:
        return 'إلغاء عمولة جلسة';
      case WalletTxType.adjustment:
        return 'تسوية';
      case WalletTxType.commissionRateChange:
        return 'تغيير معدل العمولة';
      case WalletTxType.penaltyApplied:
        return 'عقوبة إلغاء / غياب';
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
