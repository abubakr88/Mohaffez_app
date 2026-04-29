import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Full-screen background for all quiz screens.
///
/// Renders a white→pale-mint gradient base, a tiled 8-point Islamic star
/// outline pattern (8 % opacity, teal), a dot grid (5 % opacity, teal),
/// and soft white corner vignettes — all via CustomPainter so no asset
/// file is needed and it scales to any screen size.
class QuizBackground extends StatelessWidget {
  final Widget child;

  const QuizBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _IslamicPatternPainter()),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _IslamicPatternPainter extends CustomPainter {
  static const _teal = Color(0xFF0D9488);
  static const _mint = Color(0xFFF0FDFA);
  static const _gridSize = 80.0;
  static const _dotSpacing = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGradient(canvas, size);
    _drawStarGrid(canvas, size);
    _drawDotGrid(canvas, size);
    _drawCornerVignettes(canvas, size);
  }

  void _drawGradient(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, _mint],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _drawStarGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _teal.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;

    final cols = (size.width / _gridSize).ceil() + 2;
    final rows = (size.height / _gridSize).ceil() + 2;
    const r = _gridSize * 0.40;

    for (var row = -1; row < rows; row++) {
      for (var col = -1; col < cols; col++) {
        final cx = col * _gridSize + _gridSize / 2;
        final cy = row * _gridSize + _gridSize / 2;
        canvas.drawPath(_islamicStar8(Offset(cx, cy), r), paint);
      }
    }
  }

  /// Builds a traditional 8-point Islamic star path around [center].
  ///
  /// Outer points at [outerR]; inner vertices at [outerR * 0.42] offset by
  /// half an angular step, giving the classic sharp-pointed look.
  Path _islamicStar8(Offset center, double outerR) {
    final innerR = outerR * 0.42;
    const n = 8;
    const step = math.pi / n;
    final path = Path();

    for (var i = 0; i < n * 2; i++) {
      final angle = i * step - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  void _drawDotGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _teal.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final cols = (size.width / _dotSpacing).ceil() + 1;
    final rows = (size.height / _dotSpacing).ceil() + 1;

    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        canvas.drawCircle(
          Offset(c * _dotSpacing, r * _dotSpacing),
          0.5,
          paint,
        );
      }
    }
  }

  void _drawCornerVignettes(Canvas canvas, Size size) {
    final vigR = size.width * 0.60;
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];

    for (final corner in corners) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: corner, radius: vigR));
      canvas.drawCircle(corner, vigR, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
