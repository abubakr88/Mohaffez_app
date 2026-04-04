// lib/screens/pending_requests_screen.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../shared/constants/app_theme.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/widgets/request_payment_type_badge.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../models/request_status.dart';
import '../utils/arabic_labels.dart';
import 'direct_payment_confirmations_screen.dart';

// FIX Bug 1: import BookingPaymentMethod so we can reference
// BookingPaymentMethod.subscriptionCredit.value ('subscription_credit')
// instead of the hard-coded typo 'subscriptioncredit'.
import '../providers/booking_provider.dart';

class PendingRequestsScreen extends ConsumerStatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  ConsumerState<PendingRequestsScreen> createState() =>
      _PendingRequestsScreenState();
}

class _PendingRequestsScreenState
    extends ConsumerState<PendingRequestsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';
  bool _isLoadingAccept = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildAppBar(user.uid),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase().trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث عن طالب...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
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
            ),
            SliverToBoxAdapter(child: _buildFilterChips()),
            _buildRequestsList(user.uid),
          ],
        ),
      ),
    );
  }

  // ─── App Bar ─────────────────────────────────────────────────────────────

  Widget _buildAppBar(String mohaffezId) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppThemeConstants.primaryAmber,
                AppThemeConstants.primaryAmberLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pending_actions,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الطلبات المعلقة',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'طلبات تحتاج موافقتك',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final count = ref.watch(
                              pendingRequestsCountProvider(mohaffezId));
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              count.toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          );
                        },
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

  // ─── Filter Chips ─────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: ArabicLabels.all,
              icon: Icons.all_inclusive,
              isSelected: _selectedFilter == 'all',
              onTap: () => setState(() => _selectedFilter = 'all'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'قيد المراجعة',
              icon: Icons.pending,
              isSelected: _selectedFilter == RequestStatus.pending,
              onTap: () =>
                  setState(() => _selectedFilter = RequestStatus.pending),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'في انتظار الدفع',
              icon: Icons.payment,
              isSelected: _selectedFilter == RequestStatus.awaitingPayment,
              onTap: () => setState(
                  () => _selectedFilter = RequestStatus.awaitingPayment),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'تأكيد الدفع المباشر',
              icon: Icons.payments_outlined,
              isSelected:
                  _selectedFilter == RequestStatus.awaitingDirectPayment,
              onTap: () => setState(() =>
                  _selectedFilter = RequestStatus.awaitingDirectPayment),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Requests List ────────────────────────────────────────────────────────

  Widget _buildRequestsList(String mohaffezId) {
    final requestsAsync =
        ref.watch(pendingRequestsFirstPageProvider(mohaffezId));
    return requestsAsync.when(
      loading: () => const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverFillRemaining(
          child: ErrorDisplay.dataLoad(
              onRetry: () => ref
                  .invalidate(pendingRequestsFirstPageProvider(mohaffezId)))),
      data: (allRequests) {
        var filtered = allRequests;

        if (_selectedFilter != 'all') {
          filtered = filtered.where((r) {
            final status =
                (r['status'] as String? ?? '').toLowerCase();
            if (_selectedFilter == RequestStatus.awaitingPayment) {
              // "في انتظار الدفع" chip shows both payment-waiting states
              return status == RequestStatus.awaitingPayment ||
                  status == RequestStatus.awaitingDirectPayment;
            }
            return status == _selectedFilter;
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((r) {
            final name =
                (r['studentName'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery);
          }).toList();
        }

        if (filtered.isEmpty) {
          return const SliverFillRemaining(
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'لا توجد طلبات',
              message: 'لم يصلك أي طلب حتى الآن',
              animated: true,
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final data = filtered[index];
                final requestId = data['id'] as String;
                return PendingRequestCard(
                  request: data,
                  requestId: requestId,
                  onAccept: () => _handleAccept(requestId, data),
                  onReject: () => _handleReject(requestId),
                );
              },
              childCount: filtered.length,
            ),
          ),
        );
      },
    );
  }

  // ─── Accept Handler ───────────────────────────────────────────────────────

  Future<void> _handleAccept(
      String requestId, Map<String, dynamic> data) async {
    // Loading guard - prevents double-tap
    if (_isLoadingAccept) return;
    setState(() => _isLoadingAccept = true);

    final status = (data['status'] as String? ?? '').toLowerCase();

    // FIX Bug 1: was 'subscriptioncredit' — never matched the stored value
    // 'subscription_credit'. Referencing the enum's .value is now the
    // single source of truth and will stay correct if the enum changes.
    final selectedPaymentMethod =
        data['selectedPaymentMethod'] as String? ?? '';
    final subscriptionId = data['subscriptionId'] as String?;
    final planType = data['planType'] as String? ?? '';

    // Path A: bundle session uses existing subscription credit
    // Check selectedPaymentMethod OR planType for bundle/subscription
    final bool isSubscriptionCredit =
        (selectedPaymentMethod == BookingPaymentMethod.subscriptionCredit.value ||
         planType == 'bundle' ||
         planType == 'subscription') &&
        subscriptionId != null;

    if (isSubscriptionCredit) {
      // FIX: removed subscriptionId parameter — CF reads it from Firestore.
      await _confirmSubscriptionSession(data);
      if (mounted) setState(() => _isLoadingAccept = false);
      return;
    }

    // awaitingDirectPayment: navigate to the confirmations screen.
    if (status == RequestStatus.awaitingDirectPayment) {
      final directPaymentRequestId = data['directPaymentRequestId'] as String?;
      if (!mounted) return;
      if (directPaymentRequestId != null && directPaymentRequestId.isNotEmpty) {
        context.push(
          '/mohaffez/requests/confirm?directPaymentRequestId=$directPaymentRequestId',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم العثور على معرف طلب الدفع'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // awaitingPayment: student hasn't transferred yet — different message.
    if (status == RequestStatus.awaitingPayment) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('في انتظار الدفع'),
          content: const Text(
            'هذا الطلب في انتظار دفع الطالب. سيتم قبوله تلقائياً بعد إتمام الدفع.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(ArabicLabels.ok),
            ),
          ],
        ),
      );
      return;
    }

    // Standard pending → confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد قبول الطلب'),
        content: Text(
          'هل تريد قبول طلب ${data['studentName'] ?? 'الطالب'}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(ArabicLabels.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
            ),
            child: const Text(ArabicLabels.accept),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(sessionActionsProvider.notifier)
          .acceptRequestAndCreateSession(requestId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول الطلب بنجاح ✓'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingAccept = false);
    }
  }

  // ─── Reject Handler ───────────────────────────────────────────────────────

  Future<void> _handleReject(String requestId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى توضيح سبب الرفض:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'مثال: الموعد غير متاح، الجدول ممتلئ...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(ArabicLabels.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(ArabicLabels.reject),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final reason = reasonController.text.trim().isEmpty
          ? 'لم يذكر سبب'
          : reasonController.text.trim();

      await ref
          .read(sessionActionsProvider.notifier)
          .rejectRequest(requestId, reason);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض الطلب'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Subscription Session Confirm ─────────────────────────────────────────
  //
  // FIX: CF now reads ALL session/subscription fields from Firestore.
  // The caller sends only 3 fields:
  //   1. requestId    → CF looks up the sessionRequest doc
  //   2. mohaffezId   → must equal context.auth.uid (permission check)
  //   3. mohaffezName → used in session doc + student notification
  //
  // REMOVED: subscriptionId parameter (CF reads it from the request doc).
  // REMOVED: slotDate/slotStart/slotEnd ISO conversions (CF reads Timestamps).
  // REMOVED: studentId, sessionType, amount, address fields (all from Firestore).
  // FIXED:   mohaffezId now uses currentUser.uid, not request['mohaffezId'],
  //          so the CF permission check (context.auth.uid !== data.mohaffezId)
  //          can never fail due to a stale/mismatched Firestore value.
  Future<void> _confirmSubscriptionSession(
    Map<String, dynamic> request,
  ) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: المستخدم غير مصادق عليه'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            const Center(child: CircularProgressIndicator()),
      );

      final callable = FirebaseFunctions.instance.httpsCallable(
        'confirmSubscriptionSession',
        options:
            HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call({
        'requestId':    request['id'] as String,
        'mohaffezId':   currentUser.uid,
        'mohaffezName': request['mohaffezName'] as String? ?? '',
      });

      // SAFETY: Handle null or non-Map response data gracefully
      if (result.data == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: استجابة فارغة من الخادم'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final data = result.data is Map 
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};
      
      // IMPORTANT: Check mounted BEFORE any navigation
      if (!mounted) return;
      
      // Pop the loading dialog first
      Navigator.of(context).pop();

      if (data['success'] == true) {
        // Show success message first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول الجلسة بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Use post-frame to avoid navigation during disposal
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          
          // Invalidate provider after frame to avoid disposal issues
          ref.invalidate(
            pendingRequestsFirstPageProvider(
                request['mohaffezId'] as String),
          );
          
          // Navigate safely
          if (mounted) {
            context.go('/pending-requests');
          }
        });
      } else {
        // Error from CF - show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'فشل تأكيد الجلسة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      // Check mounted at the start of error handling
      if (!mounted) return;
      
      // Safe pop - check if we can pop first
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'خطأ في تأكيد الجلسة'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // Check mounted at the start of error handling
      if (!mounted) return;
      
      // Safe pop - check if we can pop first
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Chip Widget
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeConstants.primaryAmber : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppThemeConstants.primaryAmber
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppThemeConstants.primaryAmber
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color:
                    isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color:
                    isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Request Card
// ─────────────────────────────────────────────────────────────────────────────

class PendingRequestCard extends ConsumerWidget {
  final Map<String, dynamic> request;
  final String requestId;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const PendingRequestCard({
    super.key,
    required this.request,
    required this.requestId,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = (request['status'] as String? ?? '').toLowerCase();
    final studentName = request['studentName'] as String? ?? 'غير معروف';
    final studentAge = (request['studentAge'] as num?)?.toInt();
    final sessionType = request['sessionType'] as String? ?? '';
    final location = request['location'] as String? ?? '';

    final planType = request['planType'] as String?;
    final sessionsCount = request['sessionsCount'] as int?;
    final planTitle = request['planTitle'] as String?;
    final isBundlePlan =
        planType == 'bundle' || planType == 'subscription';

    DateTime? sessionDate;
    final dateField = request['sessionDate'] ?? request['slotDate'];
    sessionDate = _asDateTime(dateField);

    final timeSlot = request['preferredTimeSlot'] as String? ??
        request['timeSlot'] as String? ??
        '';

    final isAwaitingPayment = status == RequestStatus.awaitingPayment;
    final isAwaitingDirectConfirm =
        status == RequestStatus.awaitingDirectPayment;
    final isAnyPaymentState =
        isAwaitingPayment || isAwaitingDirectConfirm;
    final isConfirmed = status == RequestStatus.confirmed;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isConfirmed
              ? Colors.green.shade200
              : isAwaitingDirectConfirm
                  ? Colors.blue.shade200
                  : isAwaitingPayment
                      ? Colors.orange.shade200
                      : Colors.grey.shade200,
          width: isConfirmed || isAnyPaymentState ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header with status badge ──────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    studentName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isConfirmed
                        ? Colors.green.withValues(alpha: 0.1)
                        : isAwaitingDirectConfirm
                            ? Colors.blue.withValues(alpha: 0.1)
                            : isAwaitingPayment
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isConfirmed
                          ? Colors.green
                          : isAwaitingDirectConfirm
                              ? Colors.blue
                              : isAwaitingPayment
                                  ? Colors.orange
                                  : Colors.grey,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConfirmed
                            ? Icons.check_circle
                            : isAwaitingDirectConfirm
                                ? Icons.payments_outlined
                                : isAwaitingPayment
                                    ? Icons.payment
                                    : Icons.pending,
                        size: 16,
                        color: isConfirmed
                            ? Colors.green
                            : isAwaitingDirectConfirm
                                ? Colors.blue
                                : isAwaitingPayment
                                    ? Colors.orange
                                    : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConfirmed
                            ? 'تم القبول'
                            : isAwaitingDirectConfirm
                                ? 'في انتظار تأكيد الدفع المباشر'
                                : isAwaitingPayment
                                    ? 'في انتظار الدفع'
                                    : 'قيد المراجعة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isConfirmed
                              ? Colors.green
                              : isAwaitingDirectConfirm
                                  ? Colors.blue
                                  : isAwaitingPayment
                                      ? Colors.orange
                                      : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Bundle/Subscription info row ──────────────────────────
            if (isBundlePlan) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: planType == 'subscription'
                          ? Colors.purple.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: planType == 'subscription'
                            ? Colors.purple.shade300
                            : Colors.amber.shade400,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_membership,
                          size: 13,
                          color: planType == 'subscription'
                              ? Colors.purple.shade700
                              : Colors.amber.shade800,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          planType == 'subscription' ? 'اشتراك' : 'حزمة',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: planType == 'subscription'
                                ? Colors.purple.shade700
                                : Colors.amber.shade800,
                          ),
                        ),
                        if (planTitle != null && planTitle.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(
                            '· $planTitle',
                            style: TextStyle(
                              fontSize: 11,
                              color: planType == 'subscription'
                                  ? Colors.purple.shade600
                                  : Colors.amber.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(width: 5),
                        Text(
                          '${sessionsCount ?? 0} جلسة',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // ── Direct-pay notice + quick-navigate button ─────────────
            if (isAwaitingDirectConfirm) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: const Row(children: [
                  Icon(Icons.payments_outlined,
                      color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الطالب أرسل إشعار دفع مباشر — اذهب لـ "تأكيد المدفوعات" لقبوله أو رفضه',
                      style:
                          TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final dpId =
                        request['directPaymentRequestId'] as String?;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DirectPaymentConfirmationsScreen(
                          directPaymentRequestId: dpId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white),
                  label: const Text('تأكيد الدفع المباشر',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],

            // ── Session details ────────────────────────────────────────
            _buildDetailRow(
              ArabicLabels.type,
              ArabicLabels.getSessionTypeLabel(sessionType),
            ),
            const SizedBox(height: 8),

            if (studentAge != null)
              _buildDetailRow('العمر', '$studentAge سنة'),
            if (studentAge != null) const SizedBox(height: 8),

            if (sessionDate != null)
              _buildDetailRow(
                ArabicLabels.date,
                DateFormat('dd/MM/yyyy', 'ar').format(sessionDate),
              ),
            const SizedBox(height: 8),

            if (timeSlot.isNotEmpty)
              _buildDetailRow(ArabicLabels.time, timeSlot),
            const SizedBox(height: 8),

            if (location.isNotEmpty)
              _buildDetailRow(ArabicLabels.location, location),

            if (request['paymentAmount'] != null &&
                (request['paymentAmount'] as num) > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.payment, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${request['planTitle'] ?? 'خطة دفع'} — '
                      '${(request['paymentAmount'] as num).toStringAsFixed(0)} جنيه',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            _buildPaymentTypeInfo(ref),

            const SizedBox(height: 8),
            RequestPaymentTypeBadge(
              requestData: request,
            ),

            // ── Action buttons ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(ArabicLabels.reject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: Icon(
                      isAnyPaymentState
                          ? Icons.info_outline
                          : Icons.check,
                      size: 18,
                    ),
                    label: Text(
                      isAnyPaymentState ? 'التفاصيل' : ArabicLabels.accept,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAwaitingDirectConfirm
                          ? Colors.blue
                          : isAwaitingPayment
                              ? Colors.orange
                              : AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey),
        ),
      ],
    );
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    try {
      final maybeDate = (value as dynamic)?.toDate();
      return maybeDate is DateTime ? maybeDate : null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildPaymentTypeInfo(WidgetRef ref) {
    final paymentType = request['paymentType'] as String?;
    final subscriptionId = request['subscriptionId'] as String?;
    final planType = request['planType'] as String?;

    final isBundleOrSubscription = paymentType == 'bundle' ||
        paymentType == 'subscription' ||
        planType == 'bundle' ||
        planType == 'subscription';

    if (isBundleOrSubscription) {
      if (subscriptionId != null) {
        final bundleAsync = ref.watch(bundleByIdProvider(subscriptionId));
        return bundleAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
          data: (bundle) {
            if (bundle == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.collections_bookmark_outlined,
                          size: 18, color: Colors.green),
                      SizedBox(width: 8),
                      Text('نوع الحجز: باقة',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('اسم الباقة: ${bundle.planTitle}'),
                  Text(
                      'الجلسات المتبقية: ${bundle.remainingSessions} / ${bundle.totalSessions}'),
                ],
              ),
            );
          },
        );
      } else {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.card_membership,
                  size: 18, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Text(
                'نوع الحجز: باقة — في انتظار تأكيد الدفع المباشر',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800),
              ),
            ],
          ),
        );
      }
    }

    // Single direct payment (not a bundle)
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.payment, size: 18, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            'نوع الحجز: دفع مباشر',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}
