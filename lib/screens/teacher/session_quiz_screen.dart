import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/challenge_questions_provider.dart';
import 'quiz/games/complete_ayah_game.dart';
import 'quiz/games/custom_questions_game.dart';
import 'quiz/games/name_surah_game.dart';
import 'quiz/games/order_ayahs_game.dart';
import 'quiz/games/tajweed_rule_game.dart';
import 'quiz/state/quiz_session_controller.dart';
import 'quiz/widgets/confetti_overlay.dart';
import 'quiz/widgets/quiz_design_tokens.dart';
import 'quiz/widgets/score_badge.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

/// Session quiz hub: one selector that routes to the active game.
///
/// All games share a single Riverpod-backed [QuizSessionController] so the
/// header score and streak persist as the student moves between games.
/// All correct-answer celebrations route through a single
/// [ConfettiOverlayController] hosted at this layer.
class SessionQuizScreen extends ConsumerStatefulWidget {
  final String? studentName;
  final String? mohaffezId;
  final String? studentId;

  const SessionQuizScreen({
    super.key,
    this.studentName,
    this.mohaffezId,
    this.studentId,
  });

  @override
  ConsumerState<SessionQuizScreen> createState() => _SessionQuizScreenState();
}

enum _GameMode { selector, completeAyah, nameSurah, tajweedRule, orderAyahs, customQuestions }

class _SessionQuizScreenState extends ConsumerState<SessionQuizScreen> {
  _GameMode _mode = _GameMode.selector;
  final ConfettiOverlayController _confetti = ConfettiOverlayController();

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: QuizDS.bg,
        body: ConfettiOverlay(
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
    );
  }

  Widget _buildHeader() {
    final session = ref.watch(quizSessionControllerProvider);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [QuizDS.teal700, QuizDS.teal600],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.white.withValues(alpha: 0.15),
                    borderRadius: QuizDS.r12,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppThemeConstants.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        color: AppThemeConstants.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.studentName != null)
                      Text(
                        widget.studentName!,
                        style: TextStyle(
                          color: AppThemeConstants.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              if (session.asked > 0)
                ScoreBadge(
                  correct: session.correct,
                  total: session.asked,
                  streak: session.streak,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _GameMode.selector:
        return _Selector(
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

// ─── Selector ────────────────────────────────────────────────────────────────

class _ModeCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;
  final _GameMode mode;
  const _ModeCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bg,
    required this.mode,
  });
}

class _Selector extends ConsumerWidget {
  final String? studentName;
  final String? mohaffezId;
  final String? studentId;
  final ValueChanged<_GameMode> onSelect;

  const _Selector({
    required this.studentName,
    required this.mohaffezId,
    required this.studentId,
    required this.onSelect,
  });

  static const _modes = <_ModeCardData>[
    _ModeCardData(
      icon: Icons.auto_stories_rounded,
      title: 'أكمل الآية',
      subtitle: 'أكمل الآية من أولها',
      color: QuizDS.teal500,
      bg: QuizDS.teal50,
      mode: _GameMode.completeAyah,
    ),
    _ModeCardData(
      icon: Icons.search_rounded,
      title: 'تحديد السورة',
      subtitle: 'من أي سورة هذه الآية؟',
      color: QuizDS.amber,
      bg: QuizDS.amberBg,
      mode: _GameMode.nameSurah,
    ),
    _ModeCardData(
      icon: Icons.menu_book_rounded,
      title: 'أحكام التجويد',
      subtitle: 'ما الحكم الظاهر في الآية؟',
      color: QuizDS.purple,
      bg: QuizDS.purpleBg,
      mode: _GameMode.tajweedRule,
    ),
    _ModeCardData(
      icon: Icons.sort_rounded,
      title: 'ترتيب الآيات',
      subtitle: 'رتب الآيات حسب ترتيبها',
      color: QuizDS.blue,
      bg: QuizDS.blueBg,
      mode: _GameMode.orderAyahs,
    ),
  ];

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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            studentName != null
                ? 'جلسة تحدي مع $studentName'
                : 'اختر نوع التحدي',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: QuizDS.text1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'تقييم تفاعلي يجعل الحفظ أكثر متعة',
            style: TextStyle(fontSize: 14, color: QuizDS.text2),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.92,
            ),
            itemCount: _modes.length,
            itemBuilder: (_, i) =>
                _ModeCard(data: _modes[i], onTap: () => onSelect(_modes[i].mode)),
          ),
          if (customCount > 0) ...[
            const SizedBox(height: 14),
            _CustomQuestionsCard(
              count: customCount,
              onTap: () => onSelect(_GameMode.customQuestions),
            ),
          ],
          if (session.asked > 0) ...[
            const SizedBox(height: 28),
            _SessionSummary(
              correct: session.correct,
              asked: session.asked,
              bestStreak: session.bestStreak,
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ModeCard extends StatefulWidget {
  final _ModeCardData data;
  final VoidCallback onTap;
  const _ModeCard({required this.data, required this.onTap});

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.data;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: AppThemeConstants.white,
            borderRadius: QuizDS.r20,
            border: Border.all(color: QuizDS.border),
            boxShadow: [
              BoxShadow(
                color: m.color.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: m.bg, borderRadius: QuizDS.r16),
                child: Icon(m.icon, color: m.color, size: 28),
              ),
              const Spacer(),
              Text(
                m.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: QuizDS.text1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                m.subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: QuizDS.text2,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomQuestionsCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _CustomQuestionsCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B7A75), Color(0xFF0E8278)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: QuizDS.r20,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B7A75).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppThemeConstants.white.withValues(alpha: 0.15),
                borderRadius: QuizDS.r16,
              ),
              child: const Icon(
                Icons.extension_rounded,
                color: AppThemeConstants.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تحديات المحفظ',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppThemeConstants.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count سؤال مخصص من محفظك',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppThemeConstants.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppThemeConstants.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  final int correct;
  final int asked;
  final int bestStreak;

  const _SessionSummary({
    required this.correct,
    required this.asked,
    required this.bestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final pct = asked > 0 ? (correct / asked * 100).round() : 0;
    final color = pct >= 70
        ? QuizDS.green
        : pct >= 40
            ? QuizDS.amber
            : QuizDS.red;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: QuizDS.r16,
        border: Border.all(color: QuizDS.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: QuizDS.teal50,
              borderRadius: QuizDS.r12,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: QuizDS.teal500,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نتيجة الجلسة',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: QuizDS.text1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$correct إجابة صحيحة من $asked سؤال',
                  style: const TextStyle(fontSize: 13, color: QuizDS.text2),
                ),
                if (bestStreak >= 2) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: QuizDS.amber,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'أطول سلسلة: $bestStreak',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: QuizDS.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
