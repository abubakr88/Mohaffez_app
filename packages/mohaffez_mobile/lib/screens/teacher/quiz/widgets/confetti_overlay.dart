import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'quiz_design_tokens.dart';

/// Wraps a child and overlays a celebratory confetti burst that the parent
/// triggers via [ConfettiOverlayController.celebrate].
///
/// Two intensities:
///   - [ConfettiIntensity.normal]   single small burst (correct answer)
///   - [ConfettiIntensity.fireworks] double burst from both top corners
///     (used for streaks of 3+ and end-of-quiz)
class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final ConfettiOverlayController controller;

  const ConfettiOverlay({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> {
  late final ConfettiController _center =
      ConfettiController(duration: const Duration(milliseconds: 700));
  late final ConfettiController _left =
      ConfettiController(duration: const Duration(seconds: 1));
  late final ConfettiController _right =
      ConfettiController(duration: const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    widget.controller._attach(_handleCelebrate);
  }

  void _handleCelebrate(ConfettiIntensity intensity) {
    if (!mounted) return;
    if (intensity == ConfettiIntensity.fireworks) {
      _left.play();
      _right.play();
    } else {
      _center.play();
    }
  }

  @override
  void dispose() {
    widget.controller._detach();
    _center.dispose();
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Center burst — for ordinary correct answers
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _center,
            blastDirection: pi / 2, // straight down
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 18,
            maxBlastForce: 18,
            minBlastForce: 8,
            gravity: 0.35,
            shouldLoop: false,
            colors: QuizDS.confettiColors,
          ),
        ),
        // Left fireworks
        Align(
          alignment: Alignment.topLeft,
          child: ConfettiWidget(
            confettiController: _left,
            blastDirection: pi / 4, // toward bottom-right
            emissionFrequency: 0.04,
            numberOfParticles: 25,
            maxBlastForce: 24,
            minBlastForce: 12,
            gravity: 0.3,
            shouldLoop: false,
            colors: QuizDS.confettiColors,
          ),
        ),
        // Right fireworks
        Align(
          alignment: Alignment.topRight,
          child: ConfettiWidget(
            confettiController: _right,
            blastDirection: 3 * pi / 4, // toward bottom-left
            emissionFrequency: 0.04,
            numberOfParticles: 25,
            maxBlastForce: 24,
            minBlastForce: 12,
            gravity: 0.3,
            shouldLoop: false,
            colors: QuizDS.confettiColors,
          ),
        ),
      ],
    );
  }
}

enum ConfettiIntensity { normal, fireworks }

class ConfettiOverlayController {
  void Function(ConfettiIntensity)? _listener;

  void _attach(void Function(ConfettiIntensity) l) => _listener = l;
  void _detach() => _listener = null;

  void celebrate({ConfettiIntensity intensity = ConfettiIntensity.normal}) {
    _listener?.call(intensity);
  }
}
