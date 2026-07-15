// Per-tier commission definition. Stored as an array under
// `systemConfig/global.commissionTiers` and read by:
//   • Cloud Function `recomputeTeacherTiers` to assign rates to teachers
//   • Mobile admin UI to edit thresholds and rates
//   • Mobile teacher UI to render progress towards next tier
//
// Plain class (matches SystemConfigModel) so we avoid a build_runner
// regeneration cycle in shared core.

class CommissionTierModel {
  /// Stable identifier, e.g. 'starter', 'active', 'distinguished', 'elite'.
  /// Persisted on `users/{teacherId}.commissionTier`.
  final String id;

  /// Display label in Arabic, e.g. 'البداية', 'نشط'.
  final String labelAr;

  /// Inclusive lower bound on on-time sessions completed in the current
  /// financial cycle to qualify for this tier. Sorted ascending defines the ladder.
  final int minSessions;

  /// Commission rate applied to all transactions while the teacher sits
  /// on this tier (0.0–1.0).
  final double rate;

  /// Optional badge/emoji shown in UI; purely decorative.
  final String? badge;

  const CommissionTierModel({
    required this.id,
    required this.labelAr,
    required this.minSessions,
    required this.rate,
    this.badge,
  });

  factory CommissionTierModel.fromMap(Map<String, dynamic> data) {
    return CommissionTierModel(
      id: data['id'] as String? ?? '',
      labelAr: data['labelAr'] as String? ?? '',
      minSessions: (data['minSessions'] as num?)?.toInt() ?? 0,
      rate: (data['rate'] as num?)?.toDouble() ?? 0.10,
      badge: data['badge'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'labelAr': labelAr,
        'minSessions': minSessions,
        'rate': rate,
        if (badge != null) 'badge': badge,
      };

  CommissionTierModel copyWith({
    String? id,
    String? labelAr,
    int? minSessions,
    double? rate,
    String? badge,
  }) {
    return CommissionTierModel(
      id: id ?? this.id,
      labelAr: labelAr ?? this.labelAr,
      minSessions: minSessions ?? this.minSessions,
      rate: rate ?? this.rate,
      badge: badge ?? this.badge,
    );
  }

  /// Default tier table seeded when admin hasn't configured one yet.
  /// Thresholds are on-time sessions per financial cycle; admin can tune via
  /// the admin tier editor without redeploying.
  static const List<CommissionTierModel> defaultTiers = [
    CommissionTierModel(
      id: 'starter',
      labelAr: 'البداية',
      minSessions: 0,
      rate: 0.15,
      badge: '🌱',
    ),
    CommissionTierModel(
      id: 'active',
      labelAr: 'نشط',
      minSessions: 8,
      rate: 0.12,
      badge: '⭐',
    ),
    CommissionTierModel(
      id: 'intermediate',
      labelAr: 'متوسط',
      minSessions: 14,
      rate: 0.10,
      badge: '✨',
    ),
    CommissionTierModel(
      id: 'distinguished',
      labelAr: 'متميز',
      minSessions: 20,
      rate: 0.08,
      badge: '🏆',
    ),
    CommissionTierModel(
      id: 'elite',
      labelAr: 'نخبة',
      minSessions: 35,
      rate: 0.05,
      badge: '💎',
    ),
  ];

  /// New teachers start from the lowest threshold tier, which carries the
  /// highest platform commission until their completed-session goals lower it.
  static CommissionTierModel starterTier(List<CommissionTierModel> tiers) {
    if (tiers.isEmpty) return defaultTiers.first;
    final sorted = [...tiers]
      ..sort((a, b) => a.minSessions.compareTo(b.minSessions));
    return sorted.first;
  }

  static double starterRate(List<CommissionTierModel> tiers) =>
      starterTier(tiers).rate;

  /// Given a sorted-ascending tier list and a session count, returns the
  /// highest-qualifying tier. Returns null if list is empty.
  static CommissionTierModel? tierForSessions(
    List<CommissionTierModel> tiers,
    int sessions,
  ) {
    if (tiers.isEmpty) return null;
    final sorted = [...tiers]
      ..sort((a, b) => a.minSessions.compareTo(b.minSessions));
    CommissionTierModel current = sorted.first;
    for (final t in sorted) {
      if (sessions >= t.minSessions) current = t;
    }
    return current;
  }
}
