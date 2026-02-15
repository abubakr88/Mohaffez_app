// lib/screens/student_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/booking_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../utils/arabic_labels.dart';

// ============================================================================
// FILTER ENUM AND PROVIDER
// ============================================================================
enum RequestFilter {
  all,           // الكل
  pending,       // قيد الانتظار
  accepted,      // مقبول
  rejected,      // مرفوض
  cancelled,     // ملغي
  awaitingPayment, // في انتظار الدفع
}

final requestFilterProvider = StateProvider<RequestFilter>((ref) => RequestFilter.all);

// ============================================================================
// MAIN SCREEN
// ============================================================================
class StudentRequestsScreen extends ConsumerStatefulWidget {
  const StudentRequestsScreen({super.key});

  @override
  ConsumerState<StudentRequestsScreen> createState() => _StudentRequestsScreenState();
}

class _StudentRequestsScreenState extends ConsumerState<StudentRequestsScreen> {
  final searchController = TextEditingController();
  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final selectedFilter = ref.watch(requestFilterProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('لم يتم تسجيل الدخول')),
          );
        }
        return _buildContent(context, ref, user.uid, selectedFilter);
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

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    String studentId,
    RequestFilter filter,
  ) {
    final requestsAsync = ref.watch(studentRequestsFirstPageProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // App Bar with Filter
            _buildAppBar(context, ref, filter),
            
            // Search Bar
            _buildSearchBar(),
            
            // Filter Chips
            _buildFilterChips(ref, filter),
            
            // Requests List
            _buildRequestsList(context, ref, studentId, requestsAsync, filter),
            
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // APP BAR
  // ==========================================================================
  Widget _buildAppBar(BuildContext context, WidgetRef ref, RequestFilter filter) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryAmber, Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.request_page,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طلباتي',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'إدارة طلبات الحجز',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            final user = ref.read(currentUserProvider).value;
            if (user != null) {
              ref.invalidate(studentRequestsFirstPageProvider(user.uid));
            }
          },
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  // ==========================================================================
  // SEARCH BAR
  // ==========================================================================
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: TextField(
          controller: searchController,
          onChanged: (value) {
            setState(() {
              searchQuery = value.toLowerCase().trim();
            });
          },
          decoration: InputDecoration(
            hintText: 'البحث في الطلبات...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      searchController.clear();
                      setState(() {
                        searchQuery = '';
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // FILTER CHIPS
  // ==========================================================================
  Widget _buildFilterChips(WidgetRef ref, RequestFilter selectedFilter) {
    final filters = [
      (RequestFilter.all, 'الكل', Icons.all_inbox),
      (RequestFilter.pending, 'قيد الانتظار', Icons.pending),
      (RequestFilter.awaitingPayment, 'في انتظار الدفع', Icons.payment),
      (RequestFilter.accepted, 'مقبول', Icons.check_circle),
      (RequestFilter.rejected, 'مرفوض', Icons.cancel),
      (RequestFilter.cancelled, 'ملغي', Icons.block),
    ];

    return SliverToBoxAdapter(
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final (filter, label, icon) = filters[index];
            final isSelected = selectedFilter == filter;
            
            return ChoiceChip(
              avatar: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              label: Text(label),
              selected: isSelected,
              onSelected: (_) {
                ref.read(requestFilterProvider.notifier).state = filter;
              },
              selectedColor: AppTheme.primaryAmber,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // REQUESTS LIST
  // ==========================================================================
  Widget _buildRequestsList(
    BuildContext context,
    WidgetRef ref,
    String studentId,
    AsyncValue<List<Map<String, dynamic>>> requestsAsync,
    RequestFilter filter,
  ) {
    return requestsAsync.when(
      data: (allRequests) {
        // Apply filters
        var filteredRequests = _applyFilters(allRequests, filter);
        
        // Apply search
        if (searchQuery.isNotEmpty) {
          filteredRequests = filteredRequests.where((req) {
            final mohaffezName = (req['mohaffezName'] as String? ?? '').toLowerCase();
            final sessionType = (req['sessionType'] as String? ?? '').toLowerCase();
            return mohaffezName.contains(searchQuery) || 
                   sessionType.contains(searchQuery);
          }).toList();
        }

        if (filteredRequests.isEmpty) {
          return SliverFillRemaining(
            child: EmptyState(
              icon: Icons.inbox,
              title: 'لا توجد طلبات',
              message: _getEmptyMessage(filter),
              animated: true,
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final request = filteredRequests[index];
                return _RequestCard(
                  request: request,
                  onCancel: () => _handleCancel(context, ref, request),
                );
              },
              childCount: filteredRequests.length,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverFillRemaining(
        child: ErrorDisplay.dataLoad(
          onRetry: () => ref.invalidate(studentRequestsFirstPageProvider(studentId)),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> requests,
    RequestFilter filter,
  ) {
    switch (filter) {
      case RequestFilter.all:
        return requests;
      case RequestFilter.pending:
        return requests.where((r) => r['status'] == 'pending').toList();
      case RequestFilter.awaitingPayment:
        return requests.where((r) => r['status'] == 'awaitingpayment').toList();
      case RequestFilter.accepted:
        return requests.where((r) => r['status'] == 'accepted').toList();
      case RequestFilter.rejected:
        return requests.where((r) => r['status'] == 'rejected').toList();
      case RequestFilter.cancelled:
        return requests.where((r) => r['status'] == 'cancelled').toList();
    }
  }

  String _getEmptyMessage(RequestFilter filter) {
    switch (filter) {
      case RequestFilter.all:
        return 'لم تقم بإرسال أي طلبات حجز بعد';
      case RequestFilter.pending:
        return 'لا توجد طلبات قيد الانتظار';
      case RequestFilter.awaitingPayment:
        return 'لا توجد طلبات في انتظار الدفع';
      case RequestFilter.accepted:
        return 'لا توجد طلبات مقبولة';
      case RequestFilter.rejected:
        return 'لا توجد طلبات مرفوضة';
      case RequestFilter.cancelled:
        return 'لا توجد طلبات ملغية';
    }
  }

  // ==========================================================================
  // CANCEL HANDLER
  // ==========================================================================
  Future<void> _handleCancel(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> request,
  ) async {
    final requestId = request['id'] as String?;
    final status = request['status'] as String? ?? 'pending';
    
    if (requestId == null) return;

    // Only allow cancel for certain statuses
    final canCancel = ['pending', 'awaitingpayment', 'accepted'].contains(status);
    if (!canCancel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إلغاء هذا الطلب في حالته الحالية'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الإلغاء'),
          content: const Text(
            'هل أنت متأكد من إلغاء هذا الطلب؟\n'
            'سيتم إخطار المحفظ وإعادة فتح الموعد للحجز.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('إلغاء الطلب'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // Execute cancellation
    try {
      final bookingService = ref.read(bookingServiceProvider);
      final result = await bookingService.cancelSessionRequest(requestId);

      if (result.isSuccess) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الطلب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Refresh the list
        final user = ref.read(currentUserProvider).value;
        if (user != null) {
          ref.invalidate(studentRequestsFirstPageProvider(user.uid));
        }
      } else {
        throw Exception(result.errorMessage ?? 'فشل الإلغاء');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الإلغاء: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ============================================================================
// REQUEST CARD WIDGET
// ============================================================================
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onCancel;

  const _RequestCard({
    required this.request,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final mohaffezName = request['mohaffezName'] as String? ?? 'غير معروف';
    final sessionType = request['sessionType'] as String? ?? '';
    final status = request['status'] as String? ?? 'pending';
    final preferredTimeSlot = request['preferredTimeSlot'] as String? ?? 
                                request['timeSlot'] as String? ?? 
                                '08:00';
    final createdAt = request['createdAt'] as DateTime?;
    final slotDate = request['slotDate'] is Timestamp 
        ? (request['slotDate'] as Timestamp).toDate()
        : request['slotDate'] as DateTime?;

    final (statusText, statusColor, statusIcon) = _getStatusInfo(status);

    final canCancel = ['pending', 'awaitingpayment', 'accepted'].contains(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Status and Cancel Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (canCancel)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    onPressed: onCancel,
                    tooltip: 'إلغاء الطلب',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Mohaffez Name
            Text(
              mohaffezName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Session Details
            Row(
              children: [
                _buildDetailChip(Icons.schedule, preferredTimeSlot),
                const SizedBox(width: 8),
                _buildDetailChip(Icons.location_on, _getSessionTypeLabel(sessionType)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Date Info
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  slotDate != null
                      ? 'الموعد: ${DateFormat('dd/MM/yyyy', 'ar').format(slotDate)}'
                      : 'التاريخ غير محدد',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  createdAt != null
                      ? 'طُلب ${DateFormat('dd/MM', 'ar').format(createdAt)}'
                      : '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            
            // Payment deadline warning (if applicable)
            if (status == 'awaitingpayment') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'يجب الدفع خلال 10 ساعات لتأكيد الحجز',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return ('قيد الانتظار', Colors.orange, Icons.pending);
      case 'awaitingpayment':
        return ('في انتظار الدفع', Colors.blue, Icons.payment);
      case 'accepted':
        return ('مقبول', Colors.green, Icons.check_circle);
      case 'rejected':
        return ('مرفوض', Colors.red, Icons.cancel);
      case 'cancelled':
        return ('ملغي', Colors.grey, Icons.block);
      case 'completed':
        return ('مكتمل', Colors.purple, Icons.done_all);
      default:
        return ('غير معروف', Colors.grey, Icons.help);
    }
  }

  String _getSessionTypeLabel(String type) {
    switch (type) {
      case 'home':
        return 'في المنزل';
      case 'mosque':
        return 'في المسجد';
      case 'online':
        return 'أونلاين';
      default:
        return type;
    }
  }
}