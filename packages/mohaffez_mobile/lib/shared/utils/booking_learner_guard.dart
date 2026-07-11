import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

StudentProfileModel? resolveBookingLearner(
  BuildContext context,
  WidgetRef ref,
  UserModel user,
) {
  final activeProfile = ref.read(activeStudentProfileProvider).valueOrNull;
  if (activeProfile != null) return activeProfile;

  if (normalizeRole(user.role) == roleParent) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('أضف بيانات ابنك أولاً قبل إرسال طلب حجز.'),
        backgroundColor: AppThemeConstants.error,
      ),
    );
    context.push('/student-profiles');
    return null;
  }

  return StudentProfileModel.fromUser(user);
}
