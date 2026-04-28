import 'package:flutter/material.dart';

import 'quiz_design_tokens.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

/// Header pill showing live score: stars for streak + correct/total counter.
///
/// Streak >= 3 sparkles (gold flame), >= 5 fireworks (animated pulse).
class ScoreBadge extends StatefulWidget {
  final int correct;
  final int total;
  final int streak;

  const ScoreBadge({
    super.key,
    required this.correct,
    required this.total,
    required this.streak,
  });

  @override
  State<ScoreBadge> createState() => _ScoreBadgeState();
}

class _ScoreBadgeState extends State<ScoreBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _maybeStartPulse();
  }

  @override
  void didUpdateWidget(covariant ScoreBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeStartPulse();
  }

  void _maybeStartPulse() {
    if (widget.streak >= 5) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasStreak = widget.streak >= 2;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final pulseFactor = 1.0 + (_pulse.value * 0.06);
        return Transform.scale(
          scale: pulseFactor,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppThemeConstants.white.withValues(alpha: 0.2),
              borderRadius: QuizDS.r12,
              border: Border.all(
                color: AppThemeConstants.white.withValues(alpha: 0.3 + (_pulse.value * 0.4)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasStreak) ...[
                  Icon(
                    widget.streak >= 5
                        ? Icons.local_fire_department_rounded
                        : Icons.star_rounded,
                    size: 16,
                    color: widget.streak >= 5
                        ? const Color(0xFFFF8A65)
                        : const Color(0xFFFFD54F),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.streak}',
                    style: const TextStyle(
                      color: AppThemeConstants.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppThemeConstants.white.withValues(alpha: 0.3),
                  ),
                ],
                Text(
                  '${widget.correct} / ${widget.total}',
                  style: const TextStyle(
                    color: AppThemeConstants.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
