import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../providers/trial_session_provider.dart';
import '../../shared/utils/booking_learner_guard.dart';
import '../../shared/widgets/meeting_provider_picker.dart';

class RequestTrialSessionSheet extends ConsumerStatefulWidget {
  const RequestTrialSessionSheet({
    super.key,
    required this.mohaffezId,
    required this.durationMinutes,
    required this.supportedSessionTypes,
  });

  final String mohaffezId;
  final int durationMinutes;
  final List<String> supportedSessionTypes;

  static Future<bool?> show(
    BuildContext context, {
    required String mohaffezId,
    required int durationMinutes,
    required List<String> supportedSessionTypes,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RequestTrialSessionSheet(
        mohaffezId: mohaffezId,
        durationMinutes: durationMinutes,
        supportedSessionTypes: supportedSessionTypes,
      ),
    );
  }

  @override
  ConsumerState<RequestTrialSessionSheet> createState() =>
      _RequestTrialSessionSheetState();
}

class _DayAvailability {
  _DayAvailability({
    required this.date,
    required this.start,
    required this.end,
  }) : enabled = true;

  final DateTime date;
  TimeOfDay start;
  TimeOfDay end;
  bool enabled;
}

class _RequestTrialSessionSheetState
    extends ConsumerState<RequestTrialSessionSheet> {
  late final List<_DayAvailability> _days;
  late String _sessionType;
  String? _selectedProvider;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _sessionType = widget.supportedSessionTypes.firstOrNull ?? 'online';
    _days = List.generate(3, (index) {
      final date = DateTime(now.year, now.month, now.day + index);
      final defaultStart = index == 0 && now.hour >= 17
          ? TimeOfDay(hour: (now.hour + 1).clamp(0, 23), minute: 0)
          : const TimeOfDay(hour: 17, minute: 0);
      final startMinutes = defaultStart.hour * 60 + defaultStart.minute;
      final endMinutes =
          (startMinutes + widget.durationMinutes + 60).clamp(0, 1439);
      return _DayAvailability(
        date: date,
        start: defaultStart,
        end: TimeOfDay(
          hour: endMinutes ~/ 60,
          minute: endMinutes % 60,
        ),
      );
    });
  }

  DateTime _combine(DateTime date, TimeOfDay time) => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

  Future<void> _pickTime(_DayAvailability day, bool start) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? day.start : day.end,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        day.start = selected;
      } else {
        day.end = selected;
      }
    });
  }

  Future<void> _submit() async {
    if (_sessionType == 'online' && _selectedProvider == null) {
      _showMessage('اختر وسيلة الاتصال للحلقة التجريبية.');
      return;
    }

    final enabledDays = _days.where((day) => day.enabled).toList();
    if (enabledDays.isEmpty) {
      _showMessage('اختر يومًا واحدًا على الأقل.');
      return;
    }

    final windows = <Map<String, String>>[];
    for (final day in enabledDays) {
      final start = _combine(day.date, day.start);
      final end = _combine(day.date, day.end);
      if (!end.isAfter(start)) {
        _showMessage('وقت النهاية يجب أن يكون بعد وقت البداية.');
        return;
      }
      if (start.isBefore(DateTime.now())) {
        _showMessage('اختر وقتًا قادمًا لليوم.');
        return;
      }
      if (end.difference(start).inMinutes < widget.durationMinutes) {
        _showMessage(
          'يجب ألا تقل الفترة عن ${widget.durationMinutes} دقيقة.',
        );
        return;
      }
      windows.add({
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'dayKey': '${day.date.year.toString().padLeft(4, '0')}-'
            '${day.date.month.toString().padLeft(2, '0')}-'
            '${day.date.day.toString().padLeft(2, '0')}',
      });
    }

    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        _showMessage('يرجى تسجيل الدخول أولاً.');
        return;
      }
      final activeProfile = resolveBookingLearner(context, ref, user);
      if (activeProfile == null) return;
      await ref.read(trialSessionActionsProvider.notifier).createRequest(
        mohaffezId: widget.mohaffezId,
        sessionType: _sessionType,
        preferredProvider: _sessionType == 'online' ? _selectedProvider : null,
        availabilityWindows: windows,
        learnerSnapshot: {
          'studentName': activeProfile.name,
          ...activeProfile.toCallableBookingSnapshot(user),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (error) {
      _showMessage(_friendlyError(error));
    } catch (_) {
      _showMessage('تعذر إرسال الطلب. حاول مرة أخرى.');
    }
  }

  String _friendlyError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'already-exists':
        return 'سبق أن طلبت حلقة تجريبية من هذا المحفظ.';
      case 'failed-precondition':
        return error.message ?? 'الحلقات التجريبية غير متاحة حاليًا.';
      default:
        return error.message ?? 'تعذر إرسال الطلب.';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _dayLabel(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final difference = date.difference(normalizedToday).inDays;
    if (difference == 0) return 'اليوم';
    if (difference == 1) return 'غدًا';
    return 'بعد غد';
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(trialSessionActionsProvider).isLoading;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'طلب حلقة تجريبية',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
              Text(
                'حدد الفترات المناسبة لك. سيختار المحفظ موعدًا مدته '
                '${widget.durationMinutes} دقيقة داخل إحدى هذه الفترات.',
                style: const TextStyle(
                  color: AppThemeConstants.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.supportedSessionTypes.length > 1) ...[
                const Text(
                  'نوع الحلقة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: widget.supportedSessionTypes
                      .map(
                        (type) => ButtonSegment(
                          value: type,
                          label: Text(_sessionTypeLabel(type)),
                          icon: Icon(_sessionTypeIcon(type)),
                        ),
                      )
                      .toList(),
                  selected: {_sessionType},
                  onSelectionChanged: (selection) =>
                      setState(() => _sessionType = selection.first),
                ),
                const SizedBox(height: 18),
              ],
              if (_sessionType == 'online') ...[
                MeetingProviderPicker(
                  teacherId: widget.mohaffezId,
                  selected: _selectedProvider,
                  onChanged: (provider) {
                    if (!mounted || provider == _selectedProvider) return;
                    setState(() => _selectedProvider = provider);
                  },
                ),
                const SizedBox(height: 18),
              ],
              ..._days.map(_buildDayCard),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ||
                          (_sessionType == 'online' &&
                              _selectedProvider == null)
                      ? null
                      : _submit,
                  icon: loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('إرسال الطلب'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard(_DayAvailability day) {
    final localeDate = DateFormat('d MMMM', 'ar').format(day.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppThemeConstants.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: day.enabled,
                onChanged: (value) =>
                    setState(() => day.enabled = value ?? false),
              ),
              Expanded(
                child: Text(
                  '${_dayLabel(day.date)} - $localeDate',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (day.enabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'من',
                    time: day.start,
                    onPressed: () => _pickTime(day, true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeButton(
                    label: 'إلى',
                    time: day.end,
                    onPressed: () => _pickTime(day, false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _sessionTypeLabel(String type) {
    switch (type) {
      case 'home':
        return 'منزلي';
      case 'mosque':
        return 'مسجد';
      default:
        return 'أونلاين';
    }
  }

  static IconData _sessionTypeIcon(String type) {
    switch (type) {
      case 'home':
        return Icons.home_outlined;
      case 'mosque':
        return Icons.mosque_outlined;
      default:
        return Icons.videocam_outlined;
    }
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onPressed,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule, size: 18),
          const SizedBox(width: 6),
          Flexible(child: Text('$label ${time.format(context)}')),
        ],
      ),
    );
  }
}
