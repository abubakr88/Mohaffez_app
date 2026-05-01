import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/src/services/prayer_time_service.dart';
import 'package:mohaffez_core/src/constants/schedule_constants.dart';
import '../../shared/theme/app_theme_constants.dart';

// ─── Data classes ─────────────────────────────────────────────────────────────

class _TimeRange {
  final String start;
  final String end;
  const _TimeRange({required this.start, required this.end});
}

class _DayAvailability {
  bool isActive;
  String startTime;
  String endTime;
  Set<String> sessionTypes;
  List<_TimeRange> exclusions;

  _DayAvailability({
    this.isActive = false,
    this.startTime = ScheduleConstants.defaultStartTime,
    this.endTime = ScheduleConstants.defaultEndTime,
    Set<String>? sessionTypes,
    List<_TimeRange>? exclusions,
  })  : sessionTypes = sessionTypes ?? {},
        exclusions = exclusions ?? [];

  _DayAvailability copyWith({
    bool? isActive,
    String? startTime,
    String? endTime,
    Set<String>? sessionTypes,
    List<_TimeRange>? exclusions,
  }) =>
      _DayAvailability(
        isActive: isActive ?? this.isActive,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        sessionTypes: sessionTypes ?? Set.from(this.sessionTypes),
        exclusions: exclusions ?? List.from(this.exclusions),
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AvailabilityManagementScreen extends StatefulWidget {
  const AvailabilityManagementScreen({super.key});

  @override
  State<AvailabilityManagementScreen> createState() =>
      _AvailabilityManagementScreenState();
}

class _AvailabilityManagementScreenState
    extends State<AvailabilityManagementScreen> {
  late List<_DayAvailability> _days;

  bool _loading = true;
  bool _saving = false;
  bool _loadError = false;

  // ── Session duration & break ────────────────────────────────────────────────
  int _sessionDuration = ScheduleConstants.defaultSessionDurationMinutes;
  int _breakMinutes = 0;

  // ── Prayer exclusion ────────────────────────────────────────────────────────
  bool _excludePrayers = false;
  int _prayerBeforeMinutes = -5; // negative = before azan, positive = after
  int _prayerAfterMinutes = 30;
  final _prayerService = PrayerTimeService();

  @override
  void initState() {
    super.initState();
    _days = List.generate(7, (_) => _DayAvailability());
    _loadAll();
  }

  // ── Helpers: time math ──────────────────────────────────────────────────────

  static int _toMin(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String _fromMin(int minutes) {
    final m = minutes.clamp(0, 23 * 60 + 59);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  /// True if a slot [slotStart, slotEnd) overlaps with any of [ranges].
  static bool _isExcluded(
      String slotStart, String slotEnd, List<_TimeRange> ranges) {
    final sMin = _toMin(slotStart);
    final eMin = _toMin(slotEnd);
    for (final r in ranges) {
      final rStart = _toMin(r.start);
      final rEnd = _toMin(r.end);
      if (sMin < rEnd && eMin > rStart) return true;
    }
    return false;
  }

  /// Build prayer windows from fetched times + current offsets.
  List<_TimeRange> _buildPrayerWindows(Map<String, String> prayerTimes) {
    final windows = <_TimeRange>[];
    for (final time in prayerTimes.values) {
      final azanMin = _toMin(time);
      final windowStart = azanMin + _prayerBeforeMinutes;
      final windowEnd = azanMin + _prayerAfterMinutes;
      if (windowEnd > windowStart) {
        windows.add(_TimeRange(
          start: _fromMin(windowStart),
          end: _fromMin(windowEnd),
        ));
      }
    }
    return windows;
  }

  // ── Firestore load ──────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final settingsDoc =
          await userRef.collection('settings').doc('schedule').get();

      if (settingsDoc.exists) {
        final s = settingsDoc.data()!;
        _sessionDuration = s['sessionDuration'] as int? ??
            ScheduleConstants.defaultSessionDurationMinutes;
        _excludePrayers = s['excludePrayers'] as bool? ?? false;
        _prayerBeforeMinutes = s['prayerBeforeMinutes'] as int? ?? -5;
        _prayerAfterMinutes = s['prayerAfterMinutes'] as int? ?? 30;
        _breakMinutes = s['breakMinutes'] as int? ?? 0;
      }

      final snapshot =
          await userRef.collection('availability').get();

      final newDays = List.generate(7, (_) => _DayAvailability());

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dayOfWeek = data['dayOfWeek'] as int;
        final idx = dayOfWeek - 1;
        if (idx < 0 || idx > 6) continue;

        final timeSlots =
            List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);
        final enabled =
            timeSlots.where((s) => s['enabled'] == true).toList();
        if (enabled.isEmpty) continue;

        enabled.sort((a, b) =>
            (a['startTime'] as String).compareTo(b['startTime'] as String));

        // Use explicitly stored window if available (saved since this version),
        // otherwise derive from slots for backward compatibility.
        final start = data['startTime'] as String? ??
            enabled.first['startTime'] as String;
        final end = data['endTime'] as String? ??
            enabled.last['endTime'] as String;

        final types = enabled
            .map((s) => s['sessionType'] as String? ?? 'home')
            .toSet();

        final exclusions = (data['exclusionRanges'] as List<dynamic>? ?? [])
            .map((e) => _TimeRange(
                  start: e['start'] as String,
                  end: e['end'] as String,
                ))
            .toList();

        newDays[idx] = _DayAvailability(
          isActive: true,
          startTime: start,
          endTime: end,
          sessionTypes: types,
          exclusions: exclusions,
        );
      }

      setState(() {
        _days = newDays;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  // ── Firestore save ──────────────────────────────────────────────────────────

  Future<void> _saveAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (int i = 0; i < 7; i++) {
      final day = _days[i];
      if (!day.isActive) continue;
      if (day.sessionTypes.isEmpty) {
        _showError(
            'اختر نوع جلسة واحد على الأقل ليوم ${ScheduleConstants.arabicDays[i]}');
        return;
      }
      if (_toMin(day.startTime) >= _toMin(day.endTime)) {
        _showError(
            'وقت النهاية يجب أن يكون بعد وقت البداية ليوم ${ScheduleConstants.arabicDays[i]}');
        return;
      }
    }

    // Fetch prayer times if exclusion is on
    List<_TimeRange> prayerWindows = [];
    if (_excludePrayers) {
      setState(() => _saving = true);
      final prayerTimes = await _prayerService.fetchTodayPrayerTimes();
      if (prayerTimes == null) {
        setState(() => _saving = false);
        _showError(
            'تعذر تحميل مواقيت الصلاة. تأكد من إضافة موقعك في ملفك الشخصي واتصالك بالإنترنت');
        return;
      }
      prayerWindows = _buildPrayerWindows(prayerTimes);
    }

    setState(() => _saving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      batch.set(
        userRef.collection('settings').doc('schedule'),
        {
          'sessionDuration': _sessionDuration,
          'breakMinutes': _breakMinutes,
          'excludePrayers': _excludePrayers,
          'prayerBeforeMinutes': _prayerBeforeMinutes,
          'prayerAfterMinutes': _prayerAfterMinutes,
        },
      );

      for (int i = 0; i < 7; i++) {
        final dayOfWeek = i + 1;
        final docRef =
            userRef.collection('availability').doc('day_$dayOfWeek');
        final day = _days[i];

        if (!day.isActive) {
          batch.delete(docRef);
          continue;
        }

        final allExclusions = [
          ...day.exclusions,
          ...prayerWindows,
        ];

        final slots = ScheduleConstants.generateTimeSlots(
          startTime: day.startTime,
          endTime: day.endTime,
          durationMinutes: _sessionDuration,
          breakMinutes: _breakMinutes,
        );

        final timeSlots = <Map<String, dynamic>>[];
        for (final slot in slots) {
          if (_isExcluded(slot['start']!, slot['end']!, allExclusions)) {
            continue;
          }
          for (final type in day.sessionTypes) {
            timeSlots.add({
              'startTime': slot['start'],
              'endTime': slot['end'],
              'sessionType': type,
              'enabled': true,
            });
          }
        }

        batch.set(docRef, {
          'dayOfWeek': dayOfWeek,
          'startTime': day.startTime,
          'endTime': day.endTime,
          'timeSlots': timeSlots,
          'exclusionRanges': day.exclusions
              .map((e) => {'start': e.start, 'end': e.end})
              .toList(),
          'recurringWeekly': true,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الجدول بنجاح'),
            backgroundColor: AppThemeConstants.success,
          ),
        );
      }
    } catch (_) {
      _showError('حدث خطأ أثناء الحفظ. يرجى المحاولة مرة أخرى');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── State helpers ───────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg), backgroundColor: AppThemeConstants.error),
    );
  }

  void _copyFirstDayToAll() {
    final first = _days[0];
    if (!first.isActive) {
      _showError('فعّل اليوم الأول أولاً قبل النسخ');
      return;
    }
    setState(() {
      for (int i = 1; i < 7; i++) {
        _days[i] = first.copyWith();
      }
    });
  }

  Future<void> _pickTime(int dayIdx, bool isStart) async {
    final current =
        isStart ? _days[dayIdx].startTime : _days[dayIdx].endTime;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null || !mounted) return;
    final fmt =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      _days[dayIdx] = isStart
          ? _days[dayIdx].copyWith(startTime: fmt)
          : _days[dayIdx].copyWith(endTime: fmt);
    });
  }

  void _toggleSessionType(int dayIdx, String type) {
    final types = Set<String>.from(_days[dayIdx].sessionTypes);
    types.contains(type) ? types.remove(type) : types.add(type);
    setState(() {
      _days[dayIdx] = _days[dayIdx].copyWith(sessionTypes: types);
    });
  }

  void _removeExclusion(int dayIdx, int exclIdx) {
    final updated = List<_TimeRange>.from(_days[dayIdx].exclusions)
      ..removeAt(exclIdx);
    setState(() {
      _days[dayIdx] = _days[dayIdx].copyWith(exclusions: updated);
    });
  }

  Future<void> _addExclusion(int dayIdx) async {
    final day = _days[dayIdx];
    String start = day.startTime;
    String end = day.startTime;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDS) => AlertDialog(
            title: Text(
                'استثناء ليوم ${ScheduleConstants.arabicDays[dayIdx]}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TimePickerRow(
                  label: 'من',
                  time: start,
                  onTap: () async {
                    final p = start.split(':');
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(
                          hour: int.parse(p[0]),
                          minute: int.parse(p[1])),
                    );
                    if (t != null) {
                      setDS(() => start =
                          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                    }
                  },
                ),
                const SizedBox(height: 12),
                _TimePickerRow(
                  label: 'إلى',
                  time: end,
                  onTap: () async {
                    final p = end.split(':');
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(
                          hour: int.parse(p[0]),
                          minute: int.parse(p[1])),
                    );
                    if (t != null) {
                      setDS(() => end =
                          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  if (_toMin(end) <= _toMin(start)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('وقت النهاية يجب أن يكون بعد وقت البداية'),
                        backgroundColor: AppThemeConstants.error,
                      ),
                    );
                    return;
                  }
                  final updated =
                      List<_TimeRange>.from(_days[dayIdx].exclusions)
                        ..add(_TimeRange(start: start, end: end));
                  setState(() {
                    _days[dayIdx] =
                        _days[dayIdx].copyWith(exclusions: updated);
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary),
                child: const Text('إضافة',
                    style: TextStyle(color: AppThemeConstants.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats ────────────────────────────────────────────────────────────────────

  int get _activeDays => _days.where((d) => d.isActive).length;

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('الرجاء تسجيل الدخول'),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('تسجيل الدخول')),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (_loadError)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: AppThemeConstants.error),
                      const SizedBox(height: 16),
                      const Text('حدث خطأ أثناء تحميل الجدول'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loadAll,
                          child: const Text('إعادة المحاولة')),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(child: _buildSummaryBar()),
              SliverToBoxAdapter(child: _buildHint()),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _DayCard(
                    dayName: ScheduleConstants.arabicDays[i],
                    dayIndex: i,
                    availability: _days[i],
                    onToggle: (val) => setState(
                        () => _days[i] = _days[i].copyWith(isActive: val)),
                    onPickStart: () => _pickTime(i, true),
                    onPickEnd: () => _pickTime(i, false),
                    onToggleType: (t) => _toggleSessionType(i, t),
                    onAddExclusion: () => _addExclusion(i),
                    onRemoveExclusion: (idx) => _removeExclusion(i, idx),
                    onCopyToAll: i == 0 ? _copyFirstDayToAll : null,
                  ),
                  childCount: 7,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
        floatingActionButton: (!_loading && !_loadError)
            ? FloatingActionButton.extended(
                onPressed: _saving ? null : _saveAll,
                backgroundColor: AppThemeConstants.primary,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppThemeConstants.white))
                    : const Icon(Icons.save, color: AppThemeConstants.white),
                label: Text(
                  _saving ? 'جارٍ الحفظ…' : 'حفظ الجدول',
                  style: const TextStyle(
                      color: AppThemeConstants.white, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppThemeConstants.tealGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppThemeConstants.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_today,
                            size: 28, color: AppThemeConstants.white),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الأوقات المتاحة',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppThemeConstants.white),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'حدد أيامك وأوقاتك بسهولة',
                              style: TextStyle(
                                  fontSize: 13, color: AppThemeConstants.white70),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: IconButton(
                          icon: const Icon(Icons.settings_outlined, color: AppThemeConstants.white),
                          tooltip: 'إعدادات الجدول',
                          onPressed: _showScheduleSettings,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeConstants.grey200),
        boxShadow: [
          BoxShadow(
              color: AppThemeConstants.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatPill(
              label: 'أيام نشطة',
              value: '$_activeDays',
              color: AppThemeConstants.primary,
              icon: Icons.event_available,
            ),
            const SizedBox(width: 16),
            _StatPill(
              label: 'مدة الجلسة',
              value: '$_sessionDuration د',
              color: AppThemeConstants.secondary,
              icon: Icons.timer,
            ),
            if (_breakMinutes > 0) ...[
              const SizedBox(width: 16),
              _StatPill(
                label: 'استراحة',
                value: '$_breakMinutes د',
                color: AppThemeConstants.warning,
                icon: Icons.free_breakfast_outlined,
              ),
            ],
            if (_excludePrayers) ...[
              const SizedBox(width: 16),
              const _StatPill(
                label: 'الصلوات مستثناة',
                value: '5',
                color: AppThemeConstants.success,
                icon: Icons.mosque_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHint() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeConstants.accentBlueLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppThemeConstants.accentBlueLight),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppThemeConstants.accentBlueDark, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'فعّل الأيام التي تعمل فيها، حدد الوقت ونوع الجلسة، ثم اضغط حفظ.',
              style:
                  TextStyle(fontSize: 12, color: AppThemeConstants.accentBlueDark),
            ),
          ),
        ],
      ),
    );
  }

  // ── Schedule settings dialog ──────────────────────────────────────────────

  void _showScheduleSettings() {
    int tempDuration = _sessionDuration;
    int tempBreak = _breakMinutes;
    bool tempExcludePrayers = _excludePrayers;
    int tempBefore = _prayerBeforeMinutes;
    int tempAfter = _prayerAfterMinutes;

    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDS) => AlertDialog(
            title: const Text('إعدادات الجدول'),
            contentPadding:
                const EdgeInsets.fromLTRB(24, 16, 24, 0),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Session duration ────────────────────────────────────
                  const Text('مدة الجلسة',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: tempDuration.toDouble(),
                          min: 15,
                          max: 120,
                          divisions: 21,
                          activeColor: AppThemeConstants.primary,
                          label: '$tempDuration دقيقة',
                          onChanged: (v) =>
                              setDS(() => tempDuration = v.toInt()),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '$tempDuration د',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppThemeConstants.primary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // ── Break between sessions ──────────────────────────────
                  _OffsetRow(
                    label: 'استراحة بين الجلسات',
                    sublabel: tempBreak == 0
                        ? 'بدون استراحة'
                        : '$tempBreak دقيقة بين كل جلستين',
                    value: tempBreak,
                    min: 0,
                    max: 60,
                    step: 5,
                    onChanged: (v) => setDS(() => tempBreak = v),
                  ),
                  const Divider(height: 28),

                  // ── Prayer exclusion ────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.mosque_outlined,
                          color: AppThemeConstants.success, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('استثناء أوقات الصلاة',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                      Switch.adaptive(
                        value: tempExcludePrayers,
                        onChanged: (v) =>
                            setDS(() => tempExcludePrayers = v),
                        activeTrackColor: AppThemeConstants.success,
                      ),
                    ],
                  ),

                  if (tempExcludePrayers) ...[
                    const SizedBox(height: 12),

                    // Before azan stepper
                    _OffsetRow(
                      label: 'قبل الأذان',
                      sublabel: tempBefore < 0
                          ? '${tempBefore.abs()} د قبل الأذان'
                          : tempBefore == 0
                              ? 'عند الأذان'
                              : '$tempBefore د بعد الأذان',
                      value: tempBefore,
                      min: -30,
                      max: 30,
                      step: 5,
                      onChanged: (v) => setDS(() => tempBefore = v),
                    ),
                    const SizedBox(height: 10),

                    // After azan stepper
                    _OffsetRow(
                      label: 'بعد الأذان',
                      sublabel: '+$tempAfter د',
                      value: tempAfter,
                      min: 5,
                      max: 120,
                      step: 5,
                      onChanged: (v) => setDS(() => tempAfter = v),
                    ),
                    const SizedBox(height: 12),

                    // Preview line
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.successLight,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppThemeConstants.accentGreenAlt),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppThemeConstants.success, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _prayerWindowDescription(
                                  tempBefore, tempAfter),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppThemeConstants.successDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _sessionDuration = tempDuration;
                    _breakMinutes = tempBreak;
                    _excludePrayers = tempExcludePrayers;
                    _prayerBeforeMinutes = tempBefore;
                    _prayerAfterMinutes = tempAfter;
                    _prayerService.clearCache();
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary),
                child: const Text('حفظ الإعدادات',
                    style: TextStyle(color: AppThemeConstants.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _prayerWindowDescription(int before, int after) {
    final beforeDesc = before < 0
        ? '${before.abs()} دقيقة قبل الأذان'
        : before == 0
            ? 'عند الأذان'
            : '$before دقيقة بعد الأذان';
    return 'سيتم حجب الوقت بدءاً من $beforeDesc حتى $after دقيقة بعد الأذان لكل صلاة.';
  }
}

// ─── Day card ─────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final String dayName;
  final int dayIndex;
  final _DayAvailability availability;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<String> onToggleType;
  final VoidCallback onAddExclusion;
  final ValueChanged<int> onRemoveExclusion;
  final VoidCallback? onCopyToAll;

  const _DayCard({
    required this.dayName,
    required this.dayIndex,
    required this.availability,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onToggleType,
    required this.onAddExclusion,
    required this.onRemoveExclusion,
    this.onCopyToAll,
  });

  static const _typeLabels = {
    'home': 'في المنزل',
    'mosque': 'في المسجد',
    'online': 'أونلاين',
  };
  static const _typeIcons = {
    'home': Icons.home_outlined,
    'mosque': Icons.mosque_outlined,
    'online': Icons.videocam_outlined,
  };
  static const _typeColors = {
    'home': AppThemeConstants.primary,
    'mosque': AppThemeConstants.secondary,
    'online': AppThemeConstants.accentBlue,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: availability.isActive
              ? AppThemeConstants.primary
              : AppThemeConstants.grey200,
          width: 1.5,
        ),
        boxShadow: availability.isActive
            ? [
                BoxShadow(
                  color: AppThemeConstants.primary.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          _buildHeader(),
          if (availability.isActive) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildTimeRow(),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildTypeRow(),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildExclusionsSection(),
            if (onCopyToAll != null) _buildCopyRow(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: availability.isActive
                  ? AppThemeConstants.primary.withValues(alpha: 0.1)
                  : AppThemeConstants.grey100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _shortDay,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: availability.isActive
                      ? AppThemeConstants.primary
                      : AppThemeConstants.grey500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dayName,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: availability.isActive
                    ? AppThemeConstants.black87
                    : AppThemeConstants.grey400,
              ),
            ),
          ),
          Switch.adaptive(
            value: availability.isActive,
            onChanged: onToggle,
            activeTrackColor: AppThemeConstants.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 18, color: AppThemeConstants.grey500),
          const SizedBox(width: 8),
          const Text('من',
              style: TextStyle(fontSize: 13, color: AppThemeConstants.grey500)),
          const SizedBox(width: 8),
          _TimeButton(time: availability.startTime, onTap: onPickStart),
          const SizedBox(width: 8),
          const Text('إلى',
              style: TextStyle(fontSize: 13, color: AppThemeConstants.grey500)),
          const SizedBox(width: 8),
          _TimeButton(time: availability.endTime, onTap: onPickEnd),
        ],
      ),
    );
  }

  Widget _buildTypeRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: _typeLabels.entries.map((e) {
          final selected = availability.sessionTypes.contains(e.key);
          final color = _typeColors[e.key]!;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _TypeChip(
                label: e.value,
                icon: _typeIcons[e.key]!,
                selected: selected,
                color: color,
                onTap: () => onToggleType(e.key),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExclusionsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.block, size: 16, color: AppThemeConstants.accentRed),
              SizedBox(width: 6),
              Text(
                'أوقات مستثناة',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (availability.exclusions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...availability.exclusions.asMap().entries.map((entry) {
              final i = entry.key;
              final excl = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.errorLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppThemeConstants.errorLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_circle_outline,
                          size: 16, color: AppThemeConstants.accentRed),
                      const SizedBox(width: 8),
                      Text(
                        '${excl.start}  –  ${excl.end}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppThemeConstants.error,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => onRemoveExclusion(i),
                        child: const Icon(Icons.close,
                            size: 18, color: AppThemeConstants.accentRed),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onAddExclusion,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('إضافة وقت مستثنى',
                style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: AppThemeConstants.error,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: TextButton.icon(
        onPressed: onCopyToAll,
        icon: const Icon(Icons.copy_all, size: 16),
        label: const Text('نسخ هذا الجدول لجميع الأيام',
            style: TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          foregroundColor: AppThemeConstants.secondary,
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  String get _shortDay {
    switch (dayName) {
      case 'الاثنين': return 'إثن';
      case 'الثلاثاء': return 'ثلا';
      case 'الأربعاء': return 'أرب';
      case 'الخميس': return 'خمي';
      case 'الجمعة': return 'جمع';
      case 'السبت': return 'سبت';
      case 'الأحد': return 'أحد';
      default: return dayName.substring(0, 3);
    }
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _TimeButton extends StatelessWidget {
  final String time;
  final VoidCallback onTap;
  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppThemeConstants.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppThemeConstants.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          time,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppThemeConstants.primary,
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppThemeConstants.grey100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppThemeConstants.grey300,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? color : AppThemeConstants.grey400),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? color : AppThemeConstants.grey500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatPill(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppThemeConstants.grey500)),
          ],
        ),
      ],
    );
  }
}

/// +/− stepper for integer offsets.
class _OffsetRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _OffsetRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(sublabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppThemeConstants.grey600)),
            ],
          ),
        ),
        _StepButton(
          icon: Icons.remove,
          enabled: value > min,
          onTap: () => onChanged((value - step).clamp(min, max)),
        ),
        Container(
          width: 52,
          alignment: Alignment.center,
          child: Text(
            value >= 0 ? '+$value' : '$value',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          enabled: value < max,
          onTap: () => onChanged((value + step).clamp(min, max)),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepButton(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? AppThemeConstants.primary.withValues(alpha: 0.1)
              : AppThemeConstants.grey100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? AppThemeConstants.primary.withValues(alpha: 0.3)
                : AppThemeConstants.grey200,
          ),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled
                ? AppThemeConstants.primary
                : AppThemeConstants.grey400),
      ),
    );
  }
}

/// Compact row used in the "add exclusion" dialog.
class _TimePickerRow extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;
  const _TimePickerRow(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        _TimeButton(time: time, onTap: onTap),
      ],
    );
  }
}
