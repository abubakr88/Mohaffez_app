import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStep { phone, otp, loading, done, error }

class AuthState {
  const AuthState({
    this.step = AuthStep.phone,
    this.user,
    this.role,
    this.errorMessage,
    this.phone,
    this.verificationId,
  });

  final AuthStep step;
  final User? user;
  final String? role;
  final String? errorMessage;
  final String? phone;
  final String? verificationId;

  bool get isAuthenticated => user != null && role != null;

  AuthState copyWith({
    AuthStep? step,
    User? user,
    String? role,
    String? errorMessage,
    String? phone,
    String? verificationId,
  }) =>
      AuthState(
        step: step ?? this.step,
        user: user ?? this.user,
        role: role ?? this.role,
        errorMessage: errorMessage ?? this.errorMessage,
        phone: phone ?? this.phone,
        verificationId: verificationId ?? this.verificationId,
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
      state = const AuthState(step: AuthStep.phone);
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

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(step: AuthStep.loading, phone: phone);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          final result = await _auth.signInWithCredential(credential);
          if (result.user != null) await _fetchRole(result.user!);
        },
        verificationFailed: (e) {
          state = state.copyWith(
            step: AuthStep.error,
            errorMessage: e.message ?? 'فشل إرسال الكود',
          );
        },
        codeSent: (verificationId, _) {
          state = state.copyWith(
            step: AuthStep.otp,
            verificationId: verificationId,
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        step: AuthStep.error,
        errorMessage: e.message ?? 'خطأ في إرسال الكود',
      );
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.error,
        errorMessage: 'خطأ غير متوقع: $e',
      );
    }
  }

  Future<void> verifyOtp(String otp) async {
    state = state.copyWith(step: AuthStep.loading);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: state.verificationId ?? '',
        smsCode: otp,
      );
      final result = await _auth.signInWithCredential(credential);
      if (result.user != null) await _fetchRole(result.user!);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        step: AuthStep.otp,
        errorMessage: e.message ?? 'كود خاطئ، حاول مجدداً',
      );
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.otp,
        errorMessage: 'خطأ في التحقق: $e',
      );
    }
  }

  void backToPhone() =>
      state = state.copyWith(step: AuthStep.phone, errorMessage: null);

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AuthState(step: AuthStep.phone);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

final currentRoleProvider = Provider<String?>(
  (ref) => ref.watch(authProvider).role,
);
