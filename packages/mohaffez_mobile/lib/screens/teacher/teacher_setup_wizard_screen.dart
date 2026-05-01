import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mohaffez_core/src/providers/teacher_setup_provider.dart';
import 'package:mohaffez_core/src/theme/app_theme_constants.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _DS {
  static const teal800  = Color(0xFF095752);
  static const teal700  = Color(0xFF0C6F6A);
  static const teal600  = Color(0xFF0E8278);
  static const teal500  = Color(0xFF1A9E84);
  static const teal50   = Color(0xFFEAF6F3);
  static const teal100  = Color(0xFFD4EDE7);
  static const amber    = Color(0xFFE67E22);
  static const amberBg  = Color(0xFFFFF3E0);
  static const green    = Color(0xFF2E8B57);
  static const greenBg  = Color(0xFFE8F5E9);
  static const text1    = Color(0xFF111827);
  static const text2    = Color(0xFF4B5563);
  static const text3    = Color(0xFF9CA3AF);
  static const border   = Color(0xFFE5EDE9);
  static const bg       = Color(0xFFF4F7F6);

  static const r8  = BorderRadius.all(Radius.circular(8));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r20 = BorderRadius.all(Radius.circular(20));
}

// ─── Step metadata ────────────────────────────────────────────────────────────
class _StepMeta {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String route;

  const _StepMeta({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.route,
  });
}

const _steps = [
  _StepMeta(
    title: 'الملف الشخصي',
    subtitle: 'أضف صورتك واسمك الكامل',
    description:
        'صورة واضحة واسم حقيقي يزيدان ثقة الطلاب ويرفعان معدل قبول طلباتك.',
    icon: Icons.person_rounded,
    color: _DS.teal500,
    bgColor: _DS.teal50,
    route: '/profile',
  ),
  _StepMeta(
    title: 'الشهادات والاعتمادات',
    subtitle: 'ارفع شهاداتك الدينية والتربوية',
    description:
        'الشهادات المرفوعة تُراجعها الإدارة. المحفظون الموثّقون يحصلون على وسام الاعتماد.',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFF2563EB),
    bgColor: Color(0xFFE3F2FD),
    route: '/credentials',
  ),
  _StepMeta(
    title: 'أوقات الفراغ',
    subtitle: 'حدد الأيام والأوقات المتاحة',
    description:
        'الجدول الأسبوعي يُعرض للطلاب عند الحجز. بدونه لا يمكن لأي طالب حجز جلسة.',
    icon: Icons.calendar_month_rounded,
    color: _DS.teal600,
    bgColor: _DS.teal100,
    route: '/availability',
  ),
  _StepMeta(
    title: 'أرقام المحفظة',
    subtitle: 'أضف أرقام استلام المدفوعات',
    description:
        'فودافون كاش، إنستاباي، أورنج ماني — أضف رقماً واحداً على الأقل لاستلام مدفوعات الطلاب.',
    icon: Icons.account_balance_wallet_rounded,
    color: _DS.amber,
    bgColor: _DS.amberBg,
    route: '/wallet-settings',
  ),
  _StepMeta(
    title: 'الأسعار والباقات',
    subtitle: 'حدد أسعار جلساتك وباقاتك',
    description:
        'أنشئ باقة واحدة على الأقل حتى تظهر في نتائج البحث ويتمكن الطلاب من الحجز.',
    icon: Icons.sell_rounded,
    color: Color(0xFF7A5AF8),
    bgColor: Color(0xFFF0EEFF),
    route: '/pricing-management',
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class TeacherSetupWizardScreen extends ConsumerStatefulWidget {
  const TeacherSetupWizardScreen({super.key});

  @override
  ConsumerState<TeacherSetupWizardScreen> createState() =>
      _TeacherSetupWizardScreenState();
}

class _TeacherSetupWizardScreenState
    extends ConsumerState<TeacherSetupWizardScreen> {
  int _activeStep = 0;

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(teacherSetupProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppThemeConstants.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _DS.bg,
          body: progressAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppThemeConstants.error),
                  const SizedBox(height: 12),
                  const Text('تعذر تحميل بيانات الإعداد'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.invalidate(teacherSetupProvider),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
            data: (progress) {
              // If active step was not set yet, initialize to first incomplete
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (!progress.steps[_activeStep] &&
                    progress.firstIncompleteIndex != _activeStep) {
                  // keep user's current selection unless we just loaded
                }
              });

              return CustomScrollView(
                slivers: [
                  _buildHeader(context, progress),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (progress.allDone) ...[
                          _CelebrationCard(onGoHome: () => context.go('/mohaffez-home')),
                          const SizedBox(height: 20),
                        ],
                        ...List.generate(_steps.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _StepCard(
                              index: i,
                              meta: _steps[i],
                              isDone: progress.steps[i],
                              isActive: i == _activeStep,
                              onTap: () => setState(() => _activeStep = i),
                              onOpen: () => _openStep(i, progress),
                              onSkip: () => _skipStep(progress),
                            ),
                          );
                        }),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TeacherSetupProgress progress) {
    final done = progress.completedCount;

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _DS.teal700,
      surfaceTintColor: AppThemeConstants.transparent,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_DS.teal800, _DS.teal600],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -40, left: -40,
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppThemeConstants.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                bottom: -20, right: -10,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppThemeConstants.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.white.withValues(alpha: 0.15),
                              borderRadius: _DS.r12,
                            ),
                            child: const Icon(
                              Icons.rocket_launch_rounded,
                              color: AppThemeConstants.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'دليل الإعداد السريع',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppThemeConstants.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$done من 5 ${done == 5 ? "مكتملة 🎉" : "خطوات مكتملة"}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppThemeConstants.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: _DS.r8,
                                  child: LinearProgressIndicator(
                                    value: done / 5,
                                    minHeight: 8,
                                    backgroundColor:
                                        AppThemeConstants.white.withValues(alpha: 0.2),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFD4A44A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.white.withValues(alpha: 0.15),
                              borderRadius: _DS.r12,
                              border: Border.all(
                                  color: AppThemeConstants.white.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              '$done / 5',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppThemeConstants.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStep(int index, TeacherSetupProgress progress) async {
    HapticFeedback.lightImpact();
    final route = _steps[index].route;
    await context.push(route);
    if (!mounted) return;
    ref.invalidate(teacherSetupProvider);
    // After returning, advance active step to next incomplete
    final fresh = await ref.read(teacherSetupProvider.future);
    if (!mounted) return;
    if (fresh.steps[index]) {
      // Step just completed — move to next incomplete
      final next = fresh.firstIncompleteIndex;
      setState(() => _activeStep = next);
    }
  }

  void _skipStep(TeacherSetupProgress progress) {
    HapticFeedback.selectionClick();
    // Find next step (wrapping around)
    int next = (_activeStep + 1) % _steps.length;
    setState(() => _activeStep = next);
  }
}

// ─── Step card ────────────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final int index;
  final _StepMeta meta;
  final bool isDone;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onSkip;

  const _StepCard({
    required this.index,
    required this.meta,
    required this.isDone,
    required this.isActive,
    required this.onTap,
    required this.onOpen,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDone
        ? _DS.green.withValues(alpha: 0.35)
        : isActive
            ? meta.color.withValues(alpha: 0.5)
            : _DS.border;
    final borderWidth = (isDone || isActive) ? 1.5 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: _DS.r16,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: meta.color.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: AppThemeConstants.transparent,
        borderRadius: _DS.r16,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDone ? null : onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored top stripe for active step
              if (isActive && !isDone)
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: meta.color,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      topLeft: Radius.circular(16),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Step number + icon badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? _DS.greenBg
                                    : isActive
                                        ? meta.bgColor
                                        : const Color(0xFFF9FAFB),
                                borderRadius: _DS.r12,
                              ),
                              child: Icon(
                                isDone ? Icons.check_circle_rounded : meta.icon,
                                color: isDone ? _DS.green : isActive ? meta.color : _DS.text3,
                                size: 26,
                              ),
                            ),
                            Positioned(
                              bottom: -4,
                              left: -4,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? _DS.green
                                      : isActive
                                          ? meta.color
                                          : _DS.text3,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppThemeConstants.white, width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: AppThemeConstants.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meta.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDone ? _DS.text2 : _DS.text1,
                                  decoration: isDone
                                      ? TextDecoration.none
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                meta.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _DS.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        if (isDone)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _DS.greenBg,
                              borderRadius: _DS.r8,
                              border: Border.all(
                                  color: _DS.green.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'مكتمل',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _DS.green,
                              ),
                            ),
                          )
                        else if (!isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6),
                              borderRadius: _DS.r8,
                            ),
                            child: const Text(
                              'لم يكتمل',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _DS.text3,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Expanded content for active step
                    if (isActive && !isDone) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: meta.bgColor.withValues(alpha: 0.5),
                          borderRadius: _DS.r12,
                          border: Border.all(
                              color: meta.color.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          meta.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _DS.text2,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onOpen,
                              icon: const Icon(
                                  Icons.open_in_new_rounded, size: 16),
                              label: const Text('افتح الشاشة'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: meta.color,
                                foregroundColor: AppThemeConstants.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: const RoundedRectangleBorder(
                                    borderRadius: _DS.r12),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: onSkip,
                            style: TextButton.styleFrom(
                              foregroundColor: _DS.text3,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            child: const Text(
                              'تخطي لاحقاً',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Celebration card ─────────────────────────────────────────────────────────
class _CelebrationCard extends StatelessWidget {
  final VoidCallback onGoHome;
  const _CelebrationCard({required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _DS.teal500.withValues(alpha: 0.08),
            _DS.green.withValues(alpha: 0.08),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: _DS.r20,
        border: Border.all(color: _DS.green.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _DS.greenBg,
              shape: BoxShape.circle,
              border: Border.all(
                  color: _DS.green.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(
              Icons.celebration_rounded,
              color: _DS.green,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'حساب مكتمل بالكامل!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _DS.text1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أتممت جميع خطوات الإعداد. حسابك جاهز لاستقبال الطلاب.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _DS.text2,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGoHome,
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('الذهاب للرئيسية'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.green,
                foregroundColor: AppThemeConstants.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(borderRadius: _DS.r12),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
