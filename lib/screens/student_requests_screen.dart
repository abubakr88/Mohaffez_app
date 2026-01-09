import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/empty_state_illustrations.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider.dart';
import '../providers/user_provider.dart';

class StudentRequestsScreen extends ConsumerWidget {
  const StudentRequestsScreen({super.key});

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
    final requestsAsync = ref.watch(studentRequestsProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('طلباتي')),
        body: requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return IllustratedEmptyState(
                illustration: EmptyStateIllustrations.noRequests(),
                title: 'لا توجد طلبات',
                message: 'لم ترسل أي طلبات حجز بعد.',
                action: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.search),
                  label: const Text('ابحث عن محفظ'),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _RequestCard(request: request);
              },
            );
          },
          loading: () => ShimmerWidgets.list(
            itemCount: 3,
            itemBuilder: () => ShimmerWidgets.listItem(
              showAvatar: true,
              lines: 3,
            ),
          ),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(studentRequestsProvider(studentId)),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final mohaffezName = request.mohaffezName;
    final imamAddress = request.imamAddressText ?? '';
    final status = request.status.toString().split('.').last;
    final sessionType = request.sessionType;
    final slot = request.preferredTimeSlot;
    final slotStart = request.slotStart;
    final createdAt = request.createdAt;

    final baseDate = slotStart ?? createdAt;
    final dateStr = baseDate != null
        ? '${baseDate.day}/${baseDate.month}/${baseDate.year} - ${baseDate.hour.toString().padLeft(2, '0')}:${baseDate.minute.toString().padLeft(2, '0')}'
        : '';

    final statusColor = _getStatusColor(status);
    final statusText = _getStatusLabel(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    mohaffezName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            // Details
            if (sessionType.isNotEmpty && slot.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '$sessionType - $slot',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (imamAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      imamAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Timeline
            Row(
              children: [
                _buildTimelineDot(active: true, color: Colors.orange),
                _buildTimelineLine(),
                _buildTimelineDot(
                  active: status == 'accepted',
                  color: Colors.green,
                ),
                _buildTimelineLine(),
                _buildTimelineDot(
                  active: status == 'rejected',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('تم الإرسال', style: TextStyle(fontSize: 11)),
                const Text('مقبول', style: TextStyle(fontSize: 11)),
                const Text('مرفوض', style: TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: statusColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineDot({required bool active, required Color color}) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: active ? color : Colors.grey.shade300,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? color : Colors.grey.shade400,
          width: 2,
        ),
      ),
    );
  }

  Widget _buildTimelineLine() {
    return Expanded(
      child: Container(
        height: 2,
        color: Colors.grey.shade300,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد الانتظار';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }
}
