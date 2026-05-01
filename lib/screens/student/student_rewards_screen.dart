// lib/screens/student/student_rewards_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../providers/student_rewards_provider.dart';
import '../../providers/user_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _C {
  static const teal800  = Color(0xFF095752);
  static const teal700  = Color(0xFF0C6F6A);
  static const teal50   = Color(0xFFEAF6F3);
  static const gold     = Color(0xFFD4A44A);
  static const goldBg   = Color(0xFFFFF8E1);
  static const goldDark = Color(0xFFB7791F);
  static const bg       = Color(0xFFF4F7F6);
  static const text1    = Color(0xFF111827);
  static const text2    = Color(0xFF4B5563);
  static const text3    = Color(0xFF9CA3AF);
  static const border   = Color(0xFFE5EDE9);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class StudentRewardsScreen extends ConsumerWidget {
  /// Pass the student's user doc so we can read dateOfBirth + uid.
  /// When null, falls back to currentUserProvider (viewing own profile).
  final UserModel? student;

  const StudentRewardsScreen({super.key, this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('حدث خطأ')),
      ),
      data: (currentUser) {
        final resolvedUser = student ?? currentUser;
        if (resolvedUser == null) {
          return const Scaffold(body: Center(child: Text('لا توجد بيانات')));
        }
        return _RewardsBody(student: resolvedUser);
      },
    );
  }
}

class _RewardsBody extends ConsumerWidget {
  final UserModel student;
  const _RewardsBody({required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahsAsync  = ref.watch(memorizedSurahsProvider(student.uid));
    final sessionsAsync = ref.watch(studentCompletedSessionsProvider(student.uid));

    final age = calculateAge(student.dateOfBirth);
    final sessions = sessionsAsync.valueOrNull ?? 0;
    final memorized = surahsAsync.valueOrNull ?? [];
    final level = resolveLevel(sessions, age);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: CustomScrollView(
          slivers: [
            // ── AppBar ──────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              elevation: 0,
              backgroundColor: _C.teal700,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _LevelHeader(
                  student: student,
                  level: level,
                  sessions: sessions,
                  age: age,
                ),
              ),
            ),

            // ── Stats row ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _StatsRow(
                sessions: sessions,
                memorized: memorized.length,
                age: age,
              ),
            ),

            // ── Achievements ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _AchievementsSection(
                sessions: sessions,
                memorizedCount: memorized.length,
              ),
            ),

            // ── Surahs grid ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SurahsSection(memorizedSet: memorized.toSet()),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ─── Level header ─────────────────────────────────────────────────────────────
class _LevelHeader extends StatelessWidget {
  final UserModel student;
  final StudentLevel level;
  final int sessions;
  final int age;

  const _LevelHeader({
    required this.student,
    required this.level,
    required this.sessions,
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    final progress = level.progressTo(sessions);
    final toNext   = level.sessionsToNext(sessions);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF095752), Color(0xFF0C6F6A), Color(0xFF0E8278)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Big emoji in a golden circle
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _C.gold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.gold.withValues(alpha: 0.6), width: 2),
                    ),
                    child: Center(
                      child: Text(level.emoji, style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          level.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (age > 0)
                          Text(
                            'العمر: $age سنة',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Level rank badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _C.gold.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _C.gold.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'مستوى ${level.rank + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$sessions حلقة',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        level.nextMin == -1
                            ? 'أعلى مستوى 🎉'
                            : 'المستوى التالي بعد $toNext حلقة',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(_C.gold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int sessions;
  final int memorized;
  final int age;

  const _StatsRow({
    required this.sessions,
    required this.memorized,
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatCard(label: 'الحلقات', value: '$sessions', emoji: '📚'),
          const SizedBox(width: 10),
          _StatCard(label: 'سور محفوظة', value: '$memorized', emoji: '🌟'),
          const SizedBox(width: 10),
          const _StatCard(label: 'من أصل', value: '114', emoji: '📖'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;

  const _StatCard({required this.label, required this.value, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0C6F6A).withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _C.teal700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: _C.text3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Achievements ─────────────────────────────────────────────────────────────
class _AchievementsSection extends StatelessWidget {
  final int sessions;
  final int memorizedCount;

  const _AchievementsSection({
    required this.sessions,
    required this.memorizedCount,
  });

  @override
  Widget build(BuildContext context) {
    final badges = [
      _BadgeData('أول خطوة',    '🌟', sessions >= 1,     'أكمل أول حلقة'),
      _BadgeData('المداوم',     '🔥', sessions >= 5,     '5 حلقات مكتملة'),
      _BadgeData('الحريص',     '💎', sessions >= 15,    '15 حلقة مكتملة'),
      _BadgeData('المثابر',    '⚡', sessions >= 30,    '30 حلقة مكتملة'),
      _BadgeData('المتفوق',    '🏅', sessions >= 60,    '60 حلقة مكتملة'),
      _BadgeData('حافظ الجزء', '📜', memorizedCount >= 20,  'حفظ 20 سورة'),
      _BadgeData('حافظ النصف', '🌙', memorizedCount >= 57,  'حفظ 57 سورة'),
      _BadgeData('الحافظ الكريم', '👑', memorizedCount >= 114, 'حفظ القرآن كاملاً'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الإنجازات',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _C.text1,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.78,
            children: badges.map((b) => _BadgeCard(badge: b)).toList(),
          ),
        ],
      ),
    );
  }
}

class _BadgeData {
  final String title;
  final String emoji;
  final bool earned;
  final String hint;
  const _BadgeData(this.title, this.emoji, this.earned, this.hint);
}

class _BadgeCard extends StatelessWidget {
  final _BadgeData badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: badge.earned
          ? null
          : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('للحصول على هذه الشارة: ${badge.hint}'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              ),
      child: Container(
        decoration: BoxDecoration(
          color: badge.earned ? _C.goldBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: badge.earned
                ? _C.gold.withValues(alpha: 0.6)
                : _C.border,
          ),
          boxShadow: badge.earned
              ? [
                  BoxShadow(
                    color: _C.gold.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: badge.earned
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      1, 0,
                    ]),
              child: Text(
                badge.emoji,
                style: TextStyle(
                  fontSize: 28,
                  color: badge.earned ? null : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              badge.title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badge.earned ? _C.goldDark : _C.text3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Surahs grid ─────────────────────────────────────────────────────────────
class _SurahsSection extends StatelessWidget {
  final Set<int> memorizedSet;
  const _SurahsSection({required this.memorizedSet});

  @override
  Widget build(BuildContext context) {
    // Show surahs in reverse (114 → 1) since juz amma is memorized first
    final ordered = List.generate(114, (i) => 114 - i);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'السور المحفوظة',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _C.text1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: memorizedSet.isNotEmpty ? _C.goldBg : _C.teal50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${memorizedSet.length} / 114',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: memorizedSet.isNotEmpty ? _C.goldDark : _C.teal700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 114,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (_, index) {
              final surahNum = ordered[index];
              final isMemorized = memorizedSet.contains(surahNum);
              return _SurahBadge(
                number: surahNum,
                name: surahNames[surahNum - 1],
                memorized: isMemorized,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SurahBadge extends StatelessWidget {
  final int number;
  final String name;
  final bool memorized;

  const _SurahBadge({
    required this.number,
    required this.name,
    required this.memorized,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: memorized
            ? LinearGradient(
                colors: [
                  _C.gold.withValues(alpha: 0.15),
                  _C.gold.withValues(alpha: 0.05),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              )
            : null,
        color: memorized ? null : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: memorized
              ? _C.gold.withValues(alpha: 0.7)
              : _C.border,
          width: memorized ? 1.5 : 1,
        ),
        boxShadow: memorized
            ? [
                BoxShadow(
                  color: _C.gold.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: Stack(
        children: [
          if (memorized)
            Positioned(
              top: 3,
              left: 3,
              child: Icon(
                Icons.check_circle,
                size: 12,
                color: _C.gold.withValues(alpha: 0.8),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: memorized ? _C.goldDark : _C.text3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: memorized ? FontWeight.w800 : FontWeight.w500,
                      color: memorized ? _C.teal800 : _C.text2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
