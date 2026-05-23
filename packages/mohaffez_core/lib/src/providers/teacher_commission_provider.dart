// Per-teacher commission info streamed from `users/{teacherId}`.
//
// Three fields on the user doc are written by the Cloud Function
// `recomputeTeacherTiers` (scheduled bi-weekly, 1st and 15th):
//   commissionRate   — double, effective rate for this teacher
//   commissionTier   — string id matching one of systemConfig.commissionTiers
//   tierStats        — map { last14dRevenueEgp, evaluatedAt, nextEvalAt,
//                            sessionsLast14d, totalSessionsLast14d,
//                            lateSessionsLast14d }
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

  /// On-time sessions only — what the tier math uses.
  final int sessionsLast14d;

  /// On-time + late combined — for "أكملت X" copy on the card.
  final int totalSessionsLast14d;

  /// Sessions the student flagged as late at rating time — excluded
  /// from tier math but shown to the teacher for transparency.
  final int lateSessionsLast14d;

  /// Accumulated cancellation/no-show penalty for the current cycle,
  /// in percent points (e.g. 1.5 = 1.5%). Reset to 0 at settlement.
  final double penaltyPct;

  final DateTime? evaluatedAt;
  final DateTime? nextEvalAt;

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
  });

  /// Returns the effective rate (base tier rate + cycle penalty),
  /// falling back to [globalRate] when this teacher hasn't been
  /// evaluated yet. Capped at 100% so teachers never owe more than
  /// they earned.
  double effectiveRate(double globalRate) {
    final base = rate ?? globalRate;
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

    final onTime = (stats['sessionsLast14d'] as num?)?.toInt() ?? 0;
    final lateCount = (stats['lateSessionsLast14d'] as num?)?.toInt() ?? 0;
    return TeacherCommissionInfo(
      rate: (data['commissionRate'] as num?)?.toDouble(),
      tierId: data['commissionTier'] as String?,
      last14dRevenueEgp:
          (stats['last14dRevenueEgp'] as num?)?.toDouble() ?? 0,
      sessionsLast14d: onTime,
      lateSessionsLast14d: lateCount,
      totalSessionsLast14d:
          (stats['totalSessionsLast14d'] as num?)?.toInt() ?? (onTime + lateCount),
      penaltyPct: (data['commissionPenaltyPercent'] as num?)?.toDouble() ?? 0,
      evaluatedAt: toDate(stats['evaluatedAt']),
      nextEvalAt: toDate(stats['nextEvalAt']),
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

/// Convenience: resolves the effective rate for [teacherId] (per-teacher
/// rate when set, else the global config rate). Returns null while either
/// source is still loading.
final effectiveCommissionRateProvider =
    Provider.autoDispose.family<double?, String>((ref, teacherId) {
  final cfg = ref.watch(systemConfigProvider).valueOrNull;
  if (cfg == null) return null;
  final info = ref.watch(teacherCommissionInfoProvider(teacherId)).valueOrNull;
  if (info == null) return cfg.commissionRate;
  return info.effectiveRate(cfg.commissionRate);
});
