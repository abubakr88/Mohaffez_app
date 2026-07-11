import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/student_profile_model.dart';
import '../models/user_model.dart';
import '../repositories/student_profile_repository.dart';
import 'user_provider.dart';

final studentProfilesProvider =
    StreamProvider.autoDispose.family<List<StudentProfileModel>, String>(
  (ref, ownerId) {
    final repository = ref.watch(studentProfileRepositoryProvider);
    return repository.watchProfiles(ownerId);
  },
);

final activeStudentProfileProvider =
    Provider.autoDispose<AsyncValue<StudentProfileModel?>>((ref) {
  final userAsync = ref.watch(currentUserProvider);

  return userAsync.when(
    data: (user) {
      if (user == null || !isLearnerAccountRole(user.role)) {
        return const AsyncData(null);
      }

      final profilesAsync = ref.watch(studentProfilesProvider(user.uid));
      return profilesAsync.whenData(
        (profiles) => StudentProfileModel.resolveActiveOrNull(
          user,
          profiles,
          allowSelfFallback: normalizeRole(user.role) == roleStudent,
        ),
      );
    },
    loading: () => const AsyncLoading(),
    error: (error, stackTrace) => AsyncError(error, stackTrace),
  );
});
