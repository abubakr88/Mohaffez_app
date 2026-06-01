// lib/screens/student/student_rewards_screen.dart
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/sound_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _C {
  static const teal800 = Color(0xFF095752);
  static const teal700 = Color(0xFF0C6F6A);
  static const teal50 = Color(0xFFEAF6F3);
  static const gold = Color(0xFFD4A44A);
  static const goldBg = Color(0xFFFFF8E1);
  static const goldDark = Color(0xFFB7791F);
  static const flame = Color(0xFFF97316);
  static const flameBg = Color(0xFFFFF1E6);
  static const bg = Color(0xFFF4F7F6);
  static const text1 = Color(0xFF111827);
  static const text2 = Color(0xFF4B5563);
  static const text3 = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5EDE9);
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
        backgroundColor: _C.bg,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        backgroundColor: _C.bg,
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
  static const _levelPrefKey = 'lastSeenLevelRank';
  static const _seenAchPrefKey = 'seenAchievementIds';
  bool _celebrationChecked = false;
  AchievementCategory? _filter; // null = all

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  /// Fires once per screen entry, after both data sources have loaded. Celebrates
  /// any achievement earned since the last visit, plus a level-up.
  Future<void> _runCelebrations({
    required StudentLevel level,
    required List<Achievement> achievements,
  }) async {
    if (_celebrationChecked) return;
    _celebrationChecked = true;

    final prefs = await SharedPreferences.getInstance();

    // ── New achievements ──
    final earnedIds = achievements.where((a) => a.earned).map((a) => a.id).toSet();
    final seen = prefs.getStringList(_seenAchPrefKey)?.toSet();
    if (seen != null) {
      final fresh = earnedIds.difference(seen);
      if (fresh.isNotEmpty && mounted) {
        final ach = achievements.firstWhere((a) => a.id == fresh.first);
        _confetti.play();
        SoundService.play(Sfx.badge);
        await _showAchievementDialog(ach);
      }
    }
    await prefs.setStringList(_seenAchPrefKey, earnedIds.toList());

    // ── Level up ──
    final lastRank = prefs.getInt(_levelPrefKey) ?? -1;
    if (level.rank > lastRank && lastRank != -1 && mounted) {
      _confetti.play();
      SoundService.play(Sfx.levelUp);
      _showLevelUpDialog(level);
    }
    await prefs.setInt(_levelPrefKey, level.rank);
  }

  Future<void> _showAchievementDialog(Achievement ach) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎉 إنجاز جديد!',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _C.goldDark)),
                    const SizedBox(height: 8),
                    Text(ach.title,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _C.text1)),
                    const SizedBox(height: 6),
                    Text(ach.hint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: _C.text2)),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.teal700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('رائع! 💪',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -36,
                child: _GlowBadge(emoji: ach.emoji, color: _C.gold),
              ),
            ],
          ),
        ),
      ),
    );
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
                        style:
                            TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -36,
              child: _GlowBadge(emoji: level.emoji, color: _C.gold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.student.uid;
    final surahsAsync = ref.watch(memorizedSurahsProvider(uid));
    final progressAsync = ref.watch(studentProgressProvider(uid));

    final age = calculateAge(widget.student.dateOfBirth);
    final progress = progressAsync.valueOrNull ?? const StudentProgress();
    final memorized = surahsAsync.valueOrNull ?? const <int>[];
    final memorizedSet = memorized.toSet();

    final sessions = progress.sessions;
    final streak = progress.weeklyStreak;
    final quiz = progress.quiz;
    final juzDone = completedJuzCount(memorizedSet);
    final level = resolveLevel(sessions, age);
    final xp = computeXp(
      sessions: sessions,
      memorizedFraction: memorizedQuranFraction(memorizedSet),
      quizCorrect: quiz.totalCorrect,
    );
    final xpTier = resolveXpTier(xp);

    final achievements = buildAchievementsFull(
      sessions: sessions,
      memorizedSet: memorizedSet,
      weeklyStreak: streak,
      quiz: quiz,
    );

    final isEmpty = sessions == 0 && memorized.isEmpty;

    // Once both async sources are resolved, run the entry celebrations.
    if (progressAsync.hasValue && surahsAsync.hasValue && !_celebrationChecked) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _runCelebrations(level: level, achievements: achievements),
      );
    }

    final filtered = _filter == null
        ? achievements
        : achievements.where((a) => a.category == _filter).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 286,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: _C.teal700,
                  surfaceTintColor: Colors.transparent,
                  actions: [
                    IconButton(
                      tooltip: SoundService.enabled ? 'كتم الصوت' : 'تشغيل الصوت',
                      icon: Icon(
                        SoundService.enabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        await SoundService.setEnabled(!SoundService.enabled);
                        if (SoundService.enabled) SoundService.play(Sfx.tap);
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _LevelHeader(
                      student: widget.student,
                      level: level,
                      xpTier: xpTier,
                      xp: xp,
                      sessions: sessions,
                      age: age,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _StatsRow(
                    sessions: sessions,
                    memorized: memorized.length,
                    juz: juzDone,
                    streak: streak,
                  ),
                ),

                if (isEmpty) const SliverToBoxAdapter(child: _EmptyStateHero()),

                if (!isEmpty && streak >= 2)
                  SliverToBoxAdapter(child: _StreakCard(streak: streak)),

                if (!isEmpty)
                  SliverToBoxAdapter(
                    child: _NextGoalCard(achievements: achievements),
                  ),

                if (quiz.totalAsked > 0)
                  SliverToBoxAdapter(child: _QuizMasteryCard(quiz: quiz)),

                // Achievements with category filter
                SliverToBoxAdapter(
                  child: _AchievementsHeader(
                    earned: achievements.where((a) => a.earned).length,
                    total: achievements.length,
                    filter: _filter,
                    onFilter: (c) {
                      SoundService.play(Sfx.tap);
                      setState(() => _filter = c);
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _AchievementCard(
                        achievement: filtered[i],
                        index: i,
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _SurahsSection(
                    memorizedSet: memorizedSet,
                    isEarlyStudent: isEmpty,
                  ),
                ),

                SliverToBoxAdapter(child: _MotivationalCard(level: level)),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),

            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                gravity: 0.3,
                colors: const [
                  _C.gold,
                  Color(0xFF0B7A75),
                  Colors.white,
                  Color(0xFFD4A44A),
                  Color(0xFF14B8A6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glow badge (used in celebration dialogs) ──────────────────────────────────
class _GlowBadge extends StatelessWidget {
  final String emoji;
  final Color color;
  const _GlowBadge({required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
      ),
    );
  }
}

// ─── Animated integer counter ──────────────────────────────────────────────────
class _AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle style;
  const _AnimatedCount({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}', style: style),
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
              'احجز أول حلقة لتبدأ تجميع النقاط وفتح الإنجازات',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _C.text2, height: 1.6),
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
                    '21 إنجازاً ينتظرك',
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

// ─── Level header (XP tier + progress) ─────────────────────────────────────────
class _LevelHeader extends StatelessWidget {
  final UserModel student;
  final StudentLevel level;
  final XpTier xpTier;
  final int xp;
  final int sessions;
  final int age;

  const _LevelHeader({
    required this.student,
    required this.level,
    required this.xpTier,
    required this.xp,
    required this.sessions,
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    final tierProgress = xpTier.progress(xp);
    final toNext = xpTier.toNext(xp);

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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: tierProgress),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (_, p, __) => CustomPaint(
                        painter: _ProgressRingPainter(
                            progress: p, color: _C.gold, bg: Colors.white24),
                        child: Center(
                          child: Text(xpTier.emoji,
                              style: const TextStyle(fontSize: 30)),
                        ),
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
                          xpTier.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Row(
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            _AnimatedCount(
                              value: xp,
                              style: const TextStyle(
                                color: _C.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              ' نقطة',
                              style:
                                  TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _C.gold.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _C.gold.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      level.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                          'التقدم للرتبة التالية',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          xpTier.next == -1 ? 'أعلى رتبة 🎉' : '$xp / ${xpTier.next}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: tierProgress),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (_, p, __) => LinearProgressIndicator(
                          value: p,
                          minHeight: 10,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(_C.gold),
                        ),
                      ),
                    ),
                    if (xpTier.next != -1) ...[
                      const SizedBox(height: 10),
                      Text(
                        '🎯 اجمع $toNext نقطة للوصول للرتبة التالية',
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
  final Color color;
  final Color bg;
  const _ProgressRingPainter({
    required this.progress,
    this.color = _C.gold,
    this.bg = const Color(0x33FFFFFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 4.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Stats row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int sessions;
  final int memorized;
  final int juz;
  final int streak;

  const _StatsRow({
    required this.sessions,
    required this.memorized,
    required this.juz,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatCard(label: 'الحلقات', value: sessions, emoji: '📚'),
          const SizedBox(width: 8),
          _StatCard(label: 'سور', value: memorized, emoji: '🌟'),
          const SizedBox(width: 8),
          _StatCard(label: 'أجزاء', value: juz, emoji: '📖'),
          const SizedBox(width: 8),
          _StatCard(
              label: 'أسابيع متتالية', value: streak, emoji: '🔥', highlight: true),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final String emoji;
  final bool highlight;

  const _StatCard({
    required this.label,
    required this.value,
    required this.emoji,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? _C.flame : _C.teal700;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            _AnimatedCount(
              value: value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: _C.text3),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Streak card ──────────────────────────────────────────────────────────────
class _StreakCard extends StatelessWidget {
  final int streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _C.flame.withValues(alpha: 0.16),
              _C.flame.withValues(alpha: 0.03),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.flame.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: _C.flameBg,
                shape: BoxShape.circle,
              ),
              child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سلسلة مواظبة: $streak ${streak == 2 ? 'أسبوعين' : 'أسابيع'}!',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _C.text1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'احجز حلقة هذا الأسبوع لتحافظ على سلسلتك 💪',
                    style: TextStyle(fontSize: 12, color: _C.text2),
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

// ─── Next goal ────────────────────────────────────────────────────────────────
class _NextGoalCard extends StatelessWidget {
  final List<Achievement> achievements;
  const _NextGoalCard({required this.achievements});

  @override
  Widget build(BuildContext context) {
    final locked = achievements.where((a) => !a.earned).toList()
      ..sort((a, b) => a.remaining.compareTo(b.remaining));
    if (locked.isEmpty) return const SizedBox.shrink();
    final goal = locked.first;

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
            SizedBox(
              width: 48,
              height: 48,
              child: CustomPaint(
                painter: _ProgressRingPainter(
                  progress: goal.progress,
                  color: _C.gold,
                  bg: _C.gold.withValues(alpha: 0.2),
                ),
                child: Center(
                  child: Text(goal.emoji, style: const TextStyle(fontSize: 22)),
                ),
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
                    'باقي ${goal.remaining} لفتح «${goal.title}»',
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

// ─── Quiz mastery card ─────────────────────────────────────────────────────────
class _QuizMasteryCard extends StatelessWidget {
  final QuizStats quiz;
  const _QuizMasteryCard({required this.quiz});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('إتقان التحديات'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border),
              boxShadow: [
                BoxShadow(
                  color: _C.teal700.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                _MiniStat(
                    emoji: '✅', value: quiz.totalCorrect, label: 'إجابة صحيحة'),
                _divider(),
                _MiniStat(emoji: '💯', value: quiz.accuracyPct, label: 'الدقة %'),
                _divider(),
                _MiniStat(emoji: '⚡', value: quiz.bestStreak, label: 'أطول سلسلة'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: _C.border);
}

class _MiniStat extends StatelessWidget {
  final String emoji;
  final int value;
  final String label;
  const _MiniStat(
      {required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          _AnimatedCount(
            value: value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _C.teal700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: _C.text3),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Achievements header + filter chips ────────────────────────────────────────
class _AchievementsHeader extends StatelessWidget {
  final int earned;
  final int total;
  final AchievementCategory? filter;
  final ValueChanged<AchievementCategory?> onFilter;

  const _AchievementsHeader({
    required this.earned,
    required this.total,
    required this.filter,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                const _SectionTitle('الإنجازات'),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _C.goldBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$earned / $total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _C.goldDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              children: [
                _Chip(
                  label: 'الكل',
                  selected: filter == null,
                  onTap: () => onFilter(null),
                ),
                ...AchievementCategory.values.map(
                  (c) => _Chip(
                    label: c.label,
                    selected: filter == c,
                    onTap: () => onFilter(c),
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

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _C.teal700 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _C.teal700 : _C.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _C.text2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Achievement card (with progress on locked) ────────────────────────────────
class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final int index;
  const _AchievementCard({required this.achievement, required this.index});

  void _showSheet(BuildContext context) {
    final b = achievement;
    SoundService.play(b.earned ? Sfx.badge : Sfx.tap);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _C.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: b.earned ? _C.goldBg : _C.bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: b.earned ? _C.gold : _C.border,
                    width: 2,
                  ),
                  boxShadow: b.earned
                      ? [
                          BoxShadow(
                            color: _C.gold.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          )
                        ]
                      : null,
                ),
                child: Center(
                    child: Text(b.emoji, style: const TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 16),
              Text(
                b.earned ? '🎉 تم فتح هذا الإنجاز!' : 'إنجاز مقفل',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: b.earned ? _C.goldDark : _C.text3,
                ),
              ),
              const SizedBox(height: 8),
              Text(b.title,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _C.text1)),
              const SizedBox(height: 8),
              Text(b.hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: _C.text2)),
              if (!b.earned) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: LinearProgressIndicator(
                    value: b.progress,
                    minHeight: 8,
                    backgroundColor: _C.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_C.teal700),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${b.current} / ${b.target}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.teal700,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.teal700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(b.earned ? 'ممتاز! 💪' : 'واصل التقدم 🚀',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = achievement;
    // Staggered entry: later cards finish slightly later → cascade effect.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + index * 45),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.8 + 0.2 * t.clamp(0.0, 1.0), child: child),
      ),
      child: GestureDetector(
        onTap: () => _showSheet(context),
        child: Container(
          decoration: BoxDecoration(
            color: b.earned ? _C.goldBg : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: b.earned ? _C.gold.withValues(alpha: 0.6) : _C.border,
            ),
            boxShadow: b.earned
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
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!b.earned)
                      CustomPaint(
                        size: const Size(50, 50),
                        painter: _ProgressRingPainter(
                          progress: b.progress,
                          color: _C.teal700,
                          bg: _C.border,
                        ),
                      ),
                    ColorFiltered(
                      colorFilter: b.earned
                          ? const ColorFilter.mode(
                              Colors.transparent, BlendMode.dst)
                          : const ColorFilter.matrix([
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                      child: Text(
                        b.emoji,
                        style: TextStyle(
                          fontSize: 26,
                          color: b.earned ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  b.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: b.earned ? _C.goldDark : _C.text3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!b.earned) ...[
                const SizedBox(height: 2),
                Text(
                  '${b.current}/${b.target}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _C.text3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Surahs grid ─────────────────────────────────────────────────────────────
const _juzNames = <int, String>{
  30: 'جزء عمّ',
  29: 'جزء تبارك',
  28: 'جزء قد سمع',
};

String _juzLabel(int juz) => _juzNames[juz] ?? 'الجزء $juz';

class _SurahsSection extends StatefulWidget {
  final Set<int> memorizedSet;
  final bool isEarlyStudent;
  const _SurahsSection(
      {required this.memorizedSet, required this.isEarlyStudent});

  @override
  State<_SurahsSection> createState() => _SurahsSectionState();
}

class _SurahsSectionState extends State<_SurahsSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final byJuz = <int, List<int>>{};
    for (var n = 1; n <= 114; n++) {
      byJuz.putIfAbsent(surahStartJuz[n - 1], () => []).add(n);
    }
    final allJuzKeys = byJuz.keys.toList()..sort((a, b) => b.compareTo(a));

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
                  color:
                      widget.memorizedSet.isNotEmpty ? _C.goldBg : _C.teal50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.memorizedSet.length} / 114',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.memorizedSet.isNotEmpty
                        ? _C.goldDark
                        : _C.teal700,
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
                    border:
                        Border.all(color: _C.teal700.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.expand_more_rounded,
                          color: _C.teal700, size: 20),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                child: Text(level.emoji, style: const TextStyle(fontSize: 28)),
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
          color: memorized ? _C.gold.withValues(alpha: 0.7) : _C.border,
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
