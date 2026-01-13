import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/session_model.dart';
import '../providers/session_provider.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/constants/app_theme.dart';
import '../shared/utils/error_handler.dart';
import 'session_details_screen.dart';

class UpcomingSessionsScreen extends ConsumerWidget {
  final String mohaffezId;

  const UpcomingSessionsScreen({
    super.key,
    required this.mohaffezId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingSessionsProvider(mohaffezId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الجلسات القادمة'),
              Text(
                'خلال الأسبوع القادم',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          elevation: 0,
        ),
        body: sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return const EmptyState(
                icon: Icons.event_busy,
                title: 'لا توجد جلسات قادمة',
                message: 'لم يتم حجز أي جلسات خلال الأسبوع القادم',
                animated: false,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _buildSessionCard(context, ref, session);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(upcomingSessionsProvider(mohaffezId)),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    WidgetRef ref,
    SessionModel session,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'ar');
    final timeFormat = DateFormat('hh:mm a', 'ar');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionDetailsScreen(session: session),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student name
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.accentGreen.withOpacity(0.2),
                    child: const Icon(
                      Icons.person,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.studentName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.sessionType == 'home' ? 'منزل' : 'مسجد',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {
                      _showAssignmentDialog(
                        context,
                        ref,
                        session.id!,
                        session,
                      );
                    },
                    tooltip: 'تحديث المهام',
                  ),
                ],
              ),

              const Divider(height: 24),

              // Date and time
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    session.sessionDate != null
                        ? dateFormat.format(session.sessionDate!)
                        : 'غير محدد',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    session.slotStart != null
                        ? timeFormat.format(session.slotStart!)
                        : session.preferredTimeSlot ?? 'غير محدد',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),

              // Location
              if (session.location.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.location,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Assignment preview
              if ((session.hifzAssignment?.isNotEmpty ?? false) ||
                  (session.murajaAssignment?.isNotEmpty ?? false)) ...[
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المهام',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (session.hifzAssignment?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          'حفظ: ${session.hifzAssignment}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      if (session.murajaAssignment?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          'مراجعة: ${session.murajaAssignment}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignmentDialog(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    SessionModel session,
  ) {
    final hifzController = TextEditingController(text: session.hifzAssignment);
    final murajaController = TextEditingController(text: session.murajaAssignment);
    int rating = session.sessionRating ?? 0;
    final notesController = TextEditingController(text: session.sessionNotes);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تحديث المهام'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: hifzController,
                    decoration: const InputDecoration(
                      labelText: 'الحفظ',
                      hintText: 'مثال: من 1 إلى 10',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: murajaController,
                    decoration: const InputDecoration(
                      labelText: 'المراجعة',
                      hintText: 'مثال: جزء عم',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  const Text('التقييم:'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(10, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() => rating = index + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      hintText: 'ملاحظات إضافية...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updateAssignment(
                    context,
                    ref,
                    sessionId: sessionId,
                    hifz: hifzController.text.trim(),
                    muraja: murajaController.text.trim(),
                    rating: rating,
                    notes: notesController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateAssignment(
    BuildContext context,
    WidgetRef ref, {
    required String sessionId,
    required String hifz,
    required String muraja,
    required int rating,
    required String notes,
  }) async {
    try {
      await ref.read(sessionActionsProvider.notifier).updateAssignment(
            sessionId: sessionId,
            hifzAssignment: hifz,
            murajaAssignment: muraja,
            rating: rating,
            notes: notes,
          );

      if (context.mounted) {
        ErrorHandler.showSuccess(context, 'تم تحديث المهام بنجاح');
      }
      
      // Refresh the sessions list
      ref.invalidate(upcomingSessionsProvider(mohaffezId));
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }
}
