import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/quran_quiz_bank.dart';
import '../../../../services/sound_service.dart';
import '../state/quiz_session_controller.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/quiz_buttons.dart';
import '../widgets/quiz_design_tokens.dart';
import '../widgets/reveal_game_scaffold.dart';

class NameSurahGame extends ConsumerStatefulWidget {
  final ConfettiOverlayController confetti;
  final VoidCallback onBackToMenu;

  const NameSurahGame({
    super.key,
    required this.confetti,
    required this.onBackToMenu,
  });

  @override
  ConsumerState<NameSurahGame> createState() => _NameSurahGameState();
}

class _NameSurahGameState extends ConsumerState<NameSurahGame> {
  QuizAyah? _ayah;
  bool _revealed = false;
  bool? _marked;

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
    if (!mounted) return;
    setState(() {
      _ayah = a;
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
    final ayah = _ayah;
    if (ayah == null) return const SizedBox.shrink();
    return RevealGameScaffold(
      revealed: _revealed,
      markedCorrect: _marked,
      accentColor: QuizDS.amber,
      onReveal: () => setState(() => _revealed = true),
      onMark: _mark,
      onNext: _loadNext,
      onBackToMenu: widget.onBackToMenu,
      questionWidget: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: QuizDS.amberBg,
              borderRadius: QuizDS.r12,
              border: Border.all(color: QuizDS.amber.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'من أي سورة هذه الآية؟',
              style: TextStyle(
                fontSize: 13,
                color: QuizDS.amber,
                fontWeight: FontWeight.w600,
              ),
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
        ],
      ),
      revealWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'سورة ${ayah.surahName}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: QuizDS.teal500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoBadge(
                label: 'السورة رقم ${ayah.surahNumber}',
                color: QuizDS.amber,
                bg: QuizDS.amberBg,
              ),
              InfoBadge(
                label: 'الجزء ${ayah.juzNumber}',
                color: QuizDS.teal500,
                bg: QuizDS.teal50,
              ),
              InfoBadge(
                label: 'الآية ${ayah.ayahNumber}',
                color: QuizDS.purple,
                bg: QuizDS.purpleBg,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
