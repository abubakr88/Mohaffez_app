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

    final state = ref.watch(meetingButtonStateProvider(widget.sessionId));
    if (state == MeetingButtonState.hidden) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_infoCardSeen) _InfoCard(onDismiss: _dismissInfoCard),
        const SizedBox(height: 8),
        _buildButton(context, state),
      ],
    );
  }

  void _dismissInfoCard() async {
    await MeetingLauncherService.markInfoCardSeen();
    if (mounted) setState(() => _infoCardSeen = true);
  }

  // ── State → button ─────────────────────────────────────────────────────────

  Widget _buildButton(BuildContext context, MeetingButtonState state) {
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
        );

      case MeetingButtonState.ready:
        return _JoinButton(
          label: 'ابدأ الجلسة',
          icon: Icons.videocam_rounded,
          gradient: const LinearGradient(
            colors: [AppThemeConstants.primary, AppThemeConstants.primaryVariant],
          ),
          loading: _launching,
          onTap: _handleJoin,
        );

      case MeetingButtonState.inProgress:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.role == 'student') const _SessionStartedBanner(),
            if (widget.role == 'student') const SizedBox(height: 10),
            _PulseJoinButton(
              pulse: _pulse,
              label: widget.role == 'student'
                  ? 'انضم إلى معلمك الآن'
                  : 'الجلسة مفتوحة — افتح الاجتماع',
              loading: _launching,
              onTap: _handleJoin,
            ),
          ],
        );

      case MeetingButtonState.ended:
        return const _DisabledButton(
          icon: Icons.videocam_off_rounded,
          label: 'انتهت الجلسة',
          color: AppThemeConstants.grey400,
        );

      case MeetingButtonState.hidden:
        return const SizedBox.shrink();
    }
  }

  Future<void> _handleJoin() async {
    if (_launching) return;
    setState(() => _launching = true);

    final info = ref.read(meetingInfoProvider(widget.sessionId)).valueOrNull;
    if (info == null || info.url.isEmpty) {
      setState(() => _launching = false);
      return;
    }

    try {
      await MeetingLauncherService.launch(
        context: context,
        ref: ref,
        info: info,
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
  const _InfoCard({required this.onDismiss});

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
            child: const Icon(Icons.videocam_rounded,
                color: AppThemeConstants.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'جلسة عبر الإنترنت',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppThemeConstants.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
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
                        fontSize: 11,
                        color: color.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }
}

// Shows a disabled button with live countdown until joinWindowOpensAt.
class _CountdownButton extends ConsumerWidget {
  final String sessionId;
  const _CountdownButton({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(meetingInfoProvider(sessionId));
    final info = infoAsync.valueOrNull;
    final opensAt = info?.joinWindowOpensAt;

    String label = 'الجلسة لم تبدأ بعد';
    if (opensAt != null) {
      final diff = opensAt.difference(DateTime.now());
      final h = diff.inHours;
      final m = diff.inMinutes.remainder(60);
      final s = diff.inSeconds.remainder(60);
      if (h > 0) {
        label = 'ستبدأ خلال $hس $mد';
      } else if (m > 0) {
        label = 'ستبدأ خلال $mد $sث';
      } else {
        label = 'ستبدأ خلال $sث';
      }
    }

    return _DisabledButton(
      icon: Icons.access_time_rounded,
      label: label,
      subtext: 'يمكنك الانضمام قبل الموعد بـ 10 دقائق',
      color: AppThemeConstants.primary,
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
