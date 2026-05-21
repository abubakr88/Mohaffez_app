// Per-teacher commission info streamed from `users/{teacherId}`.
//
// Three fields on the user doc are written by the Cloud Function
// `recomputeTeacherTiers` (scheduled weekly):
//   commissionRate   — double, effective rate for this teacher
//   commissionTier   — string id matching one of systemConfig.commissionTiers
//   tierStats        — map { last30dRevenueEgp, evaluatedAt, nextEvalAt,
//                            sessionsLast30d }
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
  final double last30dRevenueEgp;

  /// On-time sessions only — what the tier math uses.
  final int sessionsLast30d;

  /// On-time + late combined — for "أكملت X" copy on the card.
  final int totalSessionsLast30d;

  /// Sessions the student flagged as late at rating time — excluded
  /// from tier math but shown to the teacher for transparency.
  final int lateSessionsLast30d;

  final DateTime? evaluatedAt;
  final DateTime? nextEvalAt;

  const TeacherCommissionInfo({
    this.rate,
    this.tierId,
    this.last30dRevenueEgp = 0,
    this.sessionsLast30d = 0,
    this.totalSessionsLast30d = 0,
    this.lateSessionsLast30d = 0,
    this.evaluatedAt,
    this.nextEvalAt,
  });

  /// Returns the effective rate, falling back to [globalRate] when this
  /// teacher hasn't been evaluated yet.
  double effectiveRate(double globalRate) => rate ?? globalRate;

  /// Looks up the matching tier definition from the configured ladder.
  /// Falls back to the lowest tier when [tierId] is unset.
  CommissionTierModel? currentTier(List<CommissionTierModel> tiers) {
    if (tiers.isEmpty) return null;
    if (tierId == null) {
      final sorted = [...tiers]
        ..sort((a, b) => a.minRevenueEgp.compareTo(b.minRevenueEgp));
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
      ..sort((a, b) => a.minRevenueEgp.compareTo(b.minRevenueEgp));
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

    final onTime = (stats['sessionsLast30d'] as num?)?.toInt() ?? 0;
    final lateCount = (stats['lateSessionsLast30d'] as num?)?.toInt() ?? 0;
    return TeacherCommissionInfo(
      rate: (data['commissionRate'] as num?)?.toDouble(),
      tierId: data['commissionTier'] as String?,
      last30dRevenueEgp:
          (stats['last30dRevenueEgp'] as num?)?.toDouble() ?? 0,
      sessionsLast30d: onTime,
      lateSessionsLast30d: lateCount,
      totalSessionsLast30d:
          (stats['totalSessionsLast30d'] as num?)?.toInt() ?? (onTime + lateCount),
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
