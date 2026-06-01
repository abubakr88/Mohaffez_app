import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/quran_quiz_bank.dart';
import '../../../../services/sound_service.dart';
import '../state/quiz_session_controller.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/quiz_design_tokens.dart';
import '../widgets/reveal_game_scaffold.dart';

class CompleteAyahGame extends ConsumerStatefulWidget {
  final ConfettiOverlayController confetti;
  final VoidCallback onBackToMenu;

  const CompleteAyahGame({
    super.key,
    required this.confetti,
    required this.onBackToMenu,
  });

  @override
  ConsumerState<CompleteAyahGame> createState() => _CompleteAyahGameState();
}

class _CompleteAyahGameState extends ConsumerState<CompleteAyahGame> {
  QuizAyah? _ayah;
  bool _revealed = false;
  bool? _marked;

  @override
  void initState() {
    super.initState();
    // Defer provider mutation until after the first frame — modifying a
    // StateNotifier inside initState throws StateNotifierListenerError.
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
      accentColor: QuizDS.teal500,
      onReveal: () => setState(() => _revealed = true),
      onMark: _mark,
      onNext: _loadNext,
      onBackToMenu: widget.onBackToMenu,
      questionWidget: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: QuizDS.teal50,
              borderRadius: QuizDS.r12,
              border: Border.all(color: QuizDS.teal100),
            ),
            child: Text(
              'الجزء ${ayah.juzNumber}',
              style: const TextStyle(
                fontSize: 13,
                color: QuizDS.teal500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${ayah.textStart}...',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: QuizDS.text1,
              height: 1.8,
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'أكمل الآية شفهيًا',
            style: TextStyle(fontSize: 14, color: QuizDS.text2),
          ),
        ],
      ),
      revealWidget: Column(
        children: [
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: QuizDS.teal50,
              borderRadius: QuizDS.r12,
              border: Border.all(color: QuizDS.teal100),
            ),
            child: Text(
              'سورة ${ayah.surahName}  ·  الآية ${ayah.ayahNumber}  ·  الجزء ${ayah.juzNumber}',
              style: const TextStyle(
                fontSize: 13,
                color: QuizDS.teal600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
