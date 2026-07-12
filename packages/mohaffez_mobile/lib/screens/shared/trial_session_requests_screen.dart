import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../providers/trial_session_provider.dart';

class TrialSessionRequestsScreen extends ConsumerWidget {
  const TrialSessionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final requests = ref.watch(trialSessionRequestsProvider);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الحلقات التجريبية')),
        body: user == null
            ? const Center(child: CircularProgressIndicator())
            : requests.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _ErrorState(
                  onRetry: () => ref.invalidate(trialSessionRequestsProvider),
                ),
                data: (items) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(trialSessionRequestsProvider);
                    await ref
                        .read(trialSessionRequestsProvider.future)
                        .catchError((_) => <Map<String, dynamic>>[]);
                  },
                  child: items.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final request = items[index];
                            return user.role == 'mohaffez'
                                ? _TeacherTrialRequestCard(request: request)
                                : _StudentTrialRequestCard(request: request);
                          },
                        ),
                ),
              ),
      ),
    );
  }
}

class ActiveTrialSessionRequestsSection extends ConsumerWidget {
  const ActiveTrialSessionRequestsSection({
    super.key,
    required this.isTeacher,
  });

  final bool isTeacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(trialSessionRequestsProvider);

    return requests.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        final activeItems = items.where((request) {
          final status = request['status'] as String? ?? '';
          return status == 'pending_teacher' ||
              status == 'awaiting_student_confirmation';
        }).toList();
        if (activeItems.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.science_outlined,
                    color: AppThemeConstants.secondary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'طلبات الحلقات التجريبية',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/trial-requests'),
                    child: const Text('عرض الكل'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...activeItems.map(
                (request) => isTeacher
                    ? _TeacherTrialRequestCard(request: request)
                    : _StudentTrialRequestCard(request: request),
              ),
              const Divider(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _TeacherTrialRequestCard extends ConsumerWidget {
  const _TeacherTrialRequestCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = request['status'] as String? ?? '';
    final pending = status == 'pending_teacher';
    final terminalMessage = _trialTerminalMessage(status);
    final windows = List<Map<String, dynamic>>.from(
      request['availabilityWindows'] as List? ?? const [],
    );

    return _TrialCard(
      title: request['studentName'] as String? ?? 'طالب',
      status: status,
      sessionType: request['sessionType'] as String? ?? 'online',
      durationMinutes: (request['durationMinutes'] as num?)?.toInt() ?? 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الأوقات المناسبة للطالب',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...windows.map((window) => _WindowTile(window: window)),
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showProposalDialog(context, ref, request, windows),
                    icon: const Icon(Icons.event_available),
                    label: const Text('اقتراح موعد'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _reject(context, ref),
                  child: const Text('رفض'),
                ),
              ],
            ),
          ] else if (status == 'awaiting_student_confirmation' ||
              status == 'confirmed' ||
              terminalMessage != null) ...[
            _ProposalSummary(request: request),
            if (terminalMessage != null) ...[
              const SizedBox(height: 10),
              _TerminalStatusMessage(message: terminalMessage),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showProposalDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> request,
    List<Map<String, dynamic>> windows,
  ) async {
    if (windows.isEmpty) return;
    var selectedIndex = 0;
    var selectedTime = TimeOfDay.fromDateTime(
      _timestampDate(windows.first['start']) ?? DateTime.now(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final window = windows[selectedIndex];
          final start = _timestampDate(window['start'])!;
          final end = _timestampDate(window['end'])!;
          return AlertDialog(
            title: const Text('اقتراح موعد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedIndex,
                  decoration: const InputDecoration(labelText: 'الفترة'),
                  items: List.generate(
                    windows.length,
                    (index) {
                      final itemStart =
                          _timestampDate(windows[index]['start'])!;
                      final itemEnd = _timestampDate(windows[index]['end'])!;
                      return DropdownMenuItem(
                        value: index,
                        child: Text(_formatRange(itemStart, itemEnd)),
                      );
                    },
                  ),
                  onChanged: (index) {
                    if (index == null) return;
                    final newStart = _timestampDate(windows[index]['start'])!;
                    setDialogState(() {
                      selectedIndex = index;
                      selectedTime = TimeOfDay.fromDateTime(newStart);
                    });
                  },
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('وقت بداية الحلقة'),
                  subtitle: Text(selectedTime.format(context)),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                ),
                Text(
                  'الفترة المتاحة: ${_formatRange(start, end)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppThemeConstants.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('إرسال الموعد'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final selectedWindow = windows[selectedIndex];
    final windowStart = _timestampDate(selectedWindow['start'])!;
    final windowEnd = _timestampDate(selectedWindow['end'])!;
    final proposedStart = DateTime(
      windowStart.year,
      windowStart.month,
      windowStart.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final duration = (request['durationMinutes'] as num?)?.toInt() ?? 30;
    final proposedEnd = proposedStart.add(Duration(minutes: duration));
    if (proposedStart.isBefore(windowStart) || proposedEnd.isAfter(windowEnd)) {
      _message(context, 'الموعد المقترح يجب أن يكون داخل فترة الطالب.');
      return;
    }

    try {
      await ref.read(trialSessionActionsProvider.notifier).proposeTime(
            requestId: request['id'] as String,
            proposedStart: proposedStart,
          );
      if (context.mounted) {
        _message(context, 'تم إرسال الموعد المقترح للطالب.');
      }
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        _message(context, error.message ?? 'تعذر اقتراح الموعد.');
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض',
            hintText: 'اكتب سببًا مختصرًا للطالب',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      controller.dispose();
      return;
    }
    try {
      await ref.read(trialSessionActionsProvider.notifier).reject(
            requestId: request['id'] as String,
            reason: controller.text.trim(),
          );
    } catch (_) {
      if (context.mounted) _message(context, 'تعذر رفض الطلب.');
    } finally {
      controller.dispose();
    }
  }
}

class _StudentTrialRequestCard extends ConsumerWidget {
  const _StudentTrialRequestCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = request['status'] as String? ?? '';
    final terminalMessage = _trialTerminalMessage(status);
    return _TrialCard(
      title: request['mohaffezName'] as String? ?? 'المحفظ',
      status: status,
      sessionType: request['sessionType'] as String? ?? 'online',
      durationMinutes: (request['durationMinutes'] as num?)?.toInt() ?? 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status == 'pending_teacher')
            const Text('بانتظار أن يختار المحفظ موعدًا مناسبًا.')
          else if (status == 'awaiting_student_confirmation') ...[
            _ProposalSummary(request: request),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirm(context, ref),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('تأكيد الموعد'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _reject(context, ref),
                  child: const Text('رفض'),
                ),
              ],
            ),
          ] else if (status == 'confirmed' || terminalMessage != null) ...[
            _ProposalSummary(request: request),
            if (terminalMessage != null) ...[
              const SizedBox(height: 10),
              _TerminalStatusMessage(message: terminalMessage),
            ],
          ] else if (request['rejectionReason'] != null)
            Text('السبب: ${request['rejectionReason']}'),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(trialSessionActionsProvider.notifier)
          .confirmTime(request['id'] as String);
      if (context.mounted) {
        _message(context, 'تم تأكيد الحلقة التجريبية وإضافتها إلى جلساتك.');
      }
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        _message(context, error.message ?? 'تعذر تأكيد الموعد.');
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(trialSessionActionsProvider.notifier).reject(
            requestId: request['id'] as String,
            reason: 'الموعد المقترح غير مناسب',
          );
    } catch (_) {
      if (context.mounted) _message(context, 'تعذر رفض الموعد.');
    }
  }
}

class _TrialCard extends StatelessWidget {
  const _TrialCard({
    required this.title,
    required this.status,
    required this.sessionType,
    required this.durationMinutes,
    required this.child,
  });

  final String title;
  final String status;
  final String sessionType;
  final int durationMinutes;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: info.color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusBadge(info: info),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: '$durationMinutes دقيقة',
                ),
                _InfoChip(
                  icon: _sessionIcon(sessionType),
                  label: _sessionLabel(sessionType),
                ),
                const _InfoChip(
                  icon: Icons.money_off,
                  label: 'مجانًا',
                ),
              ],
            ),
            const Divider(height: 26),
            child,
          ],
        ),
      ),
    );
  }
}

class _WindowTile extends StatelessWidget {
  const _WindowTile({required this.window});

  final Map<String, dynamic> window;

  @override
  Widget build(BuildContext context) {
    final start = _timestampDate(window['start']);
    final end = _timestampDate(window['end']);
    if (start == null || end == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_formatRange(start, end))),
        ],
      ),
    );
  }
}

class _ProposalSummary extends StatelessWidget {
  const _ProposalSummary({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final start = _timestampDate(request['proposedStart']);
    final end = _timestampDate(request['proposedEnd']);
    if (start == null || end == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeConstants.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'الموعد المقترح\n${_formatRange(start, end)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalStatusMessage extends StatelessWidget {
  const _TerminalStatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeConstants.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppThemeConstants.grey100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.info});

  final ({String label, Color color, IconData icon}) info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 14, color: info.color),
          const SizedBox(width: 5),
          Text(info.label, style: TextStyle(color: info.color)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 160),
        Icon(Icons.science_outlined, size: 68, color: Colors.grey),
        SizedBox(height: 16),
        Center(
          child: Text(
            'لا توجد طلبات حلقات تجريبية',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('إعادة المحاولة'),
      ),
    );
  }
}

DateTime? _timestampDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _formatRange(DateTime start, DateTime end) {
  final day = DateFormat('EEEE d MMMM', 'ar').format(start);
  final startTime = DateFormat('h:mm a', 'ar').format(start);
  final endTime = DateFormat('h:mm a', 'ar').format(end);
  return '$day، $startTime - $endTime';
}

({String label, Color color, IconData icon}) _statusInfo(String status) {
  switch (status) {
    case 'pending_teacher':
      return (
        label: 'بانتظار المحفظ',
        color: AppThemeConstants.warning,
        icon: Icons.hourglass_top,
      );
    case 'awaiting_student_confirmation':
      return (
        label: 'بانتظار الطالب',
        color: AppThemeConstants.primary,
        icon: Icons.schedule_send,
      );
    case 'confirmed':
      return (
        label: 'مؤكد',
        color: AppThemeConstants.success,
        icon: Icons.check_circle,
      );
    case 'completed':
      return (
        label: 'مكتملة',
        color: AppThemeConstants.success,
        icon: Icons.task_alt,
      );
    case 'cancelled_by_teacher':
      return (
        label: 'ألغاه المحفظ',
        color: AppThemeConstants.warning,
        icon: Icons.cancel_schedule_send,
      );
    case 'cancelled_by_student':
      return (
        label: 'ألغاه الطالب',
        color: AppThemeConstants.warning,
        icon: Icons.cancel_schedule_send,
      );
    case 'teacher_no_show':
      return (
        label: 'غياب المحفظ',
        color: AppThemeConstants.error,
        icon: Icons.person_off,
      );
    case 'student_no_show':
      return (
        label: 'غياب الطالب',
        color: AppThemeConstants.error,
        icon: Icons.person_off,
      );
    default:
      return (
        label: 'مرفوض',
        color: AppThemeConstants.error,
        icon: Icons.cancel,
      );
  }
}

String? _trialTerminalMessage(String status) {
  switch (status) {
    case 'completed':
      return 'تم إكمال الحلقة التجريبية.';
    case 'cancelled_by_teacher':
      return 'تم إلغاء الحلقة التجريبية من المحفظ.';
    case 'cancelled_by_student':
      return 'تم إلغاء الحلقة التجريبية من الطالب.';
    case 'teacher_no_show':
      return 'تم تسجيل غياب المحفظ عن الحلقة التجريبية.';
    case 'student_no_show':
      return 'تم تسجيل غياب الطالب عن الحلقة التجريبية.';
    default:
      return null;
  }
}

String _sessionLabel(String type) {
  switch (type) {
    case 'home':
      return 'منزلي';
    case 'mosque':
      return 'في المسجد';
    default:
      return 'أونلاين';
  }
}

IconData _sessionIcon(String type) {
  switch (type) {
    case 'home':
      return Icons.home_outlined;
    case 'mosque':
      return Icons.mosque_outlined;
    default:
      return Icons.videocam_outlined;
  }
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
