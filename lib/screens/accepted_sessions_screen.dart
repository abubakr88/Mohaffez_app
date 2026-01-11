// lib/screens/accepted_sessions_screen.dart (FIXED)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/session_card.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/widgets/empty_state_illustrations.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';

class AcceptedSessionsScreen extends ConsumerWidget {
  const AcceptedSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('مستخدم غير معروف')));
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
        appBar: AppBar(title: const Text('الجلسات المقبولة')),
        body: firstPageAsync.when(
          data: (_) {
            final sessions = paginatedState.items;

            if (sessions.isEmpty && !paginatedState.isLoadingMore) {
              return IllustratedEmptyState(
                illustration: EmptyStateIllustrations.noSessions(),
                title: 'لا توجد جلسات',
                message: 'لم تقم بحجز أي جلسات بعد. ابحث عن محفظ الآن!',
                action: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.search),
                  label: const Text('ابحث عن محفظ'),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sessions.length + (paginatedState.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Show "Load More" button at the end
                if (index == sessions.length) {
                  return _buildLoadMoreButton(ref, studentId, paginatedState);
                }

                final session = sessions[index];
                final sessionType = session.sessionType ?? '';
                final timeSlot = session.preferredTimeSlot ?? '';
                final hasValidSubtitle = sessionType.isNotEmpty && timeSlot.isNotEmpty;

                return SessionCard(
                  title: session.mohaffezName ?? 'محفظ',
                  subtitle: hasValidSubtitle ? '$sessionType - $timeSlot' : null,
                  location: session.location ?? '',
                  dateTime: session.sessionDate ?? session.slotStart,
                  hifz: session.hifzAssignment ?? '',
                  muraja: session.murajaAssignment ?? '',
                  rating: session.sessionRating ?? 0,
                  notes: session.sessionNotes ?? '',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (session.imamAddressLat != null && session.imamAddressLng != null)
                        TextButton.icon(
                          onPressed: () async {
                            // Map navigation logic
                          },
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('خريطة'),
                        ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShimmerWidgets.listItem(showAvatar: true, lines: 3),
                ),
              ),
            ),
          ),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(studentSessionsFirstPageProvider(studentId)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(WidgetRef ref, String studentId, paginatedState) {
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
              'حدث خطأ: ${paginatedState.error}',
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
