import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStep { idle, loading, done, error }

class AuthState {
  const AuthState({
    this.step = AuthStep.idle,
    this.user,
    this.role,
    this.errorMessage,
  });

  final AuthStep step;
  final User? user;
  final String? role;
  final String? errorMessage;

  bool get isAuthenticated => user != null && role != null;

  AuthState copyWith({
    AuthStep? step,
    User? user,
    String? role,
    String? errorMessage,
  }) =>
      AuthState(
        step: step ?? this.step,
        user: user ?? this.user,
        role: role ?? this.role,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(step: AuthStep.loading)) {
    _init();
  }

  final _auth = FirebaseAuth.instance;

  Future<void> _init() async {
    final user = _auth.currentUser;
    if (user == null) {
      state = const AuthState(step: AuthStep.idle);
      return;
    }
    await _fetchRole(user);
  }

  Future<void> _fetchRole(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = doc.data()?['role'] as String?;
      if (role == null) {
        state = const AuthState(
          step: AuthStep.error,
          errorMessage: 'المستخدم غير مسجل في النظام',
        );
        await _auth.signOut();
        return;
      }
      state = AuthState(step: AuthStep.done, user: user, role: role);
    } catch (e) {
      state = AuthState(
        step: AuthStep.error,
        errorMessage: 'خطأ في تحميل بيانات المستخدم: $e',
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(step: AuthStep.loading, errorMessage: null);
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (result.user != null) await _fetchRole(result.user!);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        step: AuthStep.error,
        errorMessage: _mapError(e.code),
      );
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.error,
        errorMessage: 'خطأ غير متوقع: $e',
      );
    }
  }

  String _mapError(String code) => switch (code) {
        'user-not-found'   => 'البريد الإلكتروني غير مسجل',
        'wrong-password'   => 'كلمة المرور غير صحيحة',
        'invalid-email'    => 'صيغة البريد الإلكتروني غير صحيحة',
        'user-disabled'    => 'هذا الحساب موقوف',
        'too-many-requests'=> 'محاولات كثيرة، حاول لاحقاً',
        _                  => 'فشل تسجيل الدخول، تحقق من بياناتك',
      };

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AuthState(step: AuthStep.idle);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

final currentRoleProvider = Provider<String?>(
  (ref) => ref.watch(authProvider).role,
);
