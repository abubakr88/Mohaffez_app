import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';
import '../../providers/user_provider.dart';
import '../../providers/session_provider_paginated.dart';
import '../../models/session_model.dart';
import 'package:go_router/go_router.dart';
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
              body: Center(child: Text('لم يتم تسجيل الدخول')));
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
          title: const Text('الجلسات المقبولة'),
        ),
        body: acceptedSessionsAsync.when(
          data: (acceptedSessions) {
            if (acceptedSessions.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(acceptedStudentSessionsProvider(studentId));
                  await ref
                      .read(acceptedStudentSessionsProvider(studentId).future)
                      .catchError((_) => <Map<String, dynamic>>[]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const EmptyState(
                      icon: Icons.event_available,
                      title: 'لا توجد جلسات مقبولة',
                      message: 'جميع الجلسات المقبولة ستظهر هنا',
                      animated: true,
                    ),
                  ),
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

                  final sessionModel = SessionModel(
                    id: session['id'] as String?,
                    mohaffezId: session['mohaffezId'] as String? ?? '',
                    studentId: session['studentId'] as String? ?? '',
                    mohaffezName:
                        session['mohaffezName'] as String? ?? 'غير معروف',
                    studentName: session['studentName'] as String? ?? '',
                    sessionType: session['sessionType'] as String? ?? 'بيت',
                    preferredTimeSlot:
                        session['preferredTimeSlot'] as String? ?? '08:00',
                    location: session['location'] as String? ?? '',
                    sessionDate: session['sessionDate'] as DateTime?,
                    slotStart: session['slotStart'] as DateTime?,
                    slotEnd: session['slotEnd'] as DateTime?,
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
    final isOnline = session.sessionType.contains('اون') ||
        session.sessionType.toLowerCase().contains('online');

    final dateText = session.sessionDate != null
        ? DateFormat('EEEE، d MMMM y', 'ar').format(session.sessionDate!)
        : null;

    final timeText = session.preferredTimeSlot?.isNotEmpty == true
        ? session.preferredTimeSlot
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.pushNamed(
            'session-details',
            pathParameters: {'id': session.id ?? ''},
            extra: session,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: avatar + name + type chip ──
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppThemeConstants.secondary.withValues(alpha: 0.15),
                    child: Icon(
                      isOnline ? Icons.videocam : Icons.school,
                      color: AppThemeConstants.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      session.mohaffezName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(isOnline: isOnline, label: session.sessionType),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ── Info rows ──
              if (dateText != null)
                _InfoRow(
                    icon: Icons.calendar_today,
                    text: dateText,
                    color: AppThemeConstants.primary),
              if (timeText != null)
                _InfoRow(
                    icon: Icons.access_time,
                    text: timeText,
                    color: AppThemeConstants.textSecondary),
              if (session.location.isNotEmpty)
                _InfoRow(
                    icon: isOnline ? Icons.link : Icons.location_on,
                    text: session.location,
                    color: AppThemeConstants.error),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small helpers ────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final bool isOnline;
  final String label;

  const _TypeChip({required this.isOnline, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline
            ? AppThemeConstants.info.withValues(alpha: 0.1)
            : AppThemeConstants.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? AppThemeConstants.info.withValues(alpha: 0.4)
              : AppThemeConstants.secondary.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label.isEmpty ? (isOnline ? 'أونلاين' : 'حضوري') : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isOnline ? AppThemeConstants.accentBlueDark : AppThemeConstants.secondary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoRow(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppThemeConstants.grey700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
