// lib/screens/student/student_rewards_screen.dart
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:shared_preferences/shared_preferences.dart';


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

class _RewardsBody extends ConsumerStatefulWidget {
  final UserModel student;
  const _RewardsBody({required this.student});

  @override
  ConsumerState<_RewardsBody> createState() => _RewardsBodyState();
}

class _RewardsBodyState extends ConsumerState<_RewardsBody> {
  late final ConfettiController _confetti;
  static const _prefKey = 'lastSeenLevelRank';

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _checkLevelUp();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _checkLevelUp() async {
    final sessionsAsync = ref.read(studentCompletedSessionsProvider(widget.student.uid));
    final sessions = sessionsAsync.valueOrNull ?? 0;
    final age = calculateAge(widget.student.dateOfBirth);
    final level = resolveLevel(sessions, age);

    final prefs = await SharedPreferences.getInstance();
    final lastRank = prefs.getInt(_prefKey) ?? -1;
    if (level.rank > lastRank && lastRank != -1) {
      // Promoted since last visit
      if (mounted) {
        _confetti.play();
        _showLevelUpDialog(level);
      }
    }
    await prefs.setInt(_prefKey, level.rank);
  }

  void _showLevelUpDialog(StudentLevel level) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF095752), Color(0xFF0E8278)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ترقية إلى مستوى جديد! 🎉',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    level.name,
                    style: const TextStyle(
                      color: _C.gold,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أنت الآن في المستوى ${level.rank + 1}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.gold,
                        foregroundColor: _C.teal800,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'رائع! 🌟',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -36,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _C.gold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _C.gold.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(level.emoji, style: const TextStyle(fontSize: 36)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surahsAsync   = ref.watch(memorizedSurahsProvider(widget.student.uid));
    final sessionsAsync = ref.watch(studentCompletedSessionsProvider(widget.student.uid));

    final age      = calculateAge(widget.student.dateOfBirth);
    final sessions = sessionsAsync.valueOrNull ?? 0;
    final memorized = surahsAsync.valueOrNull ?? [];
    final level    = resolveLevel(sessions, age);
    final isEmpty  = sessions == 0 && memorized.isEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ── AppBar ────────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: _C.teal700,
                  surfaceTintColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _LevelHeader(
                      student: widget.student,
                      level: level,
                      sessions: sessions,
                      age: age,
                    ),
                  ),
                ),

                // ── Stats row ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _StatsRow(
                    sessions: sessions,
                    memorized: memorized.length,
                    age: age,
                  ),
                ),

                // ── Empty state hero ───────────────────────────────────────
                if (isEmpty)
                  const SliverToBoxAdapter(child: _EmptyStateHero()),

                // ── Next goal ──────────────────────────────────────────────
                if (!isEmpty)
                  SliverToBoxAdapter(
                    child: _NextGoalCard(
                      sessions: sessions,
                      memorizedCount: memorized.length,
                      level: level,
                    ),
                  ),

                // ── Achievements ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _AchievementsSection(
                    sessions: sessions,
                    memorizedCount: memorized.length,
                  ),
                ),

                // ── Surahs grid ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _SurahsSection(
                    memorizedSet: memorized.toSet(),
                    isEarlyStudent: isEmpty,
                  ),
                ),

                // ── Motivational CTA ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: _MotivationalCard(level: level),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),

            // Confetti overlay — sits above the scroll view
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                gravity: 0.3,
                colors: const [
                  _C.gold, Color(0xFF0B7A75), Colors.white,
                  Color(0xFFD4A44A), Color(0xFF14B8A6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state hero ─────────────────────────────────────────────────────────
class _EmptyStateHero extends StatelessWidget {
  const _EmptyStateHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: _C.teal700.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            const Text(
              'ابدأ رحلتك',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _C.text1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'احجز أول حلقة لتبدأ تجميع الإنجازات وفتح الشارات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _C.text2,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _C.teal50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.teal700.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded, color: _C.teal700, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '8 شارات تنتظرك',
                    style: TextStyle(
                      color: _C.teal700,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Progress ring around level emoji
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CustomPaint(
                      painter: _ProgressRingPainter(progress: progress),
                      child: Center(
                        child: Text(level.emoji, style: const TextStyle(fontSize: 30)),
                      ),
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
              // Progress card
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'التقدم للمستوى التالي',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          level.nextMin == -1
                              ? 'أعلى مستوى 🎉'
                              : '$sessions / ${level.nextMin}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: const AlwaysStoppedAnimation<Color>(_C.gold),
                      ),
                    ),
                    if (level.nextMin != -1) ...[
                      const SizedBox(height: 10),
                      Text(
                        '🎯 أكمل $toNext حلقة للوصول للمستوى التالي',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Progress ring painter ────────────────────────────────────────────────────
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  const _ProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 4.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = _C.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
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

// ─── Next goal ────────────────────────────────────────────────────────────────
class _NextGoalCard extends StatelessWidget {
  final int sessions;
  final int memorizedCount;
  final StudentLevel level;

  const _NextGoalCard({
    required this.sessions,
    required this.memorizedCount,
    required this.level,
  });

  // Returns (emoji, title, remaining, kind) for the closest unearned goal.
  ({String emoji, String title, int remaining, String kind})? _closestGoal() {
    final candidates = <({String emoji, String title, int remaining, String kind})>[];

    // Achievement thresholds (sessions)
    const sessionMilestones = [
      (1, '🌟', 'شارة أول خطوة'),
      (5, '🔥', 'شارة المداوم'),
      (15, '💎', 'شارة الحريص'),
      (30, '⚡', 'شارة المثابر'),
      (60, '🏅', 'شارة المتفوق'),
    ];
    for (final (threshold, emoji, title) in sessionMilestones) {
      if (sessions < threshold) {
        candidates.add((
          emoji: emoji,
          title: title,
          remaining: threshold - sessions,
          kind: 'session',
        ));
        break;
      }
    }

    // Memorization thresholds
    const memMilestones = [
      (20, '📜', 'شارة حافظ الجزء'),
      (57, '🌙', 'شارة حافظ النصف'),
      (114, '👑', 'شارة الحافظ الكريم'),
    ];
    for (final (threshold, emoji, title) in memMilestones) {
      if (memorizedCount < threshold) {
        candidates.add((
          emoji: emoji,
          title: title,
          remaining: threshold - memorizedCount,
          kind: 'surah',
        ));
        break;
      }
    }

    // Level-up
    if (level.nextMin != -1) {
      final toNext = level.sessionsToNext(sessions);
      candidates.add((
        emoji: '⬆️',
        title: 'الترقية لمستوى أعلى',
        remaining: toNext,
        kind: 'session',
      ));
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.remaining.compareTo(b.remaining));
    return candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    final goal = _closestGoal();
    if (goal == null) return const SizedBox.shrink();

    final unit = goal.kind == 'session' ? 'حلقة' : 'سورة';
    final verb = goal.kind == 'session' ? 'أكمل' : 'احفظ';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _C.gold.withValues(alpha: 0.18),
              _C.gold.withValues(alpha: 0.04),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.gold.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _C.gold.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(goal.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎯 هدفك القادم',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _C.goldDark,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$verb ${goal.remaining} $unit لفتح ${goal.title}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _C.text1,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
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
          const _SectionTitle('الإنجازات'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9,
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

  void _showEarnedSheet(BuildContext context, _BadgeData b) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _C.goldBg,
                shape: BoxShape.circle,
                border: Border.all(color: _C.gold, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _C.gold.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(b.emoji, style: const TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '🎉 حصلت على هذه الشارة!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _C.goldDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              b.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _C.text1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              b.hint,
              style: const TextStyle(fontSize: 14, color: _C.text2),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.teal700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'ممتاز! 💪',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: badge.earned
          ? () => _showEarnedSheet(context, badge)
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
// Mapping: which juz each surah starts in (1-114 → 1-30).
const _surahStartJuz = <int>[
  1, 1, 3, 4, 6, 7, 8, 9, 10, 11, 11, 12, 13, 13, 14, 14, 15, 15, 16, 16,
  17, 17, 18, 18, 18, 19, 19, 20, 20, 21, 21, 21, 21, 22, 22, 22, 23, 23, 23, 24,
  24, 25, 25, 25, 25, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 28, 28, 28,
  28, 28, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 30, 30, 30,
  30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
  30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
];

const _juzNames = <int, String>{
  30: 'جزء عمّ',
  29: 'جزء تبارك',
  28: 'جزء قد سمع',
};

String _juzLabel(int juz) => _juzNames[juz] ?? 'الجزء $juz';

class _SurahsSection extends StatefulWidget {
  final Set<int> memorizedSet;
  final bool isEarlyStudent;
  const _SurahsSection({required this.memorizedSet, required this.isEarlyStudent});

  @override
  State<_SurahsSection> createState() => _SurahsSectionState();
}

class _SurahsSectionState extends State<_SurahsSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final byJuz = <int, List<int>>{};
    for (var n = 1; n <= 114; n++) {
      byJuz.putIfAbsent(_surahStartJuz[n - 1], () => []).add(n);
    }
    final allJuzKeys = byJuz.keys.toList()..sort((a, b) => b.compareTo(a));

    // Early students (0 sessions, nothing memorized): only show Juz 30 by default.
    final visibleKeys = (widget.isEarlyStudent && !_showAll)
        ? allJuzKeys.where((j) => j == 30).toList()
        : allJuzKeys;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle('السور المحفوظة'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.memorizedSet.isNotEmpty ? _C.goldBg : _C.teal50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.memorizedSet.length} / 114',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.memorizedSet.isNotEmpty ? _C.goldDark : _C.teal700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final juz in visibleKeys)
            _JuzGroup(
              juz: juz,
              surahs: byJuz[juz]!,
              memorizedSet: widget.memorizedSet,
            ),
          if (widget.isEarlyStudent && !_showAll)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() => _showAll = true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _C.teal50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.teal700.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.expand_more_rounded, color: _C.teal700, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'عرض باقي الأجزاء (29 جزءاً)',
                        style: TextStyle(
                          color: _C.teal700,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _JuzGroup extends StatelessWidget {
  final int juz;
  final List<int> surahs;
  final Set<int> memorizedSet;

  const _JuzGroup({
    required this.juz,
    required this.surahs,
    required this.memorizedSet,
  });

  @override
  Widget build(BuildContext context) {
    final memorizedHere = surahs.where(memorizedSet.contains).length;
    final total = surahs.length;
    final isComplete = memorizedHere == total && total > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isComplete ? _C.gold : _C.teal700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _juzLabel(juz),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _C.text1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isComplete ? _C.goldBg : _C.teal50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$memorizedHere / $total',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isComplete ? _C.goldDark : _C.teal700,
                    ),
                  ),
                ),
                if (isComplete) ...[
                  const SizedBox(width: 6),
                  const Text('✨', style: TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: surahs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (_, index) {
              final surahNum = surahs[index];
              return _SurahBadge(
                number: surahNum,
                name: surahNames[surahNum - 1],
                memorized: memorizedSet.contains(surahNum),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Section title with gold bar ─────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 22,
          decoration: BoxDecoration(
            color: _C.gold,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _C.text1,
          ),
        ),
      ],
    );
  }
}

// ─── Motivational CTA card ────────────────────────────────────────────────────
class _MotivationalCard extends StatelessWidget {
  final StudentLevel level;
  const _MotivationalCard({required this.level});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF095752), Color(0xFF0E8278)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  level.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'استمر يا بطل 🌟',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'أنت تحقق تقدماً رائعاً في رحلة حفظ القرآن الكريم',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
