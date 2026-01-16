// lib/screens/upcoming_sessions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/constants/app_theme.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/widgets/empty_state.dart';
import '../providers/session_provider_paginated.dart'; // ✅ FIXED: Import paginated provider

class UpcomingSessionsScreen extends ConsumerWidget {
  final String mohaffezId;

  const UpcomingSessionsScreen({super.key, required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingSessionsProvider(mohaffezId)); // ✅ FIXED

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الجلسات القادمة')),
        body: sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return const EmptyState(
                icon: Icons.event_busy,
                title: 'لا توجد جلسات قادمة',
                message: 'الجلسات المقبولة ستظهر هنا',
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
            onRetry: () => ref.invalidate(upcomingSessionsProvider(mohaffezId)), // ✅ FIXED
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, WidgetRef ref, dynamic session) {
    final sessionDate = session['sessionDate'] as DateTime?;
    final dateStr = sessionDate != null
        ? DateFormat('yyyy-MM-dd').format(sessionDate)
        : 'غير محدد';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.2), // ✅ FIXED
          child: const Icon(Icons.school, color: AppTheme.accentGreen),
        ),
        title: Text(session['studentName'] as String? ?? 'غير معروف'),
        subtitle: Text(
          '$dateStr - ${session['preferredTimeSlot'] ?? '08:00'}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showAssignmentDialog(context, ref, session['id'] as String?),
        ),
      ),
    );
  }

  void _showAssignmentDialog(BuildContext context, WidgetRef ref, String? sessionId) {
    if (sessionId == null) return;

    final hifzController = TextEditingController();
    final murajaController = TextEditingController();
    int rating = 5;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة التقييم والواجب'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: hifzController,
                    decoration: const InputDecoration(
                      labelText: 'الحفظ',
                      hintText: 'مثال: من آية 1 إلى 10',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: murajaController,
                    decoration: const InputDecoration(
                      labelText: 'المراجعة',
                      hintText: 'مثال: مراجعة سورة البقرة',
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
                      hintText: 'أضف أي ملاحظات إضافية',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updateAssignment(
                    ref,
                    sessionId: sessionId,
                    hifz: hifzController.text.trim(),
                    muraja: murajaController.text.trim(),
                    rating: rating,
                    notes: notesController.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(ctx);
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
    WidgetRef ref, {
    required String sessionId,
    required String hifz,
    required String muraja,
    required int rating,
    required String notes,
  }) async {
    try {
      await ref.read(sessionActionsProvider.notifier).updateAssignment( // ✅ FIXED
        sessionId: sessionId,
        hifzAssignment: hifz,
        murajaAssignment: muraja,
        rating: rating,
        notes: notes,
      );
      ref.invalidate(upcomingSessionsProvider(mohaffezId)); // ✅ FIXED
    } catch (e) {
      // Error handled by provider
    }
  }
}
