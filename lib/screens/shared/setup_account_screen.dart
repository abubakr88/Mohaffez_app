// lib/screens/setup_account_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/exam_question_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';
import '../../providers/setup_provider.dart';
import '../../providers/system_config_provider.dart';
import '../../providers/user_provider.dart';

class SetupAccountScreen extends ConsumerStatefulWidget {
  const SetupAccountScreen({super.key});

  @override
  ConsumerState<SetupAccountScreen> createState() =>
      _SetupAccountScreenState();
}

class _SetupAccountScreenState extends ConsumerState<SetupAccountScreen> {
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // ─── Step 1: Profile fields ────────────────────────────────────
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _mainLocationText;
  double? _mainLocationLat;
  double? _mainLocationLng;

  // ─── Exam state (mohaffez only) ────────────────────────────────
  List<ExamQuestion>? _questions;
  final Map<String, int> _selectedAnswers = {}; // questionId → selectedIndex
  int _currentQuestionIndex = 0;
  DateTime? _examStartedAt;
  Timer? _examTimer;
  int _remainingSeconds = 180; // 3 minutes

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields from existing user data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        setState(() {
          _phoneController.text = user.phoneNumber ?? '';
          _cityController.text = user.city ?? '';
          _dateOfBirth = user.dateOfBirth;
          _mainLocationText = user.addressText;
          _mainLocationLat = user.addressLat;
          _mainLocationLng = user.addressLng;
        });
      }
    });
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    _phoneController.dispose();
    _cityController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ─── Age check ─────────────────────────────────────────────────
  bool _isAtLeast18(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

  // ─── Profile "Next" handler ────────────────────────────────────
  void _onProfileNext() {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار تاريخ الميلاد')),
      );
      return;
    }
    if (_mainLocationText == null ||
        _mainLocationText!.trim().isEmpty ||
        _mainLocationLat == null ||
        _mainLocationLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد موقعك الرئيسي على الخريطة')),
      );
      return;
    }

    final isMohaffez =
        ref.read(currentUserProvider).value?.role == 'mohaffez';

    if (isMohaffez == true && !_isAtLeast18(_dateOfBirth!)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('غير مؤهل'),
            content: const Text(
              'يجب أن يكون عمر المحفظ 18 عامًا على الأقل.\n'
              'لا يمكنك المتابعة كمحفظ.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).logout(),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (isMohaffez == true) {
      // Check if user has exhausted max retries
      final user = ref.read(currentUserProvider).value;
      final config = ref.read(systemConfigProvider).valueOrNull;
      final retryCount = user?.examRetryCount ?? 0;
      final maxRetries = config?.examMaxRetries ?? 3;
      
      if (retryCount >= maxRetries) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تم استنفاد المحاولات'),
              content: Text(
                'لقد استنفدت جميع محاولات إعادة الاختبار ($maxRetries محاولات).\n'
                'يرجى التواصل مع الدعم للمساعدة.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                  child: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        );
        return;
      }

      // Check if user has an active retry cooldown
      final nextRetryAt = user?.examNextRetryAt;
      if (nextRetryAt != null && DateTime.now().isBefore(nextRetryAt)) {
        final remaining = nextRetryAt.difference(DateTime.now());
        final days = remaining.inDays;
        final hours = remaining.inHours % 24;
        final minutes = remaining.inMinutes % 60;
        final remainingText = days > 0
            ? '$days يوم ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}'
            : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('مهلة إعادة الاختبار'),
              content: Text(
                'يجب الانتظار $remainingText قبل إعادة المحاولة.\n'
                'عدد المحاولات السابقة: $retryCount / $maxRetries',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                  child: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        );
        return;
      }

      // Go to exam instructions page
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 1);
    } else {
      _submitStudentSetup();
    }
  }

  // ─── Student submit ────────────────────────────────────────────
  Future<void> _submitStudentSetup() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final uid = ref.read(currentAuthUserProvider)?.uid;
      if (uid == null) throw Exception('المستخدم غير مسجل');

      await SetupService.completeStudentSetup(
        uid: uid,
        phoneNumber: _phoneController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        city: _cityController.text.trim(),
        addressText: _mainLocationText!.trim(),
        addressLat: _mainLocationLat!,
        addressLng: _mainLocationLng!,
      );

      // Invalidate user provider to pick up setupCompleted: true
      ref.invalidate(currentUserProvider);

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Start exam ────────────────────────────────────────────────
  Future<void> _pickMainLocation() async {
    final result = await context.push<Map<String, dynamic>>(
      '/pick-location',
      extra: {
        'initialLat': _mainLocationLat,
        'initialLng': _mainLocationLng,
        'initialSearchQuery': _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _mainLocationLat = result['lat'] as double?;
      _mainLocationLng = result['lng'] as double?;
      _mainLocationText =
          (result['locationName'] as String?) ??
          (result['city'] as String?) ??
          'موقع محدد';

      final pickedCity = (result['city'] as String?)?.trim();
      if (pickedCity != null && pickedCity.isNotEmpty) {
        _cityController.text = pickedCity;
      }
    });
  }

  void _startExam() {
    final questionsAsync = ref.read(examQuestionsProvider);
    questionsAsync.when(
      data: (questions) {
        if (questions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الاختبار غير متاح حاليًا. يرجى المحاولة لاحقًا'),
            ),
          );
          return;
        }
        setState(() {
          _questions = questions;
          _currentQuestionIndex = 0;
          _examStartedAt = DateTime.now();
          _remainingSeconds = 180;
          _currentStep = 2;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _startExamTimer();
      },
      loading: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري تحميل الأسئلة...')),
        );
      },
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل الأسئلة: $e')),
        );
      },
    );
  }

  // ─── Timer ─────────────────────────────────────────────────────
  void _startExamTimer() {
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _submitMohaffezSetup(timedOut: true);
      }
    });
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(1)}:${sec.toString().padLeft(2, '0')}';
  }

  // ─── Mohaffez submit ───────────────────────────────────────────
  Future<void> _submitMohaffezSetup({bool timedOut = false}) async {
    if (_isSubmitting) return;
    _examTimer?.cancel();
    setState(() => _isSubmitting = true);

    try {
      final questions = _questions!;
      int correct = 0;
      final answers = <Map<String, dynamic>>[];

      for (final q in questions) {
        final selected = _selectedAnswers[q.id];
        final isCorrect = selected == q.correctOptionIndex;
        if (isCorrect) correct++;

        answers.add({
          'questionId': q.id,
          'selectedOptionIndex': selected ?? -1, // -1 = unanswered
          'correctOptionIndex': q.correctOptionIndex,
          'isCorrect': isCorrect,
        });
      }

      final score = questions.isNotEmpty
          ? (correct / questions.length) * 100
          : 0.0;

      final uid = ref.read(currentAuthUserProvider)?.uid;
      if (uid == null) throw Exception('المستخدم غير مسجل');

      // Fetch exam configuration and current user state
      final config = await ref.read(systemConfigProvider.future);
      final user = ref.read(currentUserProvider).value;
      final currentRetryCount = user?.examRetryCount ?? 0;

      final result = await SetupService.completeMohaffezSetup(
        uid: uid,
        phoneNumber: _phoneController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        city: _cityController.text.trim(),
        addressText: _mainLocationText!.trim(),
        addressLat: _mainLocationLat!,
        addressLng: _mainLocationLng!,
        examScore: score,
        totalQuestions: questions.length,
        correctAnswers: correct,
        answers: answers,
        examStartedAt: _examStartedAt!,
        timedOut: timedOut,
        passingScore: config.examPassingScore,
        maxRetries: config.examMaxRetries,
        retryCooldownDays: config.examRetryCooldownDays,
        currentRetryCount: currentRetryCount,
      );

      ref.invalidate(currentUserProvider);

      // Navigate to exam result screen instead of directly to home
      if (mounted) {
        context.go(
          '/exam-result',
          extra: {
            'score': result.score,
            'correctAnswers': result.correctAnswers,
            'totalQuestions': result.totalQuestions,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isMohaffez = user.role == 'mohaffez';

    // Pre-fetch questions for mohaffez
    if (isMohaffez) {
      ref.watch(examQuestionsProvider);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false, // prevent back button from exiting setup
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _currentStep == 2 ? 'اختبار المهارات' : 'إعداد الحساب',
            ),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'تسجيل الخروج',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                        title: const Text('تسجيل الخروج'),
                        content: const Text('هل تريد تسجيل الخروج والعودة لاحقاً؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('تسجيل الخروج'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (confirmed == true) {
                    await FirebaseAuth.instance.signOut();
                  }
                },
              ),
            ],
          ),
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildProfileStep(),
              if (isMohaffez) _buildExamInstructionsStep(),
              if (isMohaffez) _buildExamStep(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PAGE 0 — Profile Step
  // ═══════════════════════════════════════════════════════════════
  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.person_outline, size: 64, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'أكمل بيانات حسابك',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // Phone number
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال رقم الهاتف';
                }
                if (value.trim().length < 10) {
                  return 'رقم الهاتف غير صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date of birth
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000, 1, 1),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now(),
                  locale: const Locale('ar'),
                );
                if (picked != null) {
                  setState(() => _dateOfBirth = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الميلاد',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _dateOfBirth != null
                      ? '${_dateOfBirth!.year}/${_dateOfBirth!.month}/${_dateOfBirth!.day}'
                      : 'اختر التاريخ',
                  style: TextStyle(
                    color: _dateOfBirth != null ? null : Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // City
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'المدينة',
                prefixIcon: Icon(Icons.location_city),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال المدينة';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: _pickMainLocation,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'الموقع الرئيسي',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (_mainLocationText?.trim().isNotEmpty ?? false)
                            ? _mainLocationText!
                            : 'اختر موقعك الرئيسي من الخريطة',
                        style: TextStyle(
                          color:
                              (_mainLocationText?.trim().isNotEmpty ?? false)
                                  ? null
                                  : Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.map_outlined),
                  ],
                ),
              ),
            ),
            if (_mainLocationLat != null && _mainLocationLng != null) ...[
              const SizedBox(height: 8),
              Text(
                'الإحداثيات: ${_mainLocationLat!.toStringAsFixed(4)}, ${_mainLocationLng!.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 32),

            // Next / Submit button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _onProfileNext,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        ref.watch(currentUserProvider).value?.role == 'mohaffez'
                            ? 'التالي'
                            : 'إكمال الإعداد',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PAGE 1 — Exam Instructions (Mohaffez only)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildExamInstructionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.quiz_outlined, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'اختبار تقييم المهارات',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعليمات الاختبار:',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _InstructionRow(
                    icon: Icons.format_list_numbered,
                    text: '10 أسئلة متنوعة في علوم القرآن والتجويد',
                  ),
                  SizedBox(height: 12),
                  _InstructionRow(
                    icon: Icons.timer,
                    text: 'المدة: 3 دقائق',
                  ),
                  SizedBox(height: 12),
                  _InstructionRow(
                    icon: Icons.send,
                    text: 'يتم إرسال الإجابات تلقائيًا عند انتهاء الوقت',
                  ),
                  SizedBox(height: 12),
                  _InstructionRow(
                    icon: Icons.navigate_next,
                    text: 'يمكنك التنقل بين الأسئلة بحرية',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _startExam,
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                'ابدأ الاختبار',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PAGE 2 — Exam (Mohaffez only)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildExamStep() {
    if (_questions == null || _questions!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final questions = _questions!;
    final currentQ = questions[_currentQuestionIndex];
    final total = questions.length;
    final progress = (_currentQuestionIndex + 1) / total;

    // Timer color: green → orange → red
    final timerColor = _remainingSeconds > 60
        ? Colors.green
        : _remainingSeconds > 30
            ? Colors.orange
            : Colors.red;

    return Column(
      children: [
        // ── Timer bar ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Icon(Icons.timer, color: timerColor, size: 20),
              const SizedBox(width: 4),
              Text(
                _formatTime(_remainingSeconds),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: timerColor,
                ),
              ),
              const Spacer(),
              Text(
                'سؤال ${_currentQuestionIndex + 1} من $total',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
        // ── Progress bar ───────────────────────────────────────
        LinearProgressIndicator(value: progress),

        // ── Question content ───────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  currentQ.questionText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                ...List.generate(currentQ.options.length, (index) {
                  final isSelected = _selectedAnswers[currentQ.id] == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAnswers[currentQ.id] = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                currentQ.options[index],
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // ── Navigation buttons ─────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Previous button
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _currentQuestionIndex--);
                    },
                    child: const Text('السابق'),
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              const SizedBox(width: 12),

              // Next / Submit button
              Expanded(
                child: _currentQuestionIndex < total - 1
                    ? ElevatedButton(
                        onPressed: () {
                          setState(() => _currentQuestionIndex++);
                        },
                        child: const Text('التالي'),
                      )
                    : ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitMohaffezSetup(timedOut: false),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('إرسال الإجابات'),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Helper widget for instructions ────────────────────────────
class _InstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InstructionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.teal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 15)),
        ),
      ],
    );
  }
}
