import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../services/meeting_launcher_service.dart';

// ─── Public widget ────────────────────────────────────────────────────────────
//
// Drop this into any screen where the session is online and accepted.
//
//   OnlineMeetingButton(
//     sessionId: session.id!,
//     sessionType: session.sessionType,
//     role: isMohaffez ? 'mohaffez' : 'student',
//   )

class OnlineMeetingButton extends ConsumerStatefulWidget {
  final String sessionId;
  final String sessionType;
  final String role; // 'student' | 'mohaffez'

  const OnlineMeetingButton({
    super.key,
    required this.sessionId,
    required this.sessionType,
    required this.role,
  });

  @override
  ConsumerState<OnlineMeetingButton> createState() =>
      _OnlineMeetingButtonState();
}

class _OnlineMeetingButtonState extends ConsumerState<OnlineMeetingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _infoCardSeen = true; // optimistic: card hidden until prefs loaded
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.65,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _loadInfoCardPref();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadInfoCardPref() async {
    final seen = await MeetingLauncherService.isInfoCardSeen();
    if (mounted) setState(() => _infoCardSeen = seen);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.sessionType != 'online') return const SizedBox.shrink();

    final isEnabled = ref.watch(onlineSessionsEnabledProvider);
    if (!isEnabled) return const SizedBox.shrink();

    final state = ref.watch(meetingButtonStateProvider(
        (sessionId: widget.sessionId, role: widget.role)));
    if (state == MeetingButtonState.hidden) return const SizedBox.shrink();
    final info = ref.watch(meetingInfoProvider(widget.sessionId)).valueOrNull;
    final isPhoneCall = info?.isPhoneCall ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_infoCardSeen)
          _InfoCard(
            isPhoneCall: isPhoneCall,
            onDismiss: _dismissInfoCard,
          ),
        const SizedBox(height: 8),
        _buildButton(context, state, info),
      ],
    );
  }

  void _dismissInfoCard() async {
    await MeetingLauncherService.markInfoCardSeen();
    if (mounted) setState(() => _infoCardSeen = true);
  }

  // ── State → button ─────────────────────────────────────────────────────────

  Widget _buildButton(
    BuildContext context,
    MeetingButtonState state,
    MeetingInfo? info,
  ) {
    final isTeacher = widget.role == 'mohaffez';
    final isPhoneCall = info?.isPhoneCall ?? false;
    if (isPhoneCall) {
      switch (state) {
        case MeetingButtonState.waitingForTeacher:
          return const _DisabledButton(
            icon: Icons.hourglass_bottom_rounded,
            label: 'حان وقت الجلسة - في انتظار مكالمة المعلم',
            subtext: 'سيظهر زر الاتصال بعد أن يبدأ المعلم الجلسة',
            color: AppThemeConstants.info,
          );
        case MeetingButtonState.ready:
          return _JoinButton(
            label: 'ابدأ المكالمة الهاتفية',
            icon: Icons.phone_rounded,
            gradient: const LinearGradient(
              colors: [
                AppThemeConstants.primary,
                AppThemeConstants.primaryVariant,
              ],
            ),
            loading: _launching,
            onTap: () => _handleJoin(state: state, info: info),
          );
        case MeetingButtonState.inProgress:
          if (isTeacher) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SessionInProgressBanner(),
                const SizedBox(height: 10),
                _JoinButton(
                  label: 'تم بدء الجلسة - اتصل بالطالب',
                  icon: Icons.phone_in_talk_rounded,
                  gradient: const LinearGradient(
                    colors: [
                      AppThemeConstants.secondary,
                      AppThemeConstants.primary,
                    ],
                  ),
                  loading: _launching,
                  onTap: () => _handleJoin(state: state, info: info),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SessionStartedBanner(),
              const SizedBox(height: 10),
              _PulseJoinButton(
                pulse: _pulse,
                label: 'اتصل بمعلمك الآن',
                loading: _launching,
                onTap: () => _handleJoin(state: state, info: info),
              ),
            ],
          );
        case MeetingButtonState.pendingMeetingLink:
        case MeetingButtonState.tooEarly:
        case MeetingButtonState.teacherLate:
        case MeetingButtonState.ended:
        case MeetingButtonState.hidden:
          break;
      }
    }
    switch (state) {
      case MeetingButtonState.pendingMeetingLink:
        return const _DisabledButton(
          icon: Icons.hourglass_top_rounded,
          label: 'جاري تجهيز رابط الجلسة...',
          subtext: 'سيتم إنشاء الرابط خلال لحظات',
          color: AppThemeConstants.grey400,
        );

      case MeetingButtonState.tooEarly:
        return _CountdownButton(
          sessionId: widget.sessionId,
          role: widget.role,
        );

      case MeetingButtonState.waitingForTeacher:
        return const _DisabledButton(
          icon: Icons.hourglass_bottom_rounded,
          label: 'حان وقت الجلسة — في انتظار المعلم',
          subtext: 'سيظهر زر الانضمام بمجرد أن يبدأ معلمك الجلسة',
          color: AppThemeConstants.info,
        );

      case MeetingButtonState.teacherLate:
        return const _TeacherLateCard();

      case MeetingButtonState.ready:
        String readyLabel = 'ابدأ الجلسة';
        if (isTeacher) {
          final info =
              ref.watch(meetingInfoProvider(widget.sessionId)).valueOrNull;
          final sessionTime = info?.slotStart ?? info?.sessionDate;
          if (sessionTime != null && DateTime.now().isBefore(sessionTime)) {
            readyLabel = 'يمكنك بدأ الجلسة الآن في حالة موافقة الطالب';
          }
        }
        return _JoinButton(
          label: readyLabel,
          icon: Icons.videocam_rounded,
          gradient: const LinearGradient(
            colors: [
              AppThemeConstants.primary,
              AppThemeConstants.primaryVariant
            ],
          ),
          loading: _launching,
          onTap: () => _handleJoin(),
        );

      case MeetingButtonState.inProgress:
        if (isTeacher) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SessionInProgressBanner(),
              const SizedBox(height: 10),
              _JoinButton(
                label: 'تم بدء الجلسة — افتح الاجتماع',
                icon: Icons.open_in_new_rounded,
                gradient: const LinearGradient(
                  colors: [
                    AppThemeConstants.secondary,
                    AppThemeConstants.primary
                  ],
                ),
                loading: _launching,
                onTap: () => _handleJoin(),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SessionStartedBanner(),
            const SizedBox(height: 10),
            _PulseJoinButton(
              pulse: _pulse,
              label: 'انضم إلى معلمك الآن',
              loading: _launching,
              onTap: () => _handleJoin(),
            ),
          ],
        );

      case MeetingButtonState.ended:
        return const _DisabledButton(
          icon: Icons.videocam_off_rounded,
          label: 'انتهت',
          color: AppThemeConstants.grey400,
        );

      case MeetingButtonState.hidden:
        return const SizedBox.shrink();
    }
  }

  Future<void> _handleJoin({
    MeetingButtonState? state,
    MeetingInfo? info,
  }) async {
    if (_launching) return;
    setState(() => _launching = true);

    final currentInfo =
        info ?? ref.read(meetingInfoProvider(widget.sessionId)).valueOrNull;
    if (currentInfo == null) {
      setState(() => _launching = false);
      return;
    }

    try {
      if (currentInfo.isPhoneCall) {
        if (widget.role == 'mohaffez' && state == MeetingButtonState.ready) {
          final leadTimeMinutes = ref
                  .read(systemConfigProvider)
                  .valueOrNull
                  ?.meetingStartLeadTimeMinutes ??
              60;
          final result = await MeetingLauncherService.markMeetingStarted(
            sessionId: widget.sessionId,
            teacherId: ref.read(authStateProvider).valueOrNull?.uid ?? '',
            leadTimeMinutes: leadTimeMinutes,
          );
          if (result.error != null) return;
        }

        final phone = widget.role == 'mohaffez'
            ? currentInfo.studentPhone
            : currentInfo.mohaffezPhone;
        final launched = await MeetingLauncherService.launchPhoneCall(
          phone: phone,
          sessionId: widget.sessionId,
          role: widget.role,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رقم الهاتف غير متاح لهذه الجلسة'),
              backgroundColor: AppThemeConstants.error,
            ),
          );
        }
        return;
      }

      if (currentInfo.url.isEmpty) return;
      await MeetingLauncherService.launch(
        context: context,
        ref: ref,
        info: currentInfo,
        sessionId: widget.sessionId,
        role: widget.role,
      );
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final VoidCallback onDismiss;
  final bool isPhoneCall;

  const _InfoCard({
    required this.onDismiss,
    this.isPhoneCall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeConstants.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppThemeConstants.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppThemeConstants.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPhoneCall ? Icons.phone_rounded : Icons.videocam_rounded,
              color: AppThemeConstants.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جلسة عبر الإنترنت',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppThemeConstants.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'سيظهر زر الانضمام بمجرد أن يبدأ معلمك الجلسة. تأكد من تطبيق المحادثة (Zoom أو Google Meet) مثبّت على هاتفك.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppThemeConstants.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                size: 18, color: AppThemeConstants.grey500),
          ),
        ],
      ),
    );
  }
}

class _DisabledButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtext;
  final Color color;

  const _DisabledButton({
    required this.icon,
    required this.label,
    this.subtext,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 15)),
              if (subtext != null)
                Text(subtext!,
                    style: TextStyle(
                        fontSize: 11, color: color.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }
}

// Shows a disabled button with live countdown until the session start time,
// with a subtext noting when the user can actually join/start early.
class _CountdownButton extends ConsumerStatefulWidget {
  final String sessionId;
  final String role;
  const _CountdownButton({required this.sessionId, required this.role});

  @override
  ConsumerState<_CountdownButton> createState() => _CountdownButtonState();
}

class _CountdownButtonState extends ConsumerState<_CountdownButton> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(meetingInfoProvider(widget.sessionId));
    final info = infoAsync.valueOrNull;
    final isTeacher = widget.role == 'mohaffez';
    final leadTimeMinutes = ref
            .watch(systemConfigProvider)
            .valueOrNull
            ?.meetingStartLeadTimeMinutes ??
        60;

    final sd = info?.slotStart ?? info?.sessionDate;
    // Count down to the join-window opening (slotStart − leadTime), not the
    // session start. This is the moment the user can actually act — both
    // roles see the same number, no "I can join early but the timer says
    // I can't" confusion. Subtext still shows the real session time so the
    // agreed meeting time isn't lost.
    final DateTime? target = sd?.subtract(Duration(minutes: leadTimeMinutes));
    final actionVerb = isTeacher ? 'البدء' : 'الانضمام';

    String label = 'لم يحن وقت ${isTeacher ? 'البدء' : 'الانضمام'} بعد';
    String subtext = sd != null
        ? 'موعد الجلسة ${_fmtTime(sd)} · يمكنك $actionVerb قبلها بـ $leadTimeMinutes دقيقة'
        : 'يمكنك $actionVerb قبل الموعد بـ $leadTimeMinutes دقيقة';

    if (target != null) {
      final diff = target.difference(DateTime.now());
      if (!diff.isNegative) {
        final h = diff.inHours;
        final m = diff.inMinutes.remainder(60);
        final s = diff.inSeconds.remainder(60);
        if (h > 0) {
          label = 'يمكنك $actionVerb بعد $hس $mد';
        } else if (m > 0) {
          label = 'يمكنك $actionVerb بعد $mد $sث';
        } else {
          label = 'يمكنك $actionVerb بعد $sث';
        }
      }
    }

    return _DisabledButton(
      icon: Icons.access_time_rounded,
      label: label,
      subtext: subtext,
      color: AppThemeConstants.primary,
    );
  }
}

String _fmtTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'م' : 'ص';
  return '$h:$m $ampm';
}

class _TeacherLateCard extends StatelessWidget {
  const _TeacherLateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeConstants.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppThemeConstants.warning.withValues(alpha: 0.4),
            width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeConstants.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.access_time_filled_rounded,
                    color: AppThemeConstants.warning, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'نأسف على التأخير — هل تم التواصل مع المعلم؟',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppThemeConstants.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: AppThemeConstants.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppThemeConstants.warning.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppThemeConstants.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'يمكنك إلغاء الحلقة وطلب التعويض من معلمك',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppThemeConstants.warning,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final bool loading;
  final VoidCallback onTap;

  const _JoinButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppThemeConstants.white,
                  ),
                )
              else
                Icon(icon, size: 22, color: AppThemeConstants.white),
              const SizedBox(width: 10),
              Text(
                loading ? 'جاري الفتح...' : label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppThemeConstants.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionInProgressBanner extends StatelessWidget {
  const _SessionInProgressBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppThemeConstants.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppThemeConstants.success.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppThemeConstants.success.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle,
                color: AppThemeConstants.success, size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'تم بدء الجلسة — الطالب يستطيع الانضمام الآن',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppThemeConstants.success,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStartedBanner extends StatelessWidget {
  const _SessionStartedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeConstants.success.withValues(alpha: 0.15),
            AppThemeConstants.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppThemeConstants.success.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppThemeConstants.success.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fiber_manual_record,
                color: AppThemeConstants.success, size: 14),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بدأ المحفظ الجلسة الآن',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.success,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'المحفظ في انتظارك — انضم الآن',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppThemeConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseJoinButton extends StatelessWidget {
  final AnimationController pulse;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PulseJoinButton({
    required this.pulse,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, child) => Opacity(
        opacity: pulse.value,
        child: child,
      ),
      child: _JoinButton(
        label: label,
        icon: Icons.videocam_rounded,
        gradient: const LinearGradient(
          colors: [AppThemeConstants.secondary, AppThemeConstants.primary],
        ),
        loading: loading,
        onTap: onTap,
      ),
    );
  }
}
