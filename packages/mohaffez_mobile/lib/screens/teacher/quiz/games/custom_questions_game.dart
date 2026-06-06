import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../../services/sound_service.dart';
import '../state/quiz_session_controller.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/quiz_buttons.dart';
import '../widgets/quiz_design_tokens.dart';
import '../widgets/result_banner.dart';

class CustomQuestionsGame extends ConsumerStatefulWidget {
  final String mohaffezId;
  final String studentId;
  final ConfettiOverlayController confetti;
  final VoidCallback onBackToMenu;

  const CustomQuestionsGame({
    super.key,
    required this.mohaffezId,
    required this.studentId,
    required this.confetti,
    required this.onBackToMenu,
  });

  @override
  ConsumerState<CustomQuestionsGame> createState() =>
      _CustomQuestionsGameState();
}

class _CustomQuestionsGameState extends ConsumerState<CustomQuestionsGame> {
  int _index = 0;
  bool _revealed = false;
  bool? _marked;
  bool _completionCelebrated = false;

  void _restart() {
    setState(() {
      _index = 0;
      _revealed = false;
      _marked = null;
      _completionCelebrated = false;
    });
  }

  void _next() {
    setState(() {
      _index++;
      _revealed = false;
      _marked = null;
    });
  }

  void _mark(bool correct) {
    SoundService.play(correct ? Sfx.clap : Sfx.tryAgain);
    final newStreak =
        ref.read(quizSessionControllerProvider.notifier).recordAnswer(correct);
    setState(() => _marked = correct);
    if (correct) {
      widget.confetti.celebrate(
        intensity: newStreak >= 3
            ? ConfettiIntensity.fireworks
            : ConfettiIntensity.normal,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = (
      mohaffezId: widget.mohaffezId,
      studentId: widget.studentId,
    );
    final questionsAsync = ref.watch(studentChallengesProvider(params));

    return questionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('تعذّر تحميل الأسئلة. يرجى المحاولة مرة أخرى',
              style: TextStyle(color: QuizDS.red)),
        ),
      ),
      data: (all) {
        final active = all.where((q) => q.isActive).toList();
        if (active.isEmpty) return _emptyState();
        if (_index >= active.length) {
          if (!_completionCelebrated) {
            _completionCelebrated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              widget.confetti.celebrate(
                intensity: ConfettiIntensity.fireworks,
              );
            });
          }
          return _completionState(active.length);
        }

        return _buildQuestionView(active[_index], active.length);
      },
    );
  }

  Widget _emptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.extension_off_rounded,
              size: 64, color: QuizDS.text3),
          const SizedBox(height: 16),
          const Text(
            'لا توجد أسئلة مفعّلة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: QuizDS.text1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'فعّل بعض الأسئلة من شاشة إدارة التحديات',
            style: TextStyle(fontSize: 14, color: QuizDS.text2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          BackToMenuButton(onTap: widget.onBackToMenu),
        ],
      ),
    );
  }

  Widget _completionState(int total) {
    final session = ref.watch(quizSessionControllerProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [QuizDS.teal600, QuizDS.teal500],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_rounded,
                size: 48, color: AppThemeConstants.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'انتهت جميع الأسئلة! 🎉',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: QuizDS.text1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${session.correct} إجابة صحيحة من ${session.asked} سؤال',
            style: const TextStyle(fontSize: 15, color: QuizDS.text2),
          ),
          if (session.bestStreak >= 3) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: QuizDS.amberBg,
                borderRadius: QuizDS.r12,
                border: Border.all(color: QuizDS.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: QuizDS.amber, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'أطول سلسلة: ${session.bestStreak}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: QuizDS.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: TealButton(
              label: 'إعادة التحديات',
              icon: Icons.replay_rounded,
              onTap: _restart,
            ),
          ),
          const SizedBox(height: 12),
          BackToMenuButton(onTap: widget.onBackToMenu),
        ],
      ),
    );
  }

  Widget _buildQuestionView(ChallengeQuestion q, int total) {
    final typeColor = _typeColor(q.type);
    final typeBg = _typeBg(q.type);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress
          Row(
            children: [
              Text(
                'سؤال ${_index + 1} من $total',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: QuizDS.text3,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: QuizDS.r12,
                  child: LinearProgressIndicator(
                    value: (_index + 1) / total,
                    backgroundColor: QuizDS.border,
                    color: QuizDS.teal500,
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Question card
          GestureDetector(
            onTap: _revealed
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    setState(() => _revealed = true);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppThemeConstants.white,
                borderRadius: QuizDS.r20,
                border: Border.all(
                  color: _marked == null
                      ? (_revealed ? typeColor.withValues(alpha: 0.4) : QuizDS.border)
                      : _marked!
                          ? QuizDS.green.withValues(alpha: 0.5)
                          : QuizDS.red.withValues(alpha: 0.5),
                  width: _marked != null ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Type + difficulty badges
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      InfoBadge(
                        label: ChallengeTypeX(q.type).label,
                        color: typeColor,
                        bg: typeBg,
                      ),
                      InfoBadge(
                        label: _diffLabel(q.difficulty),
                        color: _diffColor(q.difficulty),
                        bg: _diffBg(q.difficulty),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    q.question,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: QuizDS.text1,
                      height: 1.6,
                    ),
                  ),
                  if (_revealed) ...[
                    if (q.hint != null && q.hint!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _hintBox(q.hint!),
                    ],
                    if (q.answer != null && q.answer!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _answerBox(q.answer!),
                    ],
                  ] else ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_rounded,
                            size: 14,
                            color: typeColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text(
                          'اضغط للكشف',
                          style: TextStyle(
                            fontSize: 13,
                            color: typeColor.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Result + nav
          if (_marked != null) ...[
            AnimatedResultBanner(correct: _marked!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TealButton(
                label: _index + 1 < total ? 'السؤال التالي' : 'إنهاء التحديات',
                icon: _index + 1 < total
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.check_circle_outline_rounded,
                onTap: _next,
              ),
            ),
          ] else if (_revealed) ...[
            Row(
              children: [
                Expanded(
                  child: OutlineActionButton(
                    label: 'خطأ',
                    icon: Icons.close_rounded,
                    color: QuizDS.red,
                    onTap: () => _mark(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlineActionButton(
                    label: 'صحيح',
                    icon: Icons.check_rounded,
                    color: QuizDS.green,
                    onTap: () => _mark(true),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          BackToMenuButton(onTap: widget.onBackToMenu),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _hintBox(String hint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QuizDS.amberBg,
        borderRadius: QuizDS.r12,
        border: Border.all(color: QuizDS.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: QuizDS.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(
                fontSize: 14,
                color: QuizDS.text1,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerBox(String answer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QuizDS.teal50,
        borderRadius: QuizDS.r12,
        border: Border.all(color: QuizDS.teal100),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, size: 16, color: QuizDS.teal500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 14,
                color: QuizDS.teal700,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(ChallengeType t) => switch (t) {
        ChallengeType.completeAyah => QuizDS.teal500,
        ChallengeType.nameSurah => QuizDS.amber,
        ChallengeType.tajweedRule => QuizDS.purple,
        ChallengeType.wordMeaning => QuizDS.blue,
        ChallengeType.openQuestion => QuizDS.green,
      };

  Color _typeBg(ChallengeType t) => switch (t) {
        ChallengeType.completeAyah => QuizDS.teal50,
        ChallengeType.nameSurah => QuizDS.amberBg,
        ChallengeType.tajweedRule => QuizDS.purpleBg,
        ChallengeType.wordMeaning => QuizDS.blueBg,
        ChallengeType.openQuestion => QuizDS.greenBg,
      };

  Color _diffColor(String d) => switch (d) {
        'easy' => QuizDS.green,
        'hard' => QuizDS.red,
        _ => QuizDS.amber,
      };

  Color _diffBg(String d) => switch (d) {
        'easy' => QuizDS.greenBg,
        'hard' => QuizDS.red.withValues(alpha: 0.08),
        _ => QuizDS.amberBg,
      };

  String _diffLabel(String d) => switch (d) {
        'easy' => 'سهل',
        'hard' => 'صعب',
        _ => 'متوسط',
      };
}
