import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/quran_quiz_bank.dart';
import '../../../../services/sound_service.dart';
import '../state/quiz_session_controller.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/quiz_buttons.dart';
import '../widgets/quiz_design_tokens.dart';
import '../widgets/result_banner.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

class TajweedRuleGame extends ConsumerStatefulWidget {
  final ConfettiOverlayController confetti;
  final VoidCallback onBackToMenu;

  const TajweedRuleGame({
    super.key,
    required this.confetti,
    required this.onBackToMenu,
  });

  @override
  ConsumerState<TajweedRuleGame> createState() => _TajweedRuleGameState();
}

class _TajweedRuleGameState extends ConsumerState<TajweedRuleGame> {
  QuizAyah? _ayah;
  String? _correctRule;
  List<String> _options = [];
  String? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNext();
    });
  }

  void _loadNext() {
    final used = ref.read(quizSessionControllerProvider).usedAyahIndices;
    final ctrl = ref.read(quizSessionControllerProvider.notifier);
    if (used.length >= QuranQuizBank.ayahs.length) ctrl.clearUsedAyahs();
    final a = QuranQuizBank.randomAyah(used: used);
    ctrl.markAyahUsed(QuranQuizBank.indexOf(a));

    final correctRule = a.tajweedRules.isNotEmpty
        ? a.tajweedRules[Random().nextInt(a.tajweedRules.length)]
        : QuranQuizBank.allTajweedRules.first;
    final wrong = QuranQuizBank.distractorsFor(correctRule);

    if (!mounted) return;
    setState(() {
      _ayah = a;
      _correctRule = correctRule;
      _options = [correctRule, ...wrong]..shuffle();
      _selected = null;
    });
  }

  void _select(String option) {
    if (_selected != null) return;
    final correct = option == _correctRule;
    SoundService.play(correct ? Sfx.clap : Sfx.tryAgain);
    final newStreak =
        ref.read(quizSessionControllerProvider.notifier).recordAnswer(correct);
    setState(() => _selected = option);
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
    final ayah = _ayah;
    if (ayah == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Ayah card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppThemeConstants.white,
              borderRadius: QuizDS.r20,
              border: Border.all(color: QuizDS.border),
              boxShadow: [
                BoxShadow(
                  color: QuizDS.purple.withValues(alpha: 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: QuizDS.purpleBg,
                    borderRadius: QuizDS.r12,
                    border: Border.all(
                        color: QuizDS.purple.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'ما الحكم التجويدي الظاهر في هذه الآية؟',
                    style: TextStyle(
                      fontSize: 13,
                      color: QuizDS.purple,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  ayah.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: QuizDS.text1,
                    height: 2.0,
                    fontFamily: 'Amiri',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'سورة ${ayah.surahName}  ·  الجزء ${ayah.juzNumber}',
                  style: const TextStyle(fontSize: 12, color: QuizDS.text3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_options.length, (i) => _buildOption(i)),
          const SizedBox(height: 8),
          if (_selected != null) ...[
            AnimatedResultBanner(correct: _selected == _correctRule),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TealButton(
                label: 'سؤال جديد',
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _loadNext,
              ),
            ),
            const SizedBox(height: 10),
          ],
          BackToMenuButton(onTap: widget.onBackToMenu),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption(int i) {
    final opt = _options[i];
    final isSelected = _selected == opt;
    final isAnswered = _selected != null;
    final isCorrect = opt == _correctRule;

    Color borderColor = QuizDS.border;
    Color bgColor = AppThemeConstants.white;
    Color textColor = QuizDS.text1;

    if (isAnswered) {
      if (isCorrect) {
        borderColor = QuizDS.green;
        bgColor = QuizDS.greenBg;
        textColor = QuizDS.green;
      } else if (isSelected) {
        borderColor = QuizDS.red;
        bgColor = QuizDS.red.withValues(alpha: 0.06);
        textColor = QuizDS.red;
      }
    } else if (isSelected) {
      borderColor = QuizDS.purple;
      bgColor = QuizDS.purpleBg;
      textColor = QuizDS.purple;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: isAnswered ? null : () => _select(opt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: QuizDS.r16,
            border: Border.all(
              color: borderColor,
              width: isAnswered && isCorrect ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAnswered && isCorrect
                      ? QuizDS.green
                      : isAnswered && isSelected
                          ? QuizDS.red
                          : QuizDS.teal50,
                ),
                child: isAnswered && isCorrect
                    ? const Icon(Icons.check, color: AppThemeConstants.white, size: 16)
                    : isAnswered && isSelected
                        ? const Icon(Icons.close, color: AppThemeConstants.white, size: 16)
                        : Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: QuizDS.teal500,
                              ),
                            ),
                          ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
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
