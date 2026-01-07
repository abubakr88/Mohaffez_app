import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Auth state provider - watches Firebase auth changes
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// User data model
class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String? photoUrl;
  final int followerCount;
  final int followingCount;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.photoUrl,
    this.followerCount = 0,
    this.followingCount = 0,
  });

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? 'student',
      photoUrl: data['photoUrl'] as String?,
      followerCount: data['followerCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
    );
  }
}

// Current user data provider
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  
  if (authState == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(authState.uid)
      .get();

  if (!doc.exists) return null;

  return AppUser.fromFirestore(authState.uid, doc.data()!);
});

// Loading state provider
final loadingProvider = StateProvider<bool>((ref) => false);

// Error message provider
final errorMessageProvider = StateProvider<String?>((ref) => null);
