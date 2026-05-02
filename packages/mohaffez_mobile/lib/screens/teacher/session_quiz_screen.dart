import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quiz/games/complete_ayah_game.dart';
import 'quiz/games/custom_questions_game.dart';
import 'quiz/games/name_surah_game.dart';
import 'quiz/games/order_ayahs_game.dart';
import 'quiz/games/tajweed_rule_game.dart';
import 'quiz/state/quiz_session_controller.dart';
import 'quiz/widgets/confetti_overlay.dart';
import 'quiz/widgets/quiz_background.dart';
import 'quiz/widgets/score_badge.dart';
import 'quiz/state/quiz_session_controller.dart'
    show quizSessionControllerProvider;
import 'package:mohaffez_finder_app/providers/quiz_access_provider.dart';

enum _GameMode {
  selector,
  completeAyah,
  nameSurah,
  tajweedRule,
  orderAyahs,
  customQuestions,
}

class SessionQuizScreen extends ConsumerStatefulWidget {
  final String? studentName;
  final String? mohaffezId;
  final String? studentId;
  final String? sessionId;

  const SessionQuizScreen({
    super.key,
    this.studentName,
    this.mohaffezId,
    this.studentId,
    this.sessionId,
  });

  @override
  ConsumerState<SessionQuizScreen> createState() => _SessionQuizScreenState();
}

class _SessionQuizScreenState extends ConsumerState<SessionQuizScreen>
    with SingleTickerProviderStateMixin {
  _GameMode _mode = _GameMode.selector;
  final ConfettiOverlayController _confetti = ConfettiOverlayController();
  AnimationController? _floatController;

  AnimationController get _safeFloatController {
    return _floatController ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void initState() {
    super.initState();
    _safeFloatController;
  }

  @override
  void dispose() {
    _floatController?.dispose();
    super.dispose();
  }

  void _saveQuizResults() {
    final sid = widget.sessionId;
    if (sid == null) return;
    final s = ref.read(quizSessionControllerProvider);
    if (s.asked == 0) return;
    saveQuizResults(
      sessionId: sid,
      correct: s.correct,
      asked: s.asked,
      bestStreak: s.bestStreak,
      accuracyPct: s.accuracyPct,
    ).catchError((_) {});
  }

  void _goTo(_GameMode m) {
    HapticFeedback.lightImpact();
    setState(() => _mode = m);
  }

  void _backToSelector() => setState(() => _mode = _GameMode.selector);

  String get _title => switch (_mode) {
        _GameMode.selector        => 'تحديات الجلسة',
        _GameMode.completeAyah    => 'أكمل الآية',
        _GameMode.nameSurah       => 'تحديد السورة',
        _GameMode.tajweedRule     => 'أحكام التجويد',
        _GameMode.orderAyahs      => 'ترتيب الآيات',
        _GameMode.customQuestions => 'تحديات المحفظ',
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveQuizResults();
      },
      child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: QuizBackground(
          child: ConfettiOverlay(
            controller: _confetti,
            child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: KeyedSubtree(
                    key: ValueKey(_mode),
                    child: _buildBody(),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final session = ref.watch(quizSessionControllerProvider);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E), Color(0xFF0E6B62)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -30, left: -30,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -20, right: 40,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Floating stars
            ..._buildFloatingStars(),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Nav row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_mode == _GameMode.selector) {
                            Navigator.of(context).pop();
                          } else {
                            _backToSelector();
                          }
                        },
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (session.asked > 0)
                        ScoreBadge(
                          correct: session.correct,
                          total: session.asked,
                          streak: session.streak,
                        )
                      else
                        _ScorePill(label: '⭐ 0 / 0'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Welcome banner — only on selector
                  if (_mode == _GameMode.selector)
                    _WelcomeBanner(studentName: widget.studentName),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFloatingStars() {
    final positions = [
      const Offset(20, 8),
      const Offset(80, 30),
      const Offset(160, 10),
    ];
    return List.generate(positions.length, (i) {
      return Positioned(
        top: positions[i].dy,
        left: positions[i].dx,
        child: AnimatedBuilder(
          animation: _safeFloatController,
          builder: (_, __) {
            final offset = Tween<double>(begin: 0, end: -6).animate(
              CurvedAnimation(
                parent: _safeFloatController,
                curve: Interval(i * 0.2, 1.0, curve: Curves.easeInOut),
              ),
            ).value;
            return Transform.translate(
              offset: Offset(0, offset),
              child: Text(
                '✦',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  // ─── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_mode) {
      case _GameMode.selector:
        return _KidsSelector(
          studentName: widget.studentName,
          mohaffezId: widget.mohaffezId,
          studentId: widget.studentId,
          onSelect: _goTo,
        );
      case _GameMode.completeAyah:
        return CompleteAyahGame(
          confetti: _confetti,
          onBackToMenu: _backToSelector,
        );
      case _GameMode.nameSurah:
        return NameSurahGame(
          confetti: _confetti,
          onBackToMenu: _backToSelector,
        );
      case _GameMode.tajweedRule:
        return TajweedRuleGame(
          confetti: _confetti,
          onBackToMenu: _backToSelector,
        );
      case _GameMode.orderAyahs:
        return OrderAyahsGame(
          confetti: _confetti,
          onBackToMenu: _backToSelector,
        );
      case _GameMode.customQuestions:
        return CustomQuestionsGame(
          mohaffezId: widget.mohaffezId!,
          studentId: widget.studentId!,
          confetti: _confetti,
          onBackToMenu: _backToSelector,
        );
    }
  }
}

// ─── Welcome Banner ──────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String? studentName;
  const _WelcomeBanner({this.studentName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🌟', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName != null
                      ? 'جلسة تحدي مع $studentName!'
                      : 'اختر تحديك وابدأ الرحلة!',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'اختر تحديك وابدأ الرحلة 🚀',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
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

// ─── Score Pill (empty state) ─────────────────────────────────────────────────

class _ScorePill extends StatelessWidget {
  final String label;
  const _ScorePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Kids Selector ───────────────────────────────────────────────────────────

class _KidsModeData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color borderColor;
  final Color iconBg;
  final Color accentColor;
  final int stars; // 1–3
  final _GameMode mode;

  const _KidsModeData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.borderColor,
    required this.iconBg,
    required this.accentColor,
    required this.stars,
    required this.mode,
  });
}

const _kidsModes = <_KidsModeData>[
  _KidsModeData(
    emoji: '📖',
    title: 'أكمل الآية',
    subtitle: 'أكمل الآية من أولها',
    borderColor: Color(0xFF99F6E4),
    iconBg: Color(0xFFCCFBF1),
    accentColor: Color(0xFF0D9488),
    stars: 3,
    mode: _GameMode.completeAyah,
  ),
  _KidsModeData(
    emoji: '🔍',
    title: 'حدد السورة',
    subtitle: 'من أي سورة هذه الآية؟',
    borderColor: Color(0xFFFDE68A),
    iconBg: Color(0xFFFEF3C7),
    accentColor: Color(0xFFF59E0B),
    stars: 2,
    mode: _GameMode.nameSurah,
  ),
  _KidsModeData(
    emoji: '📚',
    title: 'أحكام التجويد',
    subtitle: 'ما الحكم في الآية؟',
    borderColor: Color(0xFFDDD6FE),
    iconBg: Color(0xFFEDE9FE),
    accentColor: Color(0xFF7C3AED),
    stars: 1,
    mode: _GameMode.tajweedRule,
  ),
  _KidsModeData(
    emoji: '🔀',
    title: 'رتّب الآيات',
    subtitle: 'رتّب حسب ترتيبها',
    borderColor: Color(0xFFBAE6FD),
    iconBg: Color(0xFFE0F2FE),
    accentColor: Color(0xFF0284C7),
    stars: 2,
    mode: _GameMode.orderAyahs,
  ),
];

class _KidsSelector extends ConsumerWidget {
  final String? studentName;
  final String? mohaffezId;
  final String? studentId;
  final ValueChanged<_GameMode> onSelect;

  const _KidsSelector({
    required this.studentName,
    required this.mohaffezId,
    required this.studentId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int customCount = 0;
    if (mohaffezId != null && studentId != null) {
      final p = (mohaffezId: mohaffezId!, studentId: studentId!);
      final all = ref.watch(studentChallengesProvider(p)).valueOrNull ?? [];
      customCount = all.where((q) => q.isActive).length;
    }
    final session = ref.watch(quizSessionControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Row(
            children: [
              Container(
                width: 5, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'اختر نوع التحدي',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF134E4A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2×2 game grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemCount: _kidsModes.length,
            itemBuilder: (_, i) => _KidsGameCard(
              data: _kidsModes[i],
              onTap: () => onSelect(_kidsModes[i].mode),
            ),
          ),
          const SizedBox(height: 14),

          // Custom challenges card
          if (customCount > 0) ...[
            _CustomChallengesCard(
              count: customCount,
              onTap: () => onSelect(_GameMode.customQuestions),
            ),
            const SizedBox(height: 20),
          ],

          // Progress bar
          if (session.asked > 0) ...[
            _ProgressSection(
              correct: session.correct,
              asked: session.asked,
            ),
            const SizedBox(height: 12),
          ],

          // Bottom hint
          const Center(
            child: Text(
              'اضغط على أي تحدٍّ لتبدأ! 🎉',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Kids Game Card ───────────────────────────────────────────────────────────

class _KidsGameCard extends StatefulWidget {
  final _KidsModeData data;
  final VoidCallback onTap;
  const _KidsGameCard({required this.data, required this.onTap});

  @override
  State<_KidsGameCard> createState() => _KidsGameCardState();
}

class _KidsGameCardState extends State<_KidsGameCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: d.borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: d.accentColor.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji icon box with optional badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 58, height: 58,
                            decoration: BoxDecoration(
                              color: d.iconBg,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Text(
                                d.emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          if (d.stars == 3)
                            Positioned(
                              top: -4, right: -4,
                              child: Container(
                                width: 18, height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white, width: 2),
                                ),
                                child: const Center(
                                  child: Text(
                                    '★',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        d.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF134E4A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Stars row
                      Row(
                        children: List.generate(3, (i) {
                          return Text(
                            '⭐',
                            style: TextStyle(
                              fontSize: 12,
                              color: i < d.stars
                                  ? null
                                  : Colors.grey.withOpacity(0.3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              // Accent bottom bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: d.accentColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom Challenges Card ───────────────────────────────────────────────────

class _CustomChallengesCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _CustomChallengesCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('🎯', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تحديات المحفّظ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count أسئلة مخصصة من محفّظك',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Progress Section ─────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final int correct;
  final int asked;
  const _ProgressSection({required this.correct, required this.asked});

  @override
  Widget build(BuildContext context) {
    final pct = asked > 0 ? correct / asked : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'تقدّمك اليوم',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
            Text(
              '$correct / $asked ✅',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D9488),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
          ),
        ),
      ],
    );
  }
}
