import 'package:flutter/material.dart';
import '../colors.dart';
import '../typography.dart';

class DSAvatar extends StatelessWidget {
  const DSAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40.0,
    this.color,
  });

  final String? imageUrl;
  final String? name;
  final double size;
  final Color? color;

  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return parts[0][0];
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? DSColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size / 2),
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: Text(
                _initials,
                style: DSText.resolve(
                  context,
                  size: size * 0.35,
                  weight: FontWeight.w600,
                  color: bg,
                ),
              ),
            )
          : null,
    );
  }
}
