// screens/completed_sessions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/widgets/empty_state.dart';
import '../providers/session_provider_paginated.dart';

class CompletedSessionsScreen extends ConsumerWidget {
  final String mohaffezId;

  const CompletedSessionsScreen({
    super.key,
    required this.mohaffezId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginatedState = ref.watch(completedSessionsPaginatedProvider(mohaffezId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجلسات المكتملة'),
        ),
        body: _buildBody(context, ref, paginatedState),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    CompletedSessionsState state,
  ) {
    if (state.sessions.isEmpty && !state.isLoadingMore && !state.hasMore) {
      return const EmptyState(
        icon: Icons.event_available,
        title: 'لا توجد جلسات مكتملة',
        message: 'سيتم عرض جلساتك المكتملة هنا',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          ref.read(completedSessionsPaginatedProvider(mohaffezId).notifier).loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          ref.read(completedSessionsPaginatedProvider(mohaffezId).notifier).refresh();
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.sessions.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at bottom
            if (index == state.sessions.length) {
              if (state.isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (state.error != null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => ref
                            .read(completedSessionsPaginatedProvider(mohaffezId).notifier)
                            .loadMore(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }

            // ✅ Build session card from map
            final session = state.sessions[index];
            return _buildSessionCard(context, session);
          },
        ),
      ),
    );
  }

  // ✅ Updated to accept Map instead of SessionModel
  Widget _buildSessionCard(BuildContext context, Map<String, dynamic> session) {
    final studentName = session['studentName'] as String? ?? 'غير معروف';
    final sessionType = session['sessionType'] as String? ?? 'منزل';
    final location = session['location'] as String? ?? '';
    final sessionDate = session['sessionDate'] as DateTime?;
    final hifzAssignment = session['hifzAssignment'] as String?;
    final murajaAssignment = session['murajaAssignment'] as String?;
    final sessionRating = session['sessionRating'] as int?;
    final sessionNotes = session['sessionNotes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.2),
          child: const Icon(Icons.check_circle, color: Colors.green),
        ),
        title: Text(
          studentName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$sessionType${location.isNotEmpty ? ' - $location' : ''}'),
            if (sessionDate != null)
              Text(
                DateFormat('dd/MM/yyyy').format(sessionDate),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hifzAssignment != null && hifzAssignment.isNotEmpty) ...[
                  _buildInfoRow('تكليف الحفظ', hifzAssignment),
                  const SizedBox(height: 8),
                ],
                if (murajaAssignment != null && murajaAssignment.isNotEmpty) ...[
                  _buildInfoRow('تكليف المراجعة', murajaAssignment),
                  const SizedBox(height: 8),
                ],
                if (sessionRating != null && sessionRating > 0) ...[
                  Row(
                    children: [
                      const Text(
                        'التقييم: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      ...List.generate(
                        10,
                        (index) => Icon(
                          index < sessionRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$sessionRating/10'),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (sessionNotes != null && sessionNotes.isNotEmpty) ...[
                  _buildInfoRow('الملاحظات', sessionNotes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
