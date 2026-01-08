import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/empty_state_illustrations.dart';

class StudentRequestsScreen extends StatelessWidget {
  const StudentRequestsScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد الانتظار';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('الرجاء تسجيل الدخول')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('طلبات الجلسات')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('sessionRequests')
              .where('studentId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ShimmerWidgets.list(
                itemCount: 3,
                itemBuilder: () => ShimmerWidgets.listItem(
                  showAvatar: true,
                  lines: 3,
                ),
              );
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return IllustratedEmptyState(
                illustration: EmptyStateIllustrations.noRequests(),
                title: 'لا توجد طلبات',
                message: 'قم بالبحث عن محفظين قريبين وأرسل طلب جلسة للبدء.',
                action: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('ابحث عن محفظ'),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final imamName = data['mohaffezName'] as String? ?? '';
                final imamAddress = data['imamAddressText'] as String? ?? '';
                final status = data['status'] as String? ?? 'pending';
                final sessionType = data['sessionType'] as String? ?? '';
                final slot = data['preferredTimeSlot'] as String? ?? '';

                final slotStartTs = data['slotStart'] as Timestamp?;
                final createdTs = data['createdAt'] as Timestamp?;
                final baseDate = slotStartTs?.toDate() ?? createdTs?.toDate();

                final dateStr = baseDate != null
                    ? '${baseDate.day}/${baseDate.month}/${baseDate.year} '
                        '${baseDate.hour.toString().padLeft(2, '0')}:'
                        '${baseDate.minute.toString().padLeft(2, '0')}'
                    : '';

                final statusColor = _statusColor(status);
                final statusText = _statusLabel(status);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                imamName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (sessionType.isNotEmpty || slot.isNotEmpty) ...[
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
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey,
                              ),
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
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey,
                              ),
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
                        
                        // Timeline visualization
                        Row(
                          children: [
                            _buildTimelineDot(
                              active: true,
                              color: Colors.orange,
                            ),
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
                          children: const [
                            Text('مرسل', style: TextStyle(fontSize: 11)),
                            Text('مقبول', style: TextStyle(fontSize: 11)),
                            Text('مرفوض', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                                'الحالة: $statusText',
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
              },
            );
          },
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
