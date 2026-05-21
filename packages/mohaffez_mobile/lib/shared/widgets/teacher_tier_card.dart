// Compact card the teacher sees on home/profile showing their current
// commission tier, current rate, and a progress bar towards the next tier.
//
// Tier data is recomputed weekly by the Cloud Function
// `recomputeTeacherTiers` — until that runs at least once for a teacher,
// the card shows the global rate with a neutral "we're still calculating"
// caption instead of incorrect tier info.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

class TeacherTierCard extends ConsumerWidget {
  final String teacherId;

  const TeacherTierCard({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(systemConfigProvider).valueOrNull;
    final info =
        ref.watch(teacherCommissionInfoProvider(teacherId)).valueOrNull;

    if (cfg == null) {
      return const SizedBox.shrink();
    }

    final tiers = cfg.commissionTiers;
    if (tiers.isEmpty) return const SizedBox.shrink();

    final effective = info?.effectiveRate(cfg.commissionRate) ?? cfg.commissionRate;
    final currentTier = info?.currentTier(tiers);
    final nextTier = info?.nextTier(tiers);
    final revenue = info?.last30dRevenueEgp ?? 0;
    final sessions = info?.sessionsLast30d ?? 0;
    final lateSessions = info?.lateSessionsLast30d ?? 0;
    final totalSessions = info?.totalSessionsLast30d ?? sessions;
    final notYetEvaluated = info?.evaluatedAt == null;

    final progressTowardNext = (nextTier == null || currentTier == null)
        ? null
        : _progressTowardNext(
            revenue: revenue,
            currentMin: currentTier.minRevenueEgp,
            nextMin: nextTier.minRevenueEgp,
          );

    // Estimate how many more sessions the teacher needs to reach the next
    // tier — uses their own average session price so the number is honest.
    int? sessionsToNextTier;
    if (nextTier != null && sessions > 0 && revenue > 0) {
      final avgPrice = revenue / sessions;
      final gap = nextTier.minRevenueEgp - revenue;
      if (avgPrice > 0 && gap > 0) {
        sessionsToNextTier = (gap / avgPrice).ceil();
      }
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeConstants.primary,
            AppThemeConstants.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                currentTier?.badge ?? '⭐',
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'شريحة عمولتك',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppThemeConstants.white,
                      ),
                    ),
                    Text(
                      currentTier?.labelAr ?? 'البداية',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppThemeConstants.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppThemeConstants.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'عمولة ${(effective * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppThemeConstants.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (notYetEvaluated)
            const Text(
              'تُحتسب شريحتك تلقائياً كل أسبوعين بناءً على حلقاتك المكتملة.',
              style: TextStyle(color: AppThemeConstants.white, fontSize: 12),
            )
          else ...[
            Text(
              'أكملت $totalSessions حلقة خلال آخر 30 يوم '
              '(${revenue.toStringAsFixed(0)} ج.م)',
              style: const TextStyle(
                color: AppThemeConstants.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (lateSessions > 0) ...[
              const SizedBox(height: 4),
              Text(
                'منها $lateSessions حلقة متأخرة لم تُحتسب في الشريحة',
                style: TextStyle(
                  color: AppThemeConstants.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (nextTier != null && progressTowardNext != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressTowardNext.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppThemeConstants.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(
                      AppThemeConstants.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sessionsToNextTier != null
                    ? 'أكمل ~$sessionsToNextTier حلقة إضافية في وقتها لتنخفض '
                        'عمولة المنصة إلى '
                        '${(nextTier.rate * 100).toStringAsFixed(0)}% '
                        '(${nextTier.badge ?? ''} ${nextTier.labelAr})'
                    : 'تبقى ${(nextTier.minRevenueEgp - revenue).clamp(0, double.infinity).toStringAsFixed(0)} ج.م '
                        'لتنخفض عمولة المنصة إلى '
                        '${(nextTier.rate * 100).toStringAsFixed(0)}% '
                        '(${nextTier.badge ?? ''} ${nextTier.labelAr})',
                style: const TextStyle(
                  color: AppThemeConstants.white,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ] else
              const Text(
                'وصلت لأعلى شريحة — تهانينا! 🎉',
                style: TextStyle(
                  color: AppThemeConstants.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ],
      ),
    );
  }

  double _progressTowardNext({
    required double revenue,
    required double currentMin,
    required double nextMin,
  }) {
    final span = nextMin - currentMin;
    if (span <= 0) return 1.0;
    return (revenue - currentMin) / span;
  }
}
