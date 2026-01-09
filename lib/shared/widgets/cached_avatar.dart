import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? semanticLabel; // NEW

  const CachedAvatar({
    super.key,
    this.imageUrl,
    this.radius = 45,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
    this.iconColor,
    this.semanticLabel, // NEW
  });

  @override
  Widget build(BuildContext context) {
    // Fallback with semantic label
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Semantics(
        label: semanticLabel ?? 'صورة المستخدم',
        image: true,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.grey.shade200,
          child: Icon(
            fallbackIcon,
            size: radius * 0.8,
            color: iconColor ?? Colors.grey.shade600,
          ),
        ),
      );
    }

    return Semantics(
      label: semanticLabel ?? 'صورة المستخدم',
      image: true,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
          backgroundColor: backgroundColor,
        ),
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[300],
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.grey.shade200,
          child: Icon(
            fallbackIcon,
            size: radius * 0.8,
            color: iconColor ?? Colors.grey.shade600,
          ),
        ),
        maxWidthDiskCache: (radius * 4).toInt(),
        maxHeightDiskCache: (radius * 4).toInt(),
        memCacheWidth: (radius * 4).toInt(),
        memCacheHeight: (radius * 4).toInt(),
      ),
    );
  }
}

/// A rectangular cached image with rounded corners (for larger images)
class CachedRectImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final Widget? errorWidget;

  const CachedRectImage({
    super.key,
    this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: width,
            height: height,
            color: Colors.grey[300],
          ),
        ),
        errorWidget: (context, url, error) =>
            errorWidget ?? _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.broken_image,
        size: width * 0.4,
        color: Colors.grey.shade400,
      ),
    );
  }
}
