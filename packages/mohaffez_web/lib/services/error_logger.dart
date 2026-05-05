// lib/services/error_logger.dart
// Centralized error logging service that fans out to Sentry + console

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ErrorLogger {
  /// Log error to all configured sinks
  static void logError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? extras,
    String? hint,
  }) {
    // Always log to console
    debugPrint('[Error] ${hint ?? ''} $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }

    // Send to Sentry if available (only in release mode)
    if (!kDebugMode) {
      try {
        Sentry.captureException(
          error,
          stackTrace: stackTrace,
          withScope: (scope) {
            if (extras != null) {
              for (final entry in extras.entries) {
                scope.setExtra(entry.key, entry.value);
              }
            }
            if (hint != null) {
              scope.setTag('hint', hint);
            }
          },
        );
      } catch (e) {
        debugPrint('[ErrorLogger] Failed to send to Sentry: $e');
      }
    }
  }

  /// Log a message (info level)
  static void logInfo(String message, {Map<String, dynamic>? extras}) {
    debugPrint('[Info] $message');
    if (extras != null) {
      debugPrint('[Extras] $extras');
    }
  }

  /// Log a warning
  static void logWarning(String message, {Map<String, dynamic>? extras}) {
    debugPrint('[Warning] $message');
    if (extras != null) {
      debugPrint('[Extras] $extras');
    }
  }
}
