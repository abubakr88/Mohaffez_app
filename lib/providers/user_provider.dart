import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'auth_provider.dart';

// Repository provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
});

// Current user provider with caching
final currentUserProvider = StreamProvider<UserModel?>((ref) async* {
  final authUser = await ref.watch(authStateProvider.future);
  
  if (authUser == null) {
    yield null;
    return;
  }

  // Get user data stream
  yield* ref.watch(userRepositoryProvider).watchUser(authUser.uid);
});

// Derived state - follower count
final followerCountProvider = Provider.family<int, String>((ref, userId) {
  final user = ref.watch(currentUserProvider).value;
  return user?.followerCount ?? 0;
});

// Derived state - following count
final followingCountProvider = Provider.family<int, String>((ref, userId) {
  final user = ref.watch(currentUserProvider).value;
  return user?.followingCount ?? 0;
});

// User role checker
final userRoleProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.role;
});

// Is mohaffez checker
final isMohaffezProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  return role == 'mohaffez';
});
