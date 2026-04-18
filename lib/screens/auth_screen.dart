import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/offline_banner.dart';
import '../services/cache_service.dart';
import '../shared/utils/validation_utils.dart';
import '../shared/theme/app_theme_constants.dart';

enum UserRole { mohaffez, student }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  UserRole _selectedRole = UserRole.mohaffez;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance;
      UserCredential cred;

      if (_isLogin) {
        cred = await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          await CacheService.saveUserId(cred.user!.uid);
          await CacheService.saveUserRole(data['role'] as String? ?? 'student');
          await CacheService.saveUserName(data['name'] as String? ?? 'مستخدم');
        }
      } else {
        cred = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        final roleString =
            _selectedRole == UserRole.mohaffez ? 'mohaffez' : 'student';

        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': roleString,
          'photoUrl': null,
          'followerCount': 0,
          'followingCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await CacheService.saveUserId(cred.user!.uid);
        await CacheService.saveUserRole(roleString);
        await CacheService.saveUserName(_nameController.text.trim());
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isLogin ? 'تم تسجيل الدخول بنجاح' : 'تم إنشاء الحساب بنجاح'),
          backgroundColor: AppThemeConstants.secondary,
        ),
      );

      context.go('/');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;
      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
          break;
        case 'email-already-in-use':
          message = 'البريد الإلكتروني مستخدم بالفعل';
          break;
        case 'weak-password':
          message = 'كلمة المرور ضعيفة جداً';
          break;
        case 'too-many-requests':
          message = 'تم تجاوز عدد المحاولات المسموح بها. يرجى المحاولة لاحقاً';
          break;
        case 'network-request-failed':
          message = 'لا يوجد اتصال بالإنترنت';
          break;
        case 'user-disabled':
          message = 'تم تعطيل هذا الحساب. يرجى التواصل مع الدعم';
          break;
        default:
          message = 'حدث خطأ أثناء المصادقة. يرجى المحاولة مرة أخرى';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppThemeConstants.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: Text(_isLogin ? 'محفظ - تسجيل الدخول' : 'محفظ - إنشاء حساب'),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: AppThemeConstants.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppThemeConstants.shadow,
                                blurRadius: 20,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/icon.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.school,
                              size: 100,
                              color: AppThemeConstants.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'محفظ',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: AppThemeConstants.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 32),

                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'الاسم'),
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الاسم مطلوب';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني'),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          textDirection: TextDirection.ltr,
                          autofillHints: const [AutofillHints.email],
                          validator: ValidationUtils.email,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: ValidationUtils.password,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 12),

                        if (!_isLogin) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('نوع الحساب:'),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('محفظ'),
                                selected: _selectedRole == UserRole.mohaffez,
                                onSelected: (_) => setState(
                                    () => _selectedRole = UserRole.mohaffez),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('طالب'),
                                selected: _selectedRole == UserRole.student,
                                onSelected: (_) => setState(
                                    () => _selectedRole = UserRole.student),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(_isLogin ? 'تسجيل الدخول' : 'إنشاء حساب'),
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_isLogin)
                          TextButton(
                            onPressed: () async {
                              final email = _emailController.text.trim();
                              if (email.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('أدخل البريد الإلكتروني أولاً'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              try {
                                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم إرسال رابط إعادة تعيين كلمة المرور'),
                                    backgroundColor: AppThemeConstants.secondary,
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('حدث خطأ أثناء إرسال رابط إعادة التعيين'),
                                    backgroundColor: AppThemeConstants.error,
                                  ),
                                );
                              }
                            },
                            child: const Text('نسيت كلمة المرور؟'),
                          ),

                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _nameController.clear();
                            });
                          },
                          child: Text(
                            _isLogin
                                ? 'ليس لديك حساب؟ سجل الآن'
                                : 'لديك حساب؟ سجل الدخول',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
