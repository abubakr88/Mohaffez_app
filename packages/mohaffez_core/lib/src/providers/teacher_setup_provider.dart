import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_provider.dart';

class TeacherSetupProgress {
  final bool profileDone;
  final bool credentialsDone;
  final bool availabilityDone;
  final bool walletDone;
  final bool pricingDone;

  const TeacherSetupProgress({
    this.profileDone = false,
    this.credentialsDone = false,
    this.availabilityDone = false,
    this.walletDone = false,
    this.pricingDone = false,
  });

  List<bool> get steps => [
        profileDone,
        credentialsDone,
        availabilityDone,
        walletDone,
        pricingDone,
      ];

  int get completedCount => steps.where((b) => b).length;
  bool get allDone => completedCount == 5;

  int get firstIncompleteIndex {
    final i = steps.indexWhere((b) => !b);
    return i == -1 ? 0 : i;
  }
}

/// True while the teacher is navigating the sequential setup wizard flow.
final wizardModeProvider = StateProvider<bool>((ref) => false);

final teacherSetupProvider = FutureProvider<TeacherSetupProgress>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const TeacherSetupProgress();

  final uid = user.uid;
  final db = FirebaseFirestore.instance;

  final profileDone =
      user.name.isNotEmpty && (user.photoUrl?.isNotEmpty ?? false);

  final results = await Future.wait([
    db.collection('users').doc(uid).collection('credentials').limit(1).get(),
    db.collection('users').doc(uid).collection('availability').limit(1).get(),
    db.collection('users').doc(uid).get(),
    db.collection('users').doc(uid).collection('pricingPlans').limit(1).get(),
  ]);

  final credDone = (results[0] as QuerySnapshot).docs.isNotEmpty;
  final availDone = (results[1] as QuerySnapshot).docs.isNotEmpty;
  final userSnap = results[2] as DocumentSnapshot;
  final pricingDone = (results[3] as QuerySnapshot).docs.isNotEmpty;

  final walletMap =
      (userSnap.data() as Map<String, dynamic>?)?['walletNumbers']
          as Map<String, dynamic>?;
  final walletDone =
      walletMap?.values.any((v) => v is String && v.isNotEmpty) ?? false;

  return TeacherSetupProgress(
    profileDone: profileDone,
    credentialsDone: credDone,
    availabilityDone: availDone,
    walletDone: walletDone,
    pricingDone: pricingDone,
  );
});

/// Returns true the very first time this teacher opens the app after approval.
/// Writes the seen-flag to SharedPreferences so subsequent calls return false.
Future<bool> shouldAutoShowSetupWizard(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'persistent_teacher_setup_wizard_shown_v1_$uid';
  if (prefs.getBool(key) ?? false) return false;
  await prefs.setBool(key, true);
  return true;
}
