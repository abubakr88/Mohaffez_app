import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../models/session_model.dart';

import 'session_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AcceptedSessionsScreen extends ConsumerWidget {
  const AcceptedSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
              body: Center(child: Text('Ù„Ù… ÙŠØªÙ… ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„')));
        }
        return _buildContent(context, ref, user.uid);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorDisplay.dataLoad(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, String studentId) {
    final acceptedSessionsAsync =
        ref.watch(acceptedStudentSessionsProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجللسات المقبولة'),
        ),
        body: acceptedSessionsAsync.when(
          data: (acceptedSessions) {
            if (acceptedSessions.isEmpty) {
              return Container(
                color: Colors.grey.withValues(alpha: 0.05),
                child: const EmptyState(
                  icon: Icons.event_busy,
                  title: 'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¬Ù„Ø³Ø§Øª Ù…Ù‚Ø¨ÙˆÙ„Ø©',
                  message: 'Ø¬Ù…ÙŠØ¹ Ø§Ù„Ø¬Ù„Ø³Ø§Øª Ø§Ù„Ù…Ù‚Ø¨ÙˆÙ„Ø© Ø³ØªØ¸Ù‡Ø± Ù‡Ù†Ø§',
                  animated: true,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(acceptedStudentSessionsProvider(studentId));
                await ref
                    .read(acceptedStudentSessionsProvider(studentId).future)
                    .catchError((_) => <Map<String, dynamic>>[]);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: acceptedSessions.length,
                itemBuilder: (context, index) {
                  final session = acceptedSessions[index];

                  // Create SessionModel properly with null safety
                  final sessionModel = SessionModel(
                    id: session['id'] as String?,
                    mohaffezId: session['mohaffezId'] as String? ?? '',
                    studentId: session['studentId'] as String? ?? '',
                    mohaffezName:
                        session['mohaffezName'] as String? ?? 'ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ',
                    studentName: session['studentName'] as String? ?? '',
                    sessionType: session['sessionType'] as String? ?? 'Ø¨ÙŠØª',
                    preferredTimeSlot:
                        session['preferredTimeSlot'] as String? ?? '08:00',
                    location: session['location'] as String? ?? '',
                    sessionDate: session['sessionDate'] as DateTime?,
                    slotStart: session['sessionDate'] as DateTime?,
                    slotEnd: session['sessionDate'] as DateTime?,
                    hifzAssignment: session['hifzAssignment'] as String?,
                    murajaAssignment: session['murajaAssignment'] as String?,
                    sessionRating: session['sessionRating'] as int? ?? 0,
                    sessionNotes: session['sessionNotes'] as String?,
                    status: session['status'] as String? ?? 'accepted',
                    createdAt: (session['createdAt'] as Timestamp?)?.toDate(),
                    isPaid: session['isPaid'] as bool? ?? false,
                  );

                  return _buildSessionCard(context, sessionModel);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () =>
                ref.invalidate(acceptedStudentSessionsProvider(studentId)),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, SessionModel session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.2),
          child: const Icon(Icons.school, color: AppTheme.accentGreen),
        ),
        title: Text(
          session.mohaffezName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${session.sessionType} - ${session.preferredTimeSlot}'),
            if (session.location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  session.location,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionDetailsScreen(session: session),
              ),
            );
          },
        ),
      ),
    );
  }
}
