// screens/completed_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/widgets/error_widgets.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/session_card.dart';
import '../providers/session_provider.dart';
import 'session_details_screen.dart';

class CompletedSessionsScreen extends ConsumerWidget {
  final String mohaffezId;

  const CompletedSessionsScreen({
    super.key,
    required this.mohaffezId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(
      completedSessionsProvider(mohaffezId),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجلسات المكتملة'),
        ),
        body: sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return const EmptyState(
                icon: Icons.event_available,
                title: 'لا توجد جلسات مكتملة',
                message: 'الجلسات التي انتهت ستظهر هنا',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return SessionCard(
                  title: session.studentName ?? 'طالب',
                  subtitle: session['sessionType'],
                  location: session.location ?? '',
                  dateTime: session.sessionDate,
                  hifz: session.hifzAssignment ?? '',
                  muraja: session.murajaAssignment ?? '',
                  rating: session.sessionRating ?? 0,
                  notes: session.sessionNotes ?? '',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionDetailsScreen(session: session),
                      ),
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(
              completedSessionsProvider(mohaffezId),
            ),
          ),
        ),
      ),
    );
  }
}
