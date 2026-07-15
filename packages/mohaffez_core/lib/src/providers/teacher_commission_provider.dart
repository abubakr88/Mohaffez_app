// Per-teacher commission info streamed from `users/{teacherId}`.
//
// Three fields on the user doc are written by the Cloud Function
// `recomputeTeacherTiers` (financial cycles starting on the 1st and 15th):
//   commissionRate   — double, effective rate for this teacher
//   commissionTier   — string id matching one of systemConfig.commissionTiers
//   tierStats        — current cycle totals plus cycleStart/cycleEnd. Legacy
//                      last14d keys are still read for older documents.
//
// Until the CF has run for a given teacher, all three are absent —
// `TeacherCommissionInfo.fallbackTo(global)` returns the global rate
// from systemConfig so behaviour stays unchanged for un-evaluated teachers.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/commission_tier_model.dart';
import 'system_config_provider.dart';

class TeacherCommissionInfo {
  final double? rate;
  final String? tierId;
  final double last14dRevenueEgp;

  /// On-time sessions in the current cycle — what the tier math uses.
  final int sessionsLast14d;

  /// On-time + late combined in the current cycle.
  final int totalSessionsLast14d;

  /// Current-cycle sessions the student flagged as late — excluded
  /// from tier math but shown to the teacher for transparency.
  final int lateSessionsLast14d;

  /// Accumulated cancellation/no-show penalty for the current cycle,
  /// in percent points (e.g. 1.5 = 1.5%). Reset to 0 at settlement.
  final double penaltyPct;

  final DateTime? evaluatedAt;
  final DateTime? nextEvalAt;
  final DateTime? cycleStart;
  final DateTime? cycleEnd;

  int get sessionsInCycle => sessionsLast14d;
  int get totalSessionsInCycle => totalSessionsLast14d;
  int get lateSessionsInCycle => lateSessionsLast14d;

  const TeacherCommissionInfo({
    this.rate,
    this.tierId,
    this.last14dRevenueEgp = 0,
    this.sessionsLast14d = 0,
    this.totalSessionsLast14d = 0,
    this.lateSessionsLast14d = 0,
    this.penaltyPct = 0,
    this.evaluatedAt,
    this.nextEvalAt,
    this.cycleStart,
    this.cycleEnd,
  });

  /// Returns the effective rate (base tier rate + cycle penalty),
  /// falling back to [fallbackRate] when this teacher hasn't been
  /// evaluated yet. Capped at 100% so teachers never owe more than
  /// they earned.
  double effectiveRate(double fallbackRate) {
    final base = rate ?? fallbackRate;
    final effective = base + penaltyPct / 100;
    return effective > 1.0 ? 1.0 : effective;
  }

  /// Looks up the matching tier definition from the configured ladder.
  /// Falls back to the lowest tier when [tierId] is unset.
  CommissionTierModel? currentTier(List<CommissionTierModel> tiers) {
    if (tiers.isEmpty) return null;
    if (tierId == null) {
      final sorted = [...tiers]
        ..sort((a, b) => a.minSessions.compareTo(b.minSessions));
      return sorted.first;
    }
    return tiers.firstWhere(
      (t) => t.id == tierId,
      orElse: () => tiers.first,
    );
  }

  /// Returns the next-higher tier above the current one, or null when
  /// already at the top.
  CommissionTierModel? nextTier(List<CommissionTierModel> tiers) {
    if (tiers.isEmpty) return null;
    final sorted = [...tiers]
      ..sort((a, b) => a.minSessions.compareTo(b.minSessions));
    final current = currentTier(sorted);
    if (current == null) return null;
    final idx = sorted.indexWhere((t) => t.id == current.id);
    if (idx < 0 || idx >= sorted.length - 1) return null;
    return sorted[idx + 1];
  }

  factory TeacherCommissionInfo.fromMap(Map<String, dynamic> data) {
    final stats = (data['tierStats'] as Map<String, dynamic>?) ?? const {};
    DateTime? toDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return null;
    }

    final onTime = (stats['sessionsInCycle'] as num?)?.toInt() ??
        (stats['sessionsLast14d'] as num?)?.toInt() ??
        0;
    final lateCount = (stats['lateSessionsInCycle'] as num?)?.toInt() ??
        (stats['lateSessionsLast14d'] as num?)?.toInt() ??
        0;
    return TeacherCommissionInfo(
      rate: (data['commissionRate'] as num?)?.toDouble(),
      tierId: data['commissionTier'] as String?,
      last14dRevenueEgp: (stats['cycleRevenueEgp'] as num?)?.toDouble() ??
          (stats['last14dRevenueEgp'] as num?)?.toDouble() ??
          0,
      sessionsLast14d: onTime,
      lateSessionsLast14d: lateCount,
      totalSessionsLast14d: (stats['totalSessionsInCycle'] as num?)?.toInt() ??
          (stats['totalSessionsLast14d'] as num?)?.toInt() ??
          (onTime + lateCount),
      penaltyPct: (data['commissionPenaltyPercent'] as num?)?.toDouble() ?? 0,
      evaluatedAt: toDate(stats['evaluatedAt']),
      nextEvalAt: toDate(stats['nextEvalAt']),
      cycleStart: toDate(stats['cycleStart'] ?? stats['windowStart']),
      cycleEnd: toDate(stats['cycleEnd'] ?? stats['nextEvalAt']),
    );
  }
}

/// Streams a teacher's tier info from `users/{teacherId}`. Yields a
/// default empty info until the first snapshot arrives so subscribers
/// don't briefly see "loading" forever for new teachers.
final teacherCommissionInfoProvider =
    StreamProvider.autoDispose.family<TeacherCommissionInfo, String>(
  (ref, teacherId) {
    if (teacherId.isEmpty) {
      return Stream.value(const TeacherCommissionInfo());
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(teacherId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return const TeacherCommissionInfo();
      return TeacherCommissionInfo.fromMap(snap.data() ?? {});
    });
  },
);

/// Convenience: resolves the effective rate for [teacherId]. If the
/// per-teacher rate is not initialized yet, new teachers start from the
/// first configured tier, not the legacy global config rate.
final effectiveCommissionRateProvider =
    Provider.autoDispose.family<double?, String>((ref, teacherId) {
  final cfg = ref.watch(systemConfigProvider).valueOrNull;
  if (cfg == null) return null;
  final info = ref.watch(teacherCommissionInfoProvider(teacherId)).valueOrNull;
  final starterRate = CommissionTierModel.starterRate(cfg.commissionTiers);
  if (info == null) return starterRate;
  return info.effectiveRate(starterRate);
});
