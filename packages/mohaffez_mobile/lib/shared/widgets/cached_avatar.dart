// lib/shared/widgets/cached_avatar.dart - OPTIMIZED
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String semanticLabel;

  const CachedAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppThemeConstants.grey200,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                // ✅ ADDED: Progressive loading
                progressIndicatorBuilder: (context, url, progress) {
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.progress,
                      strokeWidth: 2,
                    ),
                  );
                },
                // ✅ ADDED: Memory cache settings
                memCacheWidth: (radius * 2 * MediaQuery.of(context).devicePixelRatio).round(),
                memCacheHeight: (radius * 2 * MediaQuery.of(context).devicePixelRatio).round(),
                errorWidget: (context, url, error) {
                  return Icon(
                    Icons.person,
                    size: radius,
                    color: AppThemeConstants.grey400,
                  );
                },
              ),
            )
          : Icon(
              Icons.person,
              size: radius,
              color: AppThemeConstants.grey400,
            ),
    );
  }
}
