import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

class QuranMistakeCluster {
  const QuranMistakeCluster({
    required this.mistakes,
    required this.xPosition,
    required this.yPosition,
  });

  final List<QuranMistake> mistakes;
  final double xPosition;
  final double yPosition;
}

List<QuranMistakeCluster> clusterQuranMistakes(
  List<QuranMistake> mistakes, {
  double threshold = 0.05,
}) {
  final clusters = <_MutableMistakeCluster>[];
  for (final mistake in mistakes) {
    _MutableMistakeCluster? nearest;
    var nearestDistanceSquared = double.infinity;
    for (final cluster in clusters) {
      final dx = cluster.xPosition - mistake.xPosition;
      final dy = cluster.yPosition - mistake.yPosition;
      final distanceSquared = (dx * dx) + (dy * dy);
      if (distanceSquared <= threshold * threshold &&
          distanceSquared < nearestDistanceSquared) {
        nearest = cluster;
        nearestDistanceSquared = distanceSquared;
      }
    }
    if (nearest == null) {
      clusters.add(_MutableMistakeCluster(mistake));
    } else {
      nearest.add(mistake);
    }
  }
  return clusters.map((cluster) => cluster.freeze()).toList();
}

class _MutableMistakeCluster {
  _MutableMistakeCluster(QuranMistake mistake)
      : mistakes = <QuranMistake>[mistake],
        xPosition = mistake.xPosition,
        yPosition = mistake.yPosition;

  final List<QuranMistake> mistakes;
  double xPosition;
  double yPosition;

  void add(QuranMistake mistake) {
    final previousCount = mistakes.length;
    mistakes.add(mistake);
    xPosition =
        ((xPosition * previousCount) + mistake.xPosition) / mistakes.length;
    yPosition =
        ((yPosition * previousCount) + mistake.yPosition) / mistakes.length;
  }

  QuranMistakeCluster freeze() => QuranMistakeCluster(
        mistakes: List<QuranMistake>.unmodifiable(mistakes),
        xPosition: xPosition,
        yPosition: yPosition,
      );
}

class QuranMistakePainter extends CustomPainter {
  final List<QuranMistake> mistakes;

  QuranMistakePainter({required this.mistakes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final cluster in clusterQuranMistakes(mistakes)) {
      final primaryMistake = cluster.mistakes.first;
      final isGroup = cluster.mistakes.length > 1;
      final dx = cluster.xPosition.clamp(0.0, 1.0) * size.width;
      final dy = cluster.yPosition.clamp(0.0, 1.0) * size.height;
      final radius = isGroup ? 18.0 : 16.0;

      final fillPaint = Paint()
        ..color = (isGroup
                ? AppThemeConstants.primary
                : getMistakeColor(primaryMistake.type))
            .withValues(alpha: 0.88)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = AppThemeConstants.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(dx, dy), radius, fillPaint);
      canvas.drawCircle(Offset(dx, dy), radius, strokePaint);

      if (isGroup) {
        final countPainter = TextPainter(
          text: TextSpan(
            text: '${cluster.mistakes.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        countPainter.paint(
          canvas,
          Offset(
            dx - (countPainter.width / 2),
            dy - (countPainter.height / 2),
          ),
        );
      }

      if (cluster.mistakes.any((mistake) => mistake.hasComment)) {
        final commentPaint = Paint()
          ..color = AppThemeConstants.accentBlueDark
          ..style = PaintingStyle.fill;
        final commentStroke = Paint()
          ..color = AppThemeConstants.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final commentOffset = Offset(dx + 12, dy - 12);
        canvas.drawCircle(commentOffset, 7.5, commentPaint);
        canvas.drawCircle(commentOffset, 7.5, commentStroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant QuranMistakePainter oldDelegate) {
    return oldDelegate.mistakes != mistakes;
  }
}
