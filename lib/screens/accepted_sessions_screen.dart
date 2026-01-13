import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/paginated_list_view.dart';
import '../shared/widgets/session_card.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/empty_state_illustrations.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';
import 'session_details_screen.dart';

class AcceptedSessionsScreen extends ConsumerWidget {
  const AcceptedSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('غير مسجل')));
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
    final firstPageAsync =
        ref.watch(studentSessionsFirstPageProvider(studentId));
    final paginatedState =
        ref.watch(paginatedStudentSessionsProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجلسات المكتملة'),
          actions: [
            if (paginatedState.items.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Chip(
                    label: Text(
                      '${paginatedState.items.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
          ],
        ),
        body: firstPageAsync.when(
          data: (_) {
            final sessions = paginatedState.items;

            // Empty state
            if (sessions.isEmpty && !paginatedState.isLoadingMore) {
              return IllustratedEmptyState(
                illustration: EmptyStateIllustrations.noSessions(),
                title: 'لا توجد جلسات',
                message: 'لم تقم بإتمام أي جلسات بعد!',
                action: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.search),
                  label: const Text('ابحث عن محفظ'),
                ),
              );
            }

            // List with pagination
            return PaginatedListView(
              items: sessions,
              hasMore: paginatedState.hasMore,
              isLoadingMore: paginatedState.isLoadingMore,
              error: paginatedState.error,
              scrollThreshold: 0.75,
              
              // Item builder
              itemBuilder: (context, session, index) {
                final sessionType = session.sessionType ?? '';
                final timeSlot = session.preferredTimeSlot ?? '';
                final hasValidSubtitle =
                    sessionType.isNotEmpty && timeSlot.isNotEmpty;

                return SessionCard(
                  title: session.mohaffezName ?? '',
                  subtitle: hasValidSubtitle ? '$sessionType - $timeSlot' : null,
                  location: session.location ?? '',
                  dateTime: session.sessionDate ?? session.slotStart,
                  hifz: session.hifzAssignment ?? '',
                  muraja: session.murajaAssignment ?? '',
                  rating: session.sessionRating ?? 0,
                  notes: session.sessionNotes ?? '',
                  trailing: _buildTrailingActions(context, session),
                  // Added navigation on tap
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionDetailsScreen(session: session),
                      ),
                    );
                  },
                );
              },
              
              // Load more callback
              onLoadMore: () {
                return ref
                    .read(paginatedStudentSessionsProvider(studentId).notifier)
                    .loadMore();
              },
              
              // Refresh callback
              onRefresh: () async {
                return ref
                    .read(paginatedStudentSessionsProvider(studentId).notifier)
                    .refresh();
              },

              // Custom loading widget
              loadingWidget: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text(
                    'جاري تحميل المزيد...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

              // Custom error builder
              errorBuilder: (error, retry) {
                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
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
            onRetry: () =>
                ref.invalidate(studentSessionsFirstPageProvider(studentId)),
          ),
        ),
      ),
    );
  }

  Widget? _buildTrailingActions(BuildContext context, dynamic session) {
    // Add actions like navigation to map, call mohaffez, etc.
    if (session.imamAddressLat != null && session.imamAddressLng != null) {
      return IconButton(
        icon: const Icon(Icons.map, size: 20),
        onPressed: () {
          // Navigate to map or open Google Maps
        },
        tooltip: 'الموقع على الخريطة',
      );
    }
    return null;
  }
}
