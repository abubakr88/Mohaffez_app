import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

/// Main error display widget with multiple factory constructors
class ErrorDisplay extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;
  final Color? iconColor;
  final Widget? customAction;

  const ErrorDisplay({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.iconColor,
    this.customAction,
  });

  // ===== FACTORY CONSTRUCTORS FOR COMMON ERRORS =====

  /// Network error (no internet connection)
  factory ErrorDisplay.network({VoidCallback? onRetry}) {
    return ErrorDisplay(
      title: 'لا يوجد اتصال بالإنترنت',
      message: 'يرجى التحقق من الاتصال والمحاولة مرة أخرى',
      icon: Icons.wifi_off,
      iconColor: AppThemeConstants.warning,
      onRetry: onRetry,
    );
  }

  /// Permission error (location, camera, etc.)
  factory ErrorDisplay.permission({
    required String permissionName,
    VoidCallback? onRetry,
  }) {
    return ErrorDisplay(
      title: 'الإذن مطلوب',
      message: 'يرجى منح إذن $permissionName للمتابعة',
      icon: Icons.lock_outline,
      iconColor: AppThemeConstants.accentRed,
      onRetry: onRetry,
    );
  }

  /// Data loading error
  factory ErrorDisplay.dataLoad({VoidCallback? onRetry}) {
    return ErrorDisplay(
      title: 'فشل تحميل البيانات',
      message: 'حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى',
      icon: Icons.error_outline,
      iconColor: AppThemeConstants.error,
      onRetry: onRetry,
    );
  }

  /// Not found error (no data available)
  factory ErrorDisplay.notFound({
    String? itemName,
    VoidCallback? onRetry,
  }) {
    return ErrorDisplay(
      title: 'لم يتم العثور على ${itemName ?? "البيانات"}',
      message: 'العنصر المطلوب غير موجود أو تم حذفه',
      icon: Icons.search_off,
      iconColor: AppThemeConstants.grey600,
      onRetry: onRetry,
    );
  }

  /// Timeout error
  factory ErrorDisplay.timeout({VoidCallback? onRetry}) {
    return ErrorDisplay(
      title: 'انتهت مهلة الطلب',
      message: 'استغرق الطلب وقتاً طويلاً. يرجى المحاولة مرة أخرى',
      icon: Icons.timer_off,
      iconColor: AppThemeConstants.warning,
      onRetry: onRetry,
    );
  }

  /// Server error
  factory ErrorDisplay.server({VoidCallback? onRetry}) {
    return ErrorDisplay(
      title: 'خطأ في الخادم',
      message: 'حدث خطأ في الخادم. يرجى المحاولة لاحقاً',
      icon: Icons.cloud_off,
      iconColor: AppThemeConstants.error,
      onRetry: onRetry,
    );
  }

  /// Location services disabled
  factory ErrorDisplay.locationDisabled({VoidCallback? onRetry}) {
    return ErrorDisplay(
      title: 'خدمات الموقع معطلة',
      message: 'يرجى تفعيل خدمات الموقع من الإعدادات',
      icon: Icons.location_off,
      iconColor: AppThemeConstants.warning,
      onRetry: onRetry,
    );
  }

  /// Authentication error
  factory ErrorDisplay.authentication({VoidCallback? onRetry}) {
    return ErrorDisplay(
      title: 'خطأ في المصادقة',
      message: 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى',
      icon: Icons.lock_clock,
      iconColor: AppThemeConstants.accentRed,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build semantic announcement
    final semanticLabel = '$title. ${message ?? ''}'.trim();
    
    // Announce error to screen reader after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AccessibilityUtils.isScreenReaderEnabled(context)) {
        AccessibilityUtils.announce(context, semanticLabel);
      }
    });

    return Semantics(
      liveRegion: true,
      label: semanticLabel,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ FIXED: Animated icon with safe scale and opacity
              ExcludeSemantics(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 680),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.elasticOut,
                  builder: (context, animationValue, child) {
                    // Separate scale and opacity calculations
                    final scaleValue = animationValue;
                    final opacityValue = animationValue.clamp(0.0, 1.0);
                    
                    return Transform.scale(
                      scale: scaleValue,
                      child: Opacity(
                        opacity: opacityValue, // ✅ FIXED: Safe opacity
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    icon,
                    size: 64,
                    color: iconColor ?? AppThemeConstants.accentRed,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title (excluded from semantics as it's in main label)
              ExcludeSemantics(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppThemeConstants.grey700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Message (excluded from semantics as it's in main label)
              if (message != null) ...[
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: Text(
                    message!, // ✅ FIXED: Non-null assertion
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppThemeConstants.grey600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              // Retry button or custom action with semantic hint
              if (onRetry != null || customAction != null) ...[
                const SizedBox(height: 24),
                customAction ??
                    Semantics(
                      button: true,
                      label: 'إعادة المحاولة',
                      hint: 'اضغط مرتين لإعادة تحميل البيانات',
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline error banner for displaying errors within content
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Define local variables instead of undefined ones
    final bgColor = backgroundColor ?? AppThemeConstants.errorLight;
    final txtColor = textColor ?? AppThemeConstants.error;

    return Semantics(
      liveRegion: true,
      label: 'تنبيه: $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: AppThemeConstants.accentRed),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                icon ?? Icons.error_outline,
                color: txtColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: txtColor,
                  fontSize: 13,
                ),
              ),
            ),
            if (onRetry != null)
              Semantics(
                button: true,
                label: 'إعادة المحاولة',
                child: TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: txtColor,
                  ),
                  child: const Text('إعادة المحاولة'),
                ),
              ),
            if (onDismiss != null)
              Semantics(
                button: true,
                label: 'إغلاق التنبيه',
                child: IconButton(
                  icon: Icon(Icons.close, size: 18, color: txtColor),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Warning banner (less severe than error)
class WarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onDismiss;

  const WarningBanner({
    super.key,
    required this.message,
    this.onAction,
    this.actionLabel,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'تحذير: $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppThemeConstants.warningLight,
          border: Border.all(color: AppThemeConstants.accentOrange),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppThemeConstants.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppThemeConstants.warningDark,
                  fontSize: 13,
                ),
              ),
            ),
            if (onAction != null)
              Semantics(
                button: true,
                label: actionLabel ?? 'تفعيل',
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: AppThemeConstants.warningDark,
                  ),
                  child: Text(actionLabel ?? 'تفعيل'),
                ),
              ),
            if (onDismiss != null)
              Semantics(
                button: true,
                label: 'إغلاق التحذير',
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppThemeConstants.warning,
                  ),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Success banner
class SuccessBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String? actionLabel;

  const SuccessBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'نجح: $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppThemeConstants.successLight,
          border: Border.all(color: AppThemeConstants.accentGreenAlt),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.check_circle_outline,
                color: AppThemeConstants.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppThemeConstants.successDark,
                  fontSize: 13,
                ),
              ),
            ),
            if (onAction != null)
              Semantics(
                button: true,
                label: actionLabel ?? 'إجراء',
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: AppThemeConstants.successDark,
                  ),
                  child: Text(actionLabel ?? 'عرض'),
                ),
              ),
            if (onDismiss != null)
              Semantics(
                button: true,
                label: 'إغلاق الرسالة',
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppThemeConstants.success,
                  ),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Info banner
class InfoBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String? actionLabel;

  const InfoBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'معلومة: $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppThemeConstants.accentBlueLight,
          border: Border.all(color: AppThemeConstants.accentBlue),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.info_outline,
                color: AppThemeConstants.accentBlueDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppThemeConstants.accentBlueDark,
                  fontSize: 13,
                ),
              ),
            ),
            if (onAction != null)
              Semantics(
                button: true,
                label: actionLabel ?? 'إجراء',
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: AppThemeConstants.accentBlueDark,
                  ),
                  child: Text(actionLabel ?? 'المزيد'),
                ),
              ),
            if (onDismiss != null)
              Semantics(
                button: true,
                label: 'إغلاق المعلومة',
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppThemeConstants.accentBlueDark,
                  ),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Loading banner (for inline loading states)
class LoadingBanner extends StatelessWidget {
  final String message;

  const LoadingBanner({
    super.key,
    this.message = 'جاري التحميل...',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppThemeConstants.grey100,
          border: Border.all(color: AppThemeConstants.grey300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppThemeConstants.grey600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppThemeConstants.grey700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
