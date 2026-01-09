import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/assignment_card.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/empty_state_illustrations.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider.dart';
import '../providers/user_provider.dart';

class StudentAssignmentsScreen extends ConsumerWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('يرجى تسجيل الدخول')),
          );
        }
        return _buildContent(context, ref, user.uid);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErrorDisplay.dataLoad(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, String studentId) {
    final sessionsAsync = ref.watch(studentSessionsProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تكليفاتي')),
        body: sessionsAsync.when(
          data: (sessions) {
            // Filter sessions with assignments - handle nullable fields safely
            final assignmentSessions = sessions.where((session) {
              final hifz = session.hifzAssignment ?? '';
              final muraja = session.murajaAssignment ?? '';
              final notes = session.sessionNotes ?? '';
              final rating = session.sessionRating ?? 0;
              
              return hifz.isNotEmpty ||
                  muraja.isNotEmpty ||
                  rating > 0 ||
                  notes.isNotEmpty;
            }).toList();

            if (assignmentSessions.isEmpty) {
              return IllustratedEmptyState(
                illustration: EmptyStateIllustrations.noAssignments(),
                title: 'لا توجد تكليفات',
                message: 'لم تستلم أي تكليفات من المحفظين بعد.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: assignmentSessions.length,
              itemBuilder: (context, index) {
                final session = assignmentSessions[index];
                
                return AssignmentCard(
                  mohaffezName: session.mohaffezName ?? 'محفظ',
                  location: session.location ?? '',
                  sessionType: session.sessionType ?? '',
                  slotLabel: session.preferredTimeSlot ?? '',
                  sessionDate: session.sessionDate,
                  hifz: session.hifzAssignment ?? '',
                  muraja: session.murajaAssignment ?? '',
                  rating: session.sessionRating ?? 0,
                  notes: session.sessionNotes ?? '',
                );
              },
            );
          },
          loading: () => ShimmerWidgets.list(
            itemCount: 4,
            itemBuilder: () => ShimmerWidgets.listItem(
              showAvatar: true,
              lines: 3,
            ),
          ),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(studentSessionsProvider(studentId)),
          ),
        ),
      ),
    );
  }
}
