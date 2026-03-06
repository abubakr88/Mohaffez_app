import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme_constants.dart';

class SkeletonCard extends StatelessWidget {
  final double height;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 100,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: AppThemeConstants.spaceMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      itemCount: itemCount,
      // ✅ FIX: These two lines resolve the unbounded height crash.
      // Use when SkeletonList is inside a Column or non-scrollable parent.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, __) => SkeletonCard(height: itemHeight),
    );
  }
}
