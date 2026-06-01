import 'package:flutter/material.dart';

import 'quiz_design_tokens.dart';

/// Animated success/failure banner.
///
/// On correct: scales in with a soft bounce and shows an encouraging Arabic
/// phrase from a small rotating set (so kids don't see the same line twice
/// in a row). On wrong: gentle slide-in with a softer message — never
/// scolding, since this is for children.
class AnimatedResultBanner extends StatefulWidget {
  final bool correct;
  final String? customMessage;

  const AnimatedResultBanner({
    super.key,
    required this.correct,
    this.customMessage,
  });

  @override
  State<AnimatedResultBanner> createState() => _AnimatedResultBannerState();
}

class _AnimatedResultBannerState extends State<AnimatedResultBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  // Rotating positive messages — picked pseudo-randomly per build via hashCode.
  static const _correctMessages = [
    'أحسنت! ✨',
    'ممتاز! 🌟',
    'رائع! 👏',
    'بارك الله فيك! 💚',
    'إجابة موفقة! ⭐',
  ];
  static const _wrongMessages = [
    'لا بأس، حاول مرة أخرى',
    'قريب جدًا! حاول ثانية',
    'ركّز قليلًا وأعد المحاولة',
  ];

  String get _message {
    if (widget.customMessage != null) return widget.customMessage!;
    final pool = widget.correct ? _correctMessages : _wrongMessages;
    return pool[DateTime.now().millisecondsSinceEpoch % pool.length];
  }

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scale = CurvedAnimation(parent: _ac, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.correct ? QuizDS.green : QuizDS.red;
    final bg    = widget.correct ? QuizDS.greenBg : QuizDS.redBg;
    final icon  = widget.correct
        ? Icons.check_circle_rounded
        : Icons.refresh_rounded;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: Tween(begin: 0.6, end: 1.0).animate(_scale),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: QuizDS.r16,
            border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _message,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
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
