import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_shell.dart';
import '../widgets/offline_banner.dart';
import '../services/cache_service.dart';

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
          password: _passwordController.text.trim(),
        );

        // Load user data and cache it
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          await CacheService.saveUserId(cred.user!.uid);
          await CacheService.saveUserRole(data['role'] as String);
          await CacheService.saveUserName(data['name'] as String);
        }
      } else {
        cred = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
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

        // Cache user data
        await CacheService.saveUserId(cred.user!.uid);
        await CacheService.saveUserRole(roleString);
        await CacheService.saveUserName(_nameController.text.trim());
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLogin ? 'تم تسجيل الدخول' : 'تم إنشاء الحساب'),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'خطأ في تسجيل الدخول';
      if (e.code == 'user-not-found') {
        message = 'البريد الإلكتروني غير مسجل';
      } else if (e.code == 'wrong-password') {
        message = 'كلمة المرور غير صحيحة';
      } else if (e.code == 'email-already-in-use') {
        message = 'البريد الإلكتروني مستخدم بالفعل';
      } else if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة جداً';
      } else if (e.message != null) {
        message = e.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
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
          title: const Text('تسجيل الدخول - محفظ القرآن'),
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
                        if (!_isLogin)
                          TextFormField(
                            controller: _nameController,
                            decoration:
                                const InputDecoration(labelText: 'الاسم الكامل'),
                            validator: (value) =>
                                value == null || value.isEmpty ? 'مطلوب' : null,
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال البريد الإلكتروني';
                            }
                            // Proper email regex validation
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return 'الرجاء إدخال بريد إلكتروني صحيح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          decoration:
                              const InputDecoration(labelText: 'كلمة المرور'),
                          obscureText: true,
                          validator: (value) =>
                              value != null && value.length >= 6
                                  ? null
                                  : 'الحد الأدنى 6 حروف',
                        ),
                        const SizedBox(height: 12),
                        if (!_isLogin)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('أنا:'),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('محفظ'),
                                selected: _selectedRole == UserRole.mohaffez,
                                onSelected: (_) {
                                  setState(
                                      () => _selectedRole = UserRole.mohaffez);
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('طالب'),
                                selected: _selectedRole == UserRole.student,
                                onSelected: (_) {
                                  setState(
                                      () => _selectedRole = UserRole.student);
                                },
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton(
                            onPressed: _submit,
                            child: Text(_isLogin ? 'دخول' : 'إنشاء حساب'),
                          ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _nameController.clear();
                            });
                          },
                          child: Text(
                            _isLogin
                                ? 'إنشاء حساب جديد'
                                : 'لدي حساب بالفعل',
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
