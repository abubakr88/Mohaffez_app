import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../shared/constants/schedule_constants.dart';
import '../shared/theme/app_theme_constants.dart';

class AvailabilityManagementScreen extends StatefulWidget {
  const AvailabilityManagementScreen({super.key});

  @override
  State<AvailabilityManagementScreen> createState() =>
      _AvailabilityManagementScreenState();
}

class _AvailabilityManagementScreenState
    extends State<AvailabilityManagementScreen>
    with SingleTickerProviderStateMixin {
  Map<int, Map<String, dynamic>> weeklySchedule = {};
  bool loading = true;
  bool _settingsError = false;
  bool _availabilityError = false;
  final Set<String> _loadingSlots = {};
  late TabController _tabController;

  int homeSlots = 0;
  int mosqueSlots = 0;
  int onlineSlots = 0;

  String startTime = ScheduleConstants.defaultStartTime;
  String endTime = ScheduleConstants.defaultEndTime;
  int sessionDuration = ScheduleConstants.defaultSessionDurationMinutes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAvailability();
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('schedule')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          startTime = data['startTime'] as String? ??
              ScheduleConstants.defaultStartTime;
          endTime =
              data['endTime'] as String? ?? ScheduleConstants.defaultEndTime;
          sessionDuration = data['sessionDuration'] as int? ??
              ScheduleConstants.defaultSessionDurationMinutes;
        });
      }
    } catch (e) {
      setState(() => _settingsError = true);
    }
  }

  Future<void> _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('schedule')
          .set({
        'startTime': startTime,
        'endTime': endTime,
        'sessionDuration': sessionDuration,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء حفظ الإعدادات. يرجى المحاولة مرة أخرى')),
        );
      }
    }
  }

  Future<void> _loadAvailability() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('availability')
          .get();

      final schedule = <int, Map<String, dynamic>>{};
      int home = 0;
      int mosque = 0;
      int online = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dayOfWeek = data['dayOfWeek'] as int;
        schedule[dayOfWeek] = data;

        final timeSlots =
            List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);
        for (var slot in timeSlots) {
          if (slot['enabled'] == true) {
            final sessionType = slot['sessionType'] as String? ?? 'home';

            if (sessionType == 'home') {
              home++;
            } else if (sessionType == 'mosque') {
              mosque++;
            } else if (sessionType == 'online') {
              online++;
            }
          }
        }
      }

      setState(() {
        weeklySchedule = schedule;
        homeSlots = home;
        mosqueSlots = mosque;
        onlineSlots = online;
        loading = false;
        _availabilityError = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        _availabilityError = true;
      });
    }
  }

  Future<void> _toggleTimeSlot(
    int dayOfWeek,
    String startTime,
    String endTime,
    String sessionType,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final slotKey = '${dayOfWeek}_${startTime}_$sessionType';
    setState(() => _loadingSlots.add(slotKey));

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('availability')
            .doc('day_$dayOfWeek');

        final doc = await transaction.get(docRef);
        List<Map<String, dynamic>> timeSlots = [];

        if (doc.exists) {
          final data = doc.data()!;
          timeSlots = List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);

          final slotIndex = timeSlots.indexWhere((slot) =>
              slot['startTime'] == startTime &&
              slot['endTime'] == endTime &&
              slot['sessionType'] == sessionType);

          if (slotIndex >= 0) {
            timeSlots[slotIndex]['enabled'] =
                !(timeSlots[slotIndex]['enabled'] ?? false);
          } else {
            timeSlots.add({
              'startTime': startTime,
              'endTime': endTime,
              'sessionType': sessionType,
              'enabled': true,
            });
          }
        } else {
          timeSlots.add({
            'startTime': startTime,
            'endTime': endTime,
            'sessionType': sessionType,
            'enabled': true,
          });
        }

        transaction.set(docRef, {
          'dayOfWeek': dayOfWeek,
          'timeSlots': timeSlots,
          'recurringWeekly': true,
        });

        return timeSlots;
      });

      _updateLocalSlotState(dayOfWeek, startTime, endTime, sessionType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء تحديث الأوقات. يرجى المحاولة مرة أخرى')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSlots.remove(slotKey));
      }
    }
  }

  void _updateLocalSlotState(int dayOfWeek, String slotStartTime, String slotEndTime, String sessionType) {
    setState(() {
      if (!weeklySchedule.containsKey(dayOfWeek)) {
        weeklySchedule[dayOfWeek] = {
          'dayOfWeek': dayOfWeek,
          'timeSlots': [
            {
              'startTime': slotStartTime,
              'endTime': slotEndTime,
              'sessionType': sessionType,
              'enabled': true,
            }
          ],
          'recurringWeekly': true,
        };
      } else {
        final daySchedule = weeklySchedule[dayOfWeek]!;
        final timeSlots = List<Map<String, dynamic>>.from(daySchedule['timeSlots'] ?? []);
        final slotIndex = timeSlots.indexWhere((slot) =>
            slot['startTime'] == slotStartTime && slot['sessionType'] == sessionType);

        if (slotIndex >= 0) {
          timeSlots[slotIndex]['enabled'] = !(timeSlots[slotIndex]['enabled'] ?? false);
        } else {
          timeSlots.add({
            'startTime': slotStartTime,
            'endTime': slotEndTime,
            'sessionType': sessionType,
            'enabled': true,
          });
        }
        weeklySchedule[dayOfWeek] = {...daySchedule, 'timeSlots': timeSlots};
      }

      _recalculateStats();
    });
  }

  void _recalculateStats() {
    int home = 0;
    int mosque = 0;
    int online = 0;

    for (final dayData in weeklySchedule.values) {
      final timeSlots = List<Map<String, dynamic>>.from(dayData['timeSlots'] ?? []);
      for (final slot in timeSlots) {
        if (slot['enabled'] == true) {
          final sessionType = slot['sessionType'] as String? ?? 'home';
          if (sessionType == 'home') {
            home++;
          } else if (sessionType == 'mosque') {
            mosque++;
          } else if (sessionType == 'online') {
            online++;
          }
        }
      }
    }

    setState(() {
      homeSlots = home;
      mosqueSlots = mosque;
      onlineSlots = online;
    });
  }

  bool _isSlotEnabled(int dayOfWeek, String startTime, String sessionType) {
    if (!weeklySchedule.containsKey(dayOfWeek)) return false;

    final daySchedule = weeklySchedule[dayOfWeek]!;
    final timeSlots =
        List<Map<String, dynamic>>.from(daySchedule['timeSlots'] ?? []);

    final slot = timeSlots.firstWhere(
      (s) => s['startTime'] == startTime && s['sessionType'] == sessionType,
      orElse: () => {},
    );

    return slot['enabled'] ?? false;
  }

  Future<void> _bulkToggleDay(String slotStartTime, String sessionType, bool enable) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('availability');

    final dayDocs = await Future.wait(
      List.generate(7, (index) async {
        final day = index + 1;
        final dayDocRef = docRef.doc('day_$day');
        return await dayDocRef.get();
      }),
    );

    final batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < dayDocs.length; i++) {
      final day = i + 1;
      final doc = dayDocs[i];
      List<Map<String, dynamic>> timeSlots = [];

      if (doc.exists) {
        final data = doc.data()!;
        timeSlots = List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);
      }

      final slotIndex = timeSlots.indexWhere((slot) =>
          slot['startTime'] == slotStartTime && slot['sessionType'] == sessionType);

      if (slotIndex >= 0) {
        timeSlots[slotIndex]['enabled'] = enable;
      } else if (enable) {
        final slots = ScheduleConstants.generateTimeSlots(
          startTime: startTime,
          endTime: endTime,
          durationMinutes: sessionDuration,
        );
        final slot = slots.firstWhere((s) => s['start'] == slotStartTime);
        timeSlots.add({
          'startTime': slotStartTime,
          'endTime': slot['end']!,
          'sessionType': sessionType,
          'enabled': true,
        });
      }

      batch.set(docRef.doc('day_$day'), {
        'dayOfWeek': day,
        'timeSlots': timeSlots,
        'recurringWeekly': true,
      });
    }

    await batch.commit();
    await _loadAvailability();
  }

  Future<void> _clearAllAvailability() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد المسح'),
          content: const Text(
            'هل تريد مسح جميع الأوقات المتاحة؟\nسيتم حذف جميع الأوقات المفعلة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppThemeConstants.error),
              child: const Text('مسح الكل'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('availability')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      await _loadAvailability();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم مسح جميع الأوقات بنجاح'),
            backgroundColor: AppThemeConstants.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء مسح الأوقات. يرجى المحاولة مرة أخرى'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSettingsDialog() async {
    String tempStart = startTime;
    String tempEnd = endTime;
    int tempDuration = sessionDuration;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إعدادات الجدول'),
          content: StatefulBuilder(
            builder: (context, setDialogState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('وقت البداية'),
                    subtitle: Text(tempStart),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(tempStart.split(':')[0]),
                          minute: int.parse(tempStart.split(':')[1]),
                        ),
                      );
                      if (time != null) {
                        setDialogState(() {
                          tempStart =
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('وقت النهاية'),
                    subtitle: Text(tempEnd),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(tempEnd.split(':')[0]),
                          minute: int.parse(tempEnd.split(':')[1]),
                        ),
                      );
                      if (time != null) {
                        setDialogState(() {
                          tempEnd =
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('مدة الجلسة (دقيقة)'),
                    subtitle: Slider(
                      value: tempDuration.toDouble(),
                      min: 15,
                      max: 120,
                      divisions: 21,
                      label: '$tempDuration دقيقة',
                      onChanged: (value) {
                        setDialogState(() {
                          tempDuration = value.toInt();
                        });
                      },
                    ),
                    trailing: Text('$tempDuration'),
                  ),
                  const Divider(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.pop(); 
                        _clearAllAvailability();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppThemeConstants.error,
                        side: const BorderSide(color: AppThemeConstants.error, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text(
                        'مسح جميع الأوقات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tempStart.compareTo(tempEnd) >= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('وقت النهاية يجب أن يكون بعد وقت البداية'),
                      backgroundColor: AppThemeConstants.error,
                    ),
                  );
                  return;
                }

                final hasOrphanedSlots = weeklySchedule.isNotEmpty &&
                    (tempStart != startTime || tempEnd != endTime || tempDuration != sessionDuration);

                if (hasOrphanedSlots) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                        title: const Text('تحذير'),
                        content: const Text(
                          'تغيير الإعدادات قد يؤدي إلى فقدان بعض الأوقات المفعلة. هل تريد المتابعة؟',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            child: const Text('متابعة'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (confirm != true) return;
                }

                setState(() {
                  startTime = tempStart;
                  endTime = tempEnd;
                  sessionDuration = tempDuration;
                });
                await _saveSettings();
                await _loadAvailability();
                if (!mounted) return;
                Navigator.pop(this.context);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

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
                child: const Text('تسجيل الدخول'),
              ),
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
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppThemeConstants.primary, Color(0xFF42A5F5)],
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
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.calendar_today,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الأوقات المتاحة',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'إدارة أوقات الجلسات',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppThemeConstants.primary,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: AppThemeConstants.primary,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(icon: Icon(Icons.home, size: 20), text: 'في المنزل'),
                      Tab(
                          icon: Icon(Icons.mosque, size: 20),
                          text: 'في المسجد'),
                      Tab(
                          icon: Icon(Icons.videocam, size: 20),
                          text: 'أونلاين'),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _showSettingsDialog,
                  tooltip: 'إعدادات الجدول',
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.home,
                      label: 'في المنزل',
                      count: homeSlots,
                      color: AppThemeConstants.primary,
                    ),
                    _buildStatItem(
                      icon: Icons.mosque,
                      label: 'في المسجد',
                      count: mosqueSlots,
                      color: AppThemeConstants.secondary,
                    ),
                    _buildStatItem(
                      icon: Icons.videocam,
                      label: 'أونلاين',
                      count: onlineSlots,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'اضغط على الأيام لتفعيل أو إلغاء الأوقات. الجدول من $startTime إلى $endTime ($sessionDuration دقيقة لكل جلسة).',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (_settingsError)
                      IconButton(
                        icon: const Icon(Icons.warning, color: Colors.orange),
                        onPressed: _loadSettings,
                        tooltip: 'إعادة تحميل الإعدادات',
                      ),
                  ],
                ),
              ),
            ),

            SliverFillRemaining(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : _availabilityError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text('حدث خطأ أثناء تحميل الأوقات'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadAvailability,
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildScheduleGrid('home'),
                            _buildScheduleGrid('mosque'),
                            _buildScheduleGrid('online'),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleGrid(String sessionType) {
    final slots = ScheduleConstants.generateTimeSlots(
      startTime: startTime,
      endTime: endTime,
      durationMinutes: sessionDuration,
    );

    return RefreshIndicator(
      onRefresh: _loadAvailability,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: slots.map((slot) {
          return TimeSlotCard(
            startTime: slot['start']!,
            endTime: slot['end']!,
            sessionType: sessionType,
            weeklySchedule: weeklySchedule,
            loadingSlots: _loadingSlots,
            onDayTap: (dayOfWeek) => _toggleTimeSlot(
              dayOfWeek,
              slot['start']!,
              slot['end']!,
              sessionType,
            ),
            onBulkToggle: (enable) => _bulkToggleDay(slot['start']!, sessionType, enable),
            isSlotEnabled: _isSlotEnabled,
          );
        }).toList(),
      ),
    );
  }
}

class TimeSlotCard extends StatelessWidget {
  final String startTime;
  final String endTime;
  final String sessionType;
  final Map<int, Map<String, dynamic>> weeklySchedule;
  final Set<String> loadingSlots;
  final Function(int) onDayTap;
  final Function(bool) onBulkToggle;
  final bool Function(int, String, String) isSlotEnabled;

  const TimeSlotCard({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.sessionType,
    required this.weeklySchedule,
    required this.loadingSlots,
    required this.onDayTap,
    required this.onBulkToggle,
    required this.isSlotEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$startTime - $endTime',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'تفعيل الكل',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  onPressed: () => onBulkToggle(true),
                  tooltip: 'تفعيل جميع الأيام',
                  color: AppThemeConstants.secondary,
                ),
                const SizedBox(width: 16),
                Text(
                  'إلغاء الكل',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, size: 20),
                  onPressed: () => onBulkToggle(false),
                  tooltip: 'إلغاء تفعيل جميع الأيام',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final dayOfWeek = index + 1;

                final isEnabled =
                    isSlotEnabled(dayOfWeek, startTime, sessionType);
                final slotKey = '${dayOfWeek}_${startTime}_$sessionType';
                final isLoading = loadingSlots.contains(slotKey);

                return DayChip(
                  day: ScheduleConstants.arabicDays[index],
                  isEnabled: isEnabled,
                  isLoading: isLoading,
                  onTap: () => onDayTap(dayOfWeek),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class DayChip extends StatelessWidget {
  final String day;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;

  const DayChip({
    super.key,
    required this.day,
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
  });

  String get _shortDay {
    switch (day) {
      case 'الإثنين': return 'إثن';
      case 'الثلاثاء': return 'ثلا';
      case 'الأربعاء': return 'أرب';
      case 'الخميس': return 'خمي';
      case 'الجمعة': return 'جمعة';
      case 'السبت': return 'سبت';
      case 'الأحد': return 'أحد';
      default: return day.substring(0, 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isLoading
              ? Colors.grey.shade300
              : isEnabled
                  ? AppThemeConstants.secondary
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled ? AppThemeConstants.secondary : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppThemeConstants.secondary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                  )
                : Icon(
                    isEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16,
                    color: isEnabled ? Colors.white : Colors.grey.shade600,
                  ),
            const SizedBox(width: 6),
            Text(
              _shortDay,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isEnabled ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
