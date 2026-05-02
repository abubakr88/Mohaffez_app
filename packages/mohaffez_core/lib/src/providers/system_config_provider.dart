import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dev_mode_model.dart';
import '../models/system_config_model.dart';
import '../repositories/system_config_repository.dart';
import '../utils/arabic_labels.dart';
import 'user_provider.dart';

final systemConfigRepositoryProvider = Provider<SystemConfigRepository>((ref) {
  return SystemConfigRepository(FirebaseFirestore.instance);
});

final systemConfigProvider = StreamProvider<SystemConfigModel>((ref) {
  final stream = ref.watch(systemConfigRepositoryProvider).watchGlobalConfig();
  return (() async* {
    yield SystemConfigModel.defaults();
    yield* stream;
  })();
});

final devModeProvider = StreamProvider<DevModeModel>((ref) {
  final stream = ref.watch(systemConfigRepositoryProvider).watchDevMode();
  return (() async* {
    yield DevModeModel.defaults();
    yield* stream;
  })();
});

final isDevModeActiveProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final devMode = ref.watch(devModeProvider).valueOrNull;
  if (user == null || devMode == null) return false;
  return devMode.devModeEnabled && devMode.devModeUsers.contains(user.uid);
});

class SystemConfigNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final SystemConfigRepository _repository;
  final FirebaseFunctions _functions;

  SystemConfigNotifier(this._ref, this._repository, this._functions)
      : super(const AsyncValue.data(null));

  Future<void> updateGlobalConfig(Map<String, dynamic> updates) async {
    final adminUid = _ref.read(currentUserProvider).value?.uid;
    if (adminUid == null) {
      state = AsyncValue.error(ArabicLabels.unauthorized, StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateGlobalConfig(updates, adminUid);
    });
  }

  Future<void> updateDevMode(Map<String, dynamic> updates) async {
    final adminUid = _ref.read(currentUserProvider).value?.uid;
    if (adminUid == null) {
      state = AsyncValue.error(ArabicLabels.unauthorized, StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateDevMode(updates, adminUid);
    });
  }

  Future<void> sendBroadcastNotification(
      String title, String body, String targetRole) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final callable = _functions.httpsCallable('sendBroadcastNotification');
      await callable.call({
        'title': title,
        'body': body,
        'targetRole': targetRole,
      });
    });
  }
}

final systemConfigNotifierProvider =
    StateNotifierProvider<SystemConfigNotifier, AsyncValue<void>>((ref) {
  return SystemConfigNotifier(
    ref,
    ref.watch(systemConfigRepositoryProvider),
    FirebaseFunctions.instance,
  );
});
