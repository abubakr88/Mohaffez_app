// lib/screens/student_assignments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/assignment_card.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/empty_state_illustrations.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';

class StudentAssignmentsScreen extends ConsumerWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('لم يتم تسجيل الدخول')));
        }
        return _buildContent(context, ref, user.uid);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorDisplay.dataLoad(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, String studentId) {
    final firstPageAsync = ref.watch(studentSessionsFirstPageProvider(studentId));
    final paginatedState = ref.watch(paginatedStudentSessionsProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('واجباتي')),
        body: firstPageAsync.when(
          data: (_) {
            final sessions = paginatedState.sessions; // ✅ FIXED: Use sessions instead of items

            // Filter sessions with assignments
            final assignmentSessions = sessions.where((session) {
              final hifz = session['hifzAssignment'] as String? ?? '';
              final muraja = session['murajaAssignment'] as String? ?? '';
              final notes = session['sessionNotes'] as String? ?? '';
              final rating = session['sessionRating'] as int? ?? 0;
              return hifz.isNotEmpty || muraja.isNotEmpty || rating > 0 || notes.isNotEmpty;
            }).toList();

            if (assignmentSessions.isEmpty && !paginatedState.isLoadingMore) {
              return IllustratedEmptyState(
                illustration: EmptyStateIllustrations.noAssignments(),
                title: 'لا توجد واجبات',
                message: 'جميع الواجبات والتقييمات ستظهر هنا.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: assignmentSessions.length + (paginatedState.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == assignmentSessions.length) {
                  return _buildLoadMoreButton(ref, studentId, paginatedState);
                }

                final session = assignmentSessions[index];
                return AssignmentCard(
                  mohaffezName: session['mohaffezName'] as String? ?? 'غير معروف',
                  location: session['location'] as String? ?? '',
                  sessionType: session['sessionType'] as String? ?? 'بيت',
                  slotLabel: session['preferredTimeSlot'] as String? ?? '08:00',
                  sessionDate: session['sessionDate'] as DateTime?,
                  hifz: session['hifzAssignment'] as String? ?? '',
                  muraja: session['murajaAssignment'] as String? ?? '',
                  rating: session['sessionRating'] as int? ?? 0,
                  notes: session['sessionNotes'] as String? ?? '',
                );
              },
            );
          },
          loading: () => ShimmerWidgets.list(
            itemCount: 4,
            itemBuilder: () => ShimmerWidgets.listItem(showAvatar: true, lines: 3),
          ),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(studentSessionsFirstPageProvider(studentId)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(WidgetRef ref, String studentId, StudentSessionsState paginatedState) {
    if (paginatedState.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (paginatedState.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              paginatedState.error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(paginatedStudentSessionsProvider(studentId).notifier).loadMore();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: () {
            ref.read(paginatedStudentSessionsProvider(studentId).notifier).loadMore();
          },
          icon: const Icon(Icons.expand_more),
          label: const Text('تحميل المزيد'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
        ),
      ),
    );
  }
}
