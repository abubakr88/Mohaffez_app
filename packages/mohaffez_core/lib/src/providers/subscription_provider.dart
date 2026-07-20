// lib/providers/subscription_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_model.dart';
import '../repositories/subscription_repository.dart';

/// All subscriptions for the student — used by ActiveSubscriptionsScreen tabs.
final allStudentSubscriptionsProvider =
    StreamProvider.autoDispose.family<List<SubscriptionModel>, String>(
  (ref, studentId) => ref
      .read(subscriptionRepositoryProvider)
      .watchStudentSubscriptions(studentId),
);

/// Filtered by status — used by each tab in ActiveSubscriptionsScreen.
final filteredSubscriptionsProvider = StreamProvider.autoDispose
    .family<List<SubscriptionModel>, ({String studentId, String status})>(
  (ref, params) => ref
      .read(subscriptionRepositoryProvider)
      .watchStudentSubscriptions(params.studentId, statusFilter: params.status),
);

/// Count only — used by the home bottom nav badge.
/// autoDispose keeps it alive only while HomeShell is mounted (always).
final activeSubscriptionCountProvider = StreamProvider.family<int, String>(
  (ref, studentId) => ref
      .read(subscriptionRepositoryProvider)
      .watchActiveSubscriptionCount(studentId),
);

/// One bundle for a specific teacher — used by MohaffezProfileScreen banner.
final activeBundleForTeacherProvider = FutureProvider.autoDispose
    .family<SubscriptionModel?, ({String studentId, String mohaffezId})>(
  (ref, params) =>
      ref.read(subscriptionRepositoryProvider).getActiveBundleForTeacher(
            studentId: params.studentId,
            mohaffezId: params.mohaffezId,
          ),
);

/// One bounded Firestore read while the teacher views active bundles.
/// Search and filtering are performed locally by the screen.
final teacherActiveBundlesProvider = FutureProvider.autoDispose
    .family<List<TeacherActiveBundleInfo>, String>((ref, mohaffezId) {
  return ref
      .read(subscriptionRepositoryProvider)
      .getTeacherActiveBundles(mohaffezId);
});
