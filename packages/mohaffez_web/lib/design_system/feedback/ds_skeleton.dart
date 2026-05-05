import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';

class DSSkeleton extends StatefulWidget {
  const DSSkeleton({
    super.key,
    this.width,
    this.height = 16.0,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadiusGeometry? borderRadius;

  @override
  State<DSSkeleton> createState() => _DSSkeletonState();
}

class _DSSkeletonState extends State<DSSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: DSColors.border.withValues(alpha: _anim.value),
          borderRadius: widget.borderRadius ?? DSRadius.smAll,
        ),
      ),
    );
  }
}

class DSSkeletonCard extends StatelessWidget {
  const DSSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DSSpacing.xl),
      decoration: const BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.lgAll,
        border: Border.fromBorderSide(BorderSide(color: DSColors.border)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DSSkeleton(width: 80, height: 12),
          SizedBox(height: DSSpacing.sm),
          DSSkeleton(width: 140, height: 28),
          SizedBox(height: DSSpacing.sm),
          DSSkeleton(width: 100, height: 12),
        ],
      ),
    );
  }
}
