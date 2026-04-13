import 'package:flutter/material.dart';
import '../theme/app_theme_constants.dart';

/// Consistent empty state widget for admin list screens.
///
/// Shows a large icon, a message, and an optional subtitle.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppThemeConstants.icon3xl,
              color: AppThemeConstants.textSecondary,
            ),
            const SizedBox(height: AppThemeConstants.spaceMd),
            Text(
              message,
              style: const TextStyle(
                color: AppThemeConstants.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppThemeConstants.spaceSm),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppThemeConstants.textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
