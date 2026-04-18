import 'package:flutter/material.dart';
import '../theme/app_theme_constants.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? iconColor;
  final bool animated;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    this.title = 'لا توجد بيانات',
    this.message = 'لا يوجد محتوى لعرضه حالياً',
    this.action,
    this.iconColor,
    this.animated = true,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = Icon(
      icon,
      size: iconSize,
      color: iconColor ?? Colors.grey.shade300,
      semanticLabel: title, // Accessibility
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ⭐ FIXED: Animated icon with safe scale and fade
            if (animated)
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack, // ⭐ Changed from elasticOut
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: (0.5 + (0.5 * value))
                        .clamp(0.5, 1.0), // ⭐ Safe scale range
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0), // ⭐ Safe opacity
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? AppThemeConstants.primary,
                ),
              )
            else
              iconWidget,

            const SizedBox(height: 16),

            // Title with fade animation
            TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: animated ? 600 : 0),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeIn,
              builder: (context, value, child) {
                return Opacity(
                  opacity:
                      animated ? value.clamp(0.0, 1.0) : 1.0, // ⭐ Safe opacity
                  child: child,
                );
              },
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Message with delay
            if (message != null) ...[
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: animated ? 800 : 0),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeIn,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: animated
                        ? value.clamp(0.0, 1.0)
                        : 1.0, // ⭐ Safe opacity
                    child: child,
                  );
                },
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],

            // Action button with slide animation
            if (action != null) ...[
              const SizedBox(height: 24),
              TweenAnimationBuilder<Offset>(
                duration: Duration(milliseconds: animated ? 1000 : 0),
                tween: Tween(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: animated ? value * 20 : Offset.zero,
                    child: Opacity(
                      opacity: animated
                          ? (1 - value.dy / 0.3).clamp(0.0, 1.0)
                          : 1.0, // ⭐ Safe opacity
                      child: child,
                    ),
                  );
                },
                child: action,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact empty state for smaller spaces (like inside cards)
class CompactEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? iconColor;

  const CompactEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: iconColor ?? Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state with illustration (for main screens)
class IllustratedEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final Widget? action;
  final Widget illustration;

  const IllustratedEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    required this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ⭐ FIXED: Animated illustration with safe values
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: (0.5 + (0.5 * value)).clamp(0.5, 1.0), // ⭐ Safe scale
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0), // ⭐ Safe opacity
                    child: child,
                  ),
                );
              },
              child: illustration,
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),

            // Action
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
