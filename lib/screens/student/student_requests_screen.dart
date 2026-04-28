// lib/screens/student_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../providers/booking_provider.dart';
import '../../providers/session_provider_paginated.dart';
import '../../providers/user_provider.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';
import 'direct_payment_screen.dart';

// ============================================================================
// FILTER ENUM AND PROVIDER
// ============================================================================
enum RequestFilter {
  all,
  pending,
  accepted,
  rejected,
  cancelled,
  awaitingPayment,
}

final requestFilterProvider =
    StateProvider<RequestFilter>((ref) => RequestFilter.all);

// ============================================================================
// MAIN SCREEN
// ============================================================================
class StudentRequestsScreen extends ConsumerStatefulWidget {
  const StudentRequestsScreen({super.key});

  @override
  ConsumerState<StudentRequestsScreen> createState() =>
      _StudentRequestsScreenState();
}

class _StudentRequestsScreenState extends ConsumerState<StudentRequestsScreen> {
  final searchController = TextEditingController();
  String searchQuery = '';

  Future<void> _refreshRequests(String studentId) async {
    ref.invalidate(studentRequestsFirstPageProvider(studentId));
    await ref
        .read(studentRequestsFirstPageProvider(studentId).future)
        .catchError((_) => <Map<String, dynamic>>[]);
  }

  /// Returns true only when the student still needs to initiate payment.
  /// NOTE: 'awaitingdirectpaymentconfirmation' is intentionally excluded —
  /// the student already sent the payment, so no "Pay Now" button is needed.
  /// FIX: Subscription-credit requests NEVER require student payment action
  bool _requiresPayment(Map<String, dynamic> request) {
    final status = (request['status'] as String? ?? '').toLowerCase();
    final selectedPaymentMethod = request['selectedPaymentMethod'] as String? ?? '';

    // Subscription-credit requests NEVER require student payment action
    if (selectedPaymentMethod == 'subscriptioncredit') return false;

    return status == 'awaitingpayment' ||
        status == 'awaiting_payment' ||
        status == 'awaitingdirectpayment';
  }

  // ── Navigate to payment ──────────────────────────────────────────────────
  Future<void> _navigateToPayment(Map<String, dynamic> request) async {
    try {
      final requestId =
          request['id'] as String? ?? request['requestId'] as String?;
      final mohaffezId = request['mohaffezId'] as String?;

      if (requestId == null || mohaffezId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بيانات الطلب غير مكتملة'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
        return;
      }

      final mohaffezName = request['mohaffezName'] as String? ?? '';

      // Fetch fresh Firestore data to get selectedPaymentMethod and latest
      // slot details written by the teacher on acceptance.
      Map<String, dynamic> lockedRequest = Map<String, dynamic>.from(request);
      try {
        final snap = await FirebaseFirestore.instance
            .collection('sessionRequests')
            .doc(requestId)
            .get();
        if (snap.exists && snap.data() != null) {
          lockedRequest = Map<String, dynamic>.from(snap.data()!);
        }
      } catch (_) {
        // Fall back to in-memory map
      }

      if (!context.mounted) return;

      // ── KEY FIX: Route based on payment method ─────────────────────────
      // Requests created via "Request First" flow (DirectBookingRequestScreen)
      // have selectedPaymentMethod = 'directpayment'.  These must go to
      // DirectPaymentScreen (cash/wallet mark-as-paid), NOT StudentPaymentScreen
      // which shows Paymob plan selection.
      final selectedPaymentMethod =
          lockedRequest['selectedPaymentMethod'] as String?;

      if (selectedPaymentMethod == 'directpayment') {
        _openDirectPaymentScreen(
          requestId: requestId,
          mohaffezId: mohaffezId,
          mohaffezName: mohaffezName,
          lockedRequest: lockedRequest,
        );
        return;
      }

      // ── Original flow: plan selection + Paymob / online gateway ─────────
      if (!mounted) return;
      context.push(
        '/payment/$mohaffezId',
        extra: {
          'lockedRequest': lockedRequest,
        },
      );
    } catch (e, st) {
      debugPrint('navigateToPayment error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    }
  }

  /// Routes to [DirectPaymentScreen] with all slot data extracted from the
  /// accepted request.  Called only when selectedPaymentMethod = 'directpayment'.
  void _openDirectPaymentScreen({
    required String requestId,
    required String mohaffezId,
    required String mohaffezName,
    required Map<String, dynamic> lockedRequest,
  }) {
    // Converts Firestore Timestamp or ISO String to DateTime
    DateTime? toDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    context.push(
      '/booking/direct-payment',
      extra: {
        'requestId': requestId,
        'mohaffezId': mohaffezId,
        'mohaffezName': mohaffezName,
        'sessionType': lockedRequest['sessionType'] as String?,
        'preferredTimeSlot': lockedRequest['preferredTimeSlot'] as String? ??
            lockedRequest['timeSlot'] as String?,
        'slotDate': toDate(lockedRequest['slotDate']),
        'slotStart': toDate(lockedRequest['slotStart']),
        'slotEnd': toDate(lockedRequest['slotEnd']),
        'imamAddressText': lockedRequest['imamAddressText'] as String? ??
            lockedRequest['location'] as String?,
        'imamAddressLat':
            (lockedRequest['imamAddressLat'] as num?)?.toDouble(),
        'imamAddressLng':
            (lockedRequest['imamAddressLng'] as num?)?.toDouble(),
        'mohaffezPhone': lockedRequest['mohaffezPhone'] as String?,
        'planType': lockedRequest['planType'] as String?,
        'planId': lockedRequest['planId'] as String?,
        'planTitle': lockedRequest['planTitle'] as String?,
        'sessionsCount': lockedRequest['sessionsCount'] as int?,
        'validityDays': lockedRequest['validityDays'] as int?,
      },
    );
  }

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
    final requestsAsync =
        ref.watch(studentRequestsFirstPageProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => _refreshRequests(studentId),
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context, ref, filter, studentId),
              _buildSearchBar(),
              _buildFilterChips(ref, filter),
              _buildRequestsList(
                  context, ref, studentId, requestsAsync, filter),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // APP BAR
  // ==========================================================================
  Widget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    RequestFilter filter,
    String studentId,
  ) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppThemeConstants.deepTeal,
      surfaceTintColor: AppThemeConstants.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppThemeConstants.tealGradient,
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
                          color: AppThemeConstants.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.request_page,
                            size: 24, color: AppThemeConstants.white),
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
                                color: AppThemeConstants.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'إدارة طلبات الحجز',
                              style: TextStyle(
                                  fontSize: 13, color: AppThemeConstants.white70),
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
            setState(() => searchQuery = value.toLowerCase().trim());
          },
          decoration: InputDecoration(
            hintText: 'البحث في الطلبات...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      searchController.clear();
                      setState(() => searchQuery = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppThemeConstants.grey100,
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
      child: SizedBox(
        height: 50,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final (filter, label, icon) = filters[index];
            final isSelected = selectedFilter == filter;
            return ChoiceChip(
              avatar: Icon(icon,
                  size: 18,
                  color: isSelected ? AppThemeConstants.white : AppThemeConstants.grey700),
              label: Text(label),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(requestFilterProvider.notifier).state = filter,
              selectedColor: AppThemeConstants.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppThemeConstants.white : AppThemeConstants.grey700,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
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
        var filteredRequests = _applyFilters(allRequests, filter);

        if (searchQuery.isNotEmpty) {
          filteredRequests = filteredRequests.where((req) {
            final mohaffezName =
                (req['mohaffezName'] as String? ?? '').toLowerCase();
            final sessionType =
                (req['sessionType'] as String? ?? '').toLowerCase();
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
                  onPayNow: _requiresPayment(request)
                      ? () => _navigateToPayment(request)
                      : null,
                );
              },
              childCount: filteredRequests.length,
            ),
          ),
        );
      },
      loading: () =>
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverFillRemaining(
        child: ErrorDisplay.dataLoad(
          onRetry: () =>
              ref.invalidate(studentRequestsFirstPageProvider(studentId)),
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
      case RequestFilter.accepted:
        return requests.where((r) => r['status'] == 'accepted').toList();
      case RequestFilter.rejected:
        return requests.where((r) => r['status'] == 'rejected').toList();
      case RequestFilter.cancelled:
        return requests.where((r) => r['status'] == 'cancelled').toList();
      case RequestFilter.awaitingPayment:
        return requests.where((r) {
          final s = r['status'] as String? ?? '';
          return s == 'awaitingpayment' ||
              s == 'awaiting_payment' ||
              s == 'awaitingdirectpayment' ||
              // also show "sent payment, awaiting teacher confirm" here
              s == 'awaitingdirectpaymentconfirmation' ||
              s == 'awaiting_direct_payment_confirmation';
        }).toList();
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

    final canCancel = [
      'pending',
      'awaitingpayment',
      'awaiting_payment',
      'accepted',
      'awaitingdirectpaymentconfirmation',
      'awaiting_direct_payment_confirmation',
    ].contains(status);

    if (!canCancel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إلغاء هذا الطلب في حالته الحالية'),
          backgroundColor: AppThemeConstants.warning,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الإلغاء'),
          content: const Text(
            'هل أنت متأكد من إلغاء هذا الطلب؟\n'
            'سيتم إخطار المحفظ وإعادة فتح الموعد للحجز.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppThemeConstants.error),
              child: const Text('إلغاء الطلب',
                  style: TextStyle(color: AppThemeConstants.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final bookingService = ref.read(bookingServiceProvider);
      final result = await bookingService.cancelSessionRequest(requestId);

      if (result.isSuccess) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الطلب بنجاح'),
              backgroundColor: AppThemeConstants.success,
            ),
          );
        }
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
            backgroundColor: AppThemeConstants.error,
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
  final VoidCallback? onPayNow;

  const _RequestCard({
    required this.request,
    required this.onCancel,
    this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    final mohaffezName = request['mohaffezName'] as String? ?? 'غير معروف';
    final sessionType = request['sessionType'] as String? ?? '';
    final status = (request['status'] as String? ?? 'pending').toLowerCase();
    final preferredTimeSlot = request['preferredTimeSlot'] as String? ??
        request['timeSlot'] as String? ??
        '08:00';
    final createdAt = request['createdAt'] is Timestamp
        ? (request['createdAt'] as Timestamp).toDate()
        : request['createdAt'] as DateTime?;
    final slotDate = request['slotDate'] is Timestamp
        ? (request['slotDate'] as Timestamp).toDate()
        : request['slotDate'] as DateTime?;
    final rejectionReason = request['rejectionReason'] as String?;

    final (statusText, statusColor, statusIcon) = _getStatusInfo(status);

    // Normalize: covers both spellings from Firestore
    final isAwaitingDirectConfirmation =
        status == 'awaitingdirectpaymentconfirmation' ||
            status == 'awaiting_direct_payment_confirmation';

    final canCancel = [
      'pending',
      'awaitingpayment',
      'awaiting_payment',
      'accepted',
      'awaitingdirectpaymentconfirmation',
      'awaiting_direct_payment_confirmation',
    ].contains(status);

    if (status == 'rejected') {
      return _RejectedRequestCard(
        mohaffezName: mohaffezName,
        sessionType: sessionType,
        rejectionReason: rejectionReason,
        requestDate: createdAt,
        slotDate: slotDate,
        preferredTimeSlot: preferredTimeSlot,
        onDismiss: onCancel,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Status badge + Cancel ────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              if (canCancel && !isAwaitingDirectConfirmation)
                IconButton(
                  icon:
                      const Icon(Icons.cancel_outlined, color: AppThemeConstants.error),
                  onPressed: onCancel,
                  tooltip: 'إلغاء الطلب',
                ),
            ]),
            const SizedBox(height: 12),

            // ── Mohaffez Name ───────────────────────────────────────────
            Text(
              mohaffezName,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // ── Session type + time chips ───────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDetailChip(Icons.schedule, preferredTimeSlot),
                _buildDetailChip(Icons.location_on,
                    _getSessionTypeLabel(sessionType)),
              ],
            ),
            const SizedBox(height: 12),

            // ── Date row ────────────────────────────────────────────────
            Row(children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: AppThemeConstants.grey600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  slotDate != null
                      ? 'الموعد: ${DateFormat('dd/MM/yyyy', 'ar').format(slotDate)}'
                      : 'التاريخ غير محدد',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppThemeConstants.grey700),
                ),
              ),
              Flexible(
                child: Text(
                  createdAt != null
                      ? 'طُلب ${DateFormat('dd/MM', 'ar').format(createdAt)}'
                      : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppThemeConstants.grey500),
                ),
              ),
            ]),

            // ── PAY NOW BUTTON ───────────────────────────────────────────
            if (onPayNow != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPayNow,
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('ادفع الآن'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.secondary,
                    foregroundColor: AppThemeConstants.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],

            // ── AWAITING DIRECT PAYMENT CONFIRMATION ─────────────────────
            // Shown when student has already sent payment and is waiting
            // for the teacher to confirm receipt.
            // FIX: Handles both Firestore spellings (with and without underscores)
            if (isAwaitingDirectConfirmation) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppThemeConstants.accentBlueLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppThemeConstants.accentBlue),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.hourglass_top,
                        color: AppThemeConstants.accentBlueDark, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تم إرسال إشعار الدفع بنجاح ✅',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppThemeConstants.accentBlueDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'في انتظار تأكيد المعلم باستلام المبلغ.'
                            ' ستصلك إشعار فور التأكيد.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppThemeConstants.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined,
                    color: AppThemeConstants.error, size: 18),
                label: const Text('إلغاء الطلب',
                    style: TextStyle(color: AppThemeConstants.error)),
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
        color: AppThemeConstants.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppThemeConstants.grey700),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppThemeConstants.grey800)),
        ],
      ),
    );
  }

  (String, Color, IconData) _getStatusInfo(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return ('قيد الانتظار', AppThemeConstants.warning, Icons.pending);
      case 'awaitingpayment':
      case 'awaiting_payment':
        return ('في انتظار الدفع', AppThemeConstants.primary,
            Icons.payment);
      case 'awaitingdirectpayment':
        return ('في انتظار الدفع', AppThemeConstants.primary,
            Icons.payment);
      case 'awaitingdirectpaymentconfirmation':
      case 'awaiting_direct_payment_confirmation':
        return ('في انتظار تأكيد المعلم', AppThemeConstants.accentBlue,
            Icons.hourglass_top);
      case 'accepted':
      case 'confirmed':
        return ('مقبول', AppThemeConstants.success, Icons.check_circle);
      case 'rejected':
      case 'declined':
        return ('مرفوض', AppThemeConstants.error, Icons.cancel);
      case 'cancelled':
      case 'canceled':
        return ('ملغي', AppThemeConstants.grey500, Icons.block);
      case 'completed':
      case 'done':
        return ('مكتمل', AppThemeConstants.accentPurple, Icons.done_all);
      case 'expired':
        return ('منتهي', AppThemeConstants.accentRed, Icons.timer_off);
      default:
        debugPrint('⚠️ Unknown request status: "$status"');
        return ('غير معروف', AppThemeConstants.grey500, Icons.help_outline);
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
        return type.isNotEmpty ? type : 'غير محدد';
    }
  }
}

// ============================================================================
// REJECTED REQUEST CARD WIDGET
// ============================================================================
class _RejectedRequestCard extends StatelessWidget {
  final String mohaffezName;
  final String sessionType;
  final String? rejectionReason;
  final DateTime? requestDate;
  final DateTime? slotDate;
  final String preferredTimeSlot;
  final VoidCallback onDismiss;

  const _RejectedRequestCard({
    required this.mohaffezName,
    required this.sessionType,
    required this.rejectionReason,
    required this.requestDate,
    required this.slotDate,
    required this.preferredTimeSlot,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: AppThemeConstants.errorLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppThemeConstants.accentRed, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppThemeConstants.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel, size: 16, color: AppThemeConstants.error),
                    SizedBox(width: 6),
                    Text('مرفوض',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppThemeConstants.error)),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppThemeConstants.grey500),
                onPressed: onDismiss,
                tooltip: 'حذف',
              ),
            ]),
            const SizedBox(height: 12),
            Text(mohaffezName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDetailChip(Icons.schedule, preferredTimeSlot),
                _buildDetailChip(Icons.location_on,
                    _getSessionTypeLabel(sessionType)),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: AppThemeConstants.grey600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  slotDate != null
                      ? 'الموعد: ${DateFormat('dd/MM/yyyy', 'ar').format(slotDate!)}'
                      : 'التاريخ غير محدد',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppThemeConstants.grey700),
                ),
              ),
              Flexible(
                child: Text(
                  requestDate != null
                      ? 'طُلب ${DateFormat('dd/MM', 'ar').format(requestDate!)}'
                      : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppThemeConstants.grey500),
                ),
              ),
            ]),
            if (rejectionReason != null &&
                rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppThemeConstants.primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppThemeConstants.primary
                          .withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      color: AppThemeConstants.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'السبب: $rejectionReason',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppThemeConstants.primary),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppThemeConstants.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppThemeConstants.grey700),
          const SizedBox(width: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, color: AppThemeConstants.grey800)),
        ],
      ),
    );
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
