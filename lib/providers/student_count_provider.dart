import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Provider that gets student count via Cloud Function (works for both teachers and students viewing profiles)
final mohaffezStudentCountProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, mohaffezId) async {
    if (mohaffezId.isEmpty) return 0;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getMohaffezStudentCount');
      final result = await callable.call({'mohaffezId': mohaffezId});
      final count = result.data['count'] as int? ?? 0;
      debugPrint('☁️ Cloud Function returned student count: $count for $mohaffezId');
      return count;
    } catch (e) {
      debugPrint('❌ Cloud Function error: $e');
      // Fallback: return 0 if function fails
      return 0;
    }
  },
);
