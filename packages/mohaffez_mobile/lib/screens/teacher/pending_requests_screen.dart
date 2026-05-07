// lib/screens/pending_requests_screen.dart
import 'dart:ui' as ui;
import 'package:mohaffez_core/mohaffez_core.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';
import '../../shared/utils/time_formatter.dart';

import '../../shared/widgets/request_payment_type_badge.dart';

// FIX Bug 1: import BookingPaymentMethod so we can reference
// BookingPaymentMethod.subscriptionCredit.value ('subscription_credit')
// instead of the hard-coded typo 'subscriptioncredit'.

class PendingRequestsScreen extends ConsumerStatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  ConsumerState<PendingRequestsScreen> createState() =>
      _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends ConsumerState<PendingRequestsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';
  final Map<String, bool> _isLoadingAccept = {};

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
                    hintText: ArabicLabels.searchStudents,
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
                    fillColor: AppThemeConstants.background,
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
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppThemeConstants.deepTeal,
      surfaceTintColor: AppThemeConstants.transparent,
      title: const Text('الطلبات المعلقة'),
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
                          color:
                              AppThemeConstants.surface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pending_actions,
                          size: 28,
                          color: AppThemeConstants.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الطلبات المعلقة',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppThemeConstants.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'طلبات تحتاج موافقتك',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppThemeConstants.onPrimary
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final count = ref
                              .watch(pendingRequestsCountProvider(mohaffezId));
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              count.toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppThemeConstants.warning,
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
              onTap: () => setState(
                  () => _selectedFilter = RequestStatus.awaitingDirectPayment),
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
            final status = (r['status'] as String? ?? '').toLowerCase();
            return status == _selectedFilter;
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((r) {
            final name = (r['studentName'] as String? ?? '').toLowerCase();
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
                return _PendingRequestCard(
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
    // Loading guard - prevents double-tap per request
    if (_isLoadingAccept[requestId] == true) return;
    setState(() => _isLoadingAccept[requestId] = true);

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
    final bool isSubscriptionCredit = (selectedPaymentMethod ==
                BookingPaymentMethod.subscriptionCredit.value ||
            planType == 'bundle' ||
            planType == 'subscription') &&
        subscriptionId != null;

    if (isSubscriptionCredit) {
      // FIX: removed subscriptionId parameter — CF reads it from Firestore.
      await _confirmSubscriptionSession(data);
      if (mounted) setState(() => _isLoadingAccept[requestId] = false);
      return;
    }

    // awaitingDirectPayment: navigate to the confirmations screen.
    if (status == RequestStatus.awaitingDirectPayment) {
      final directPaymentRequestId = data['directPaymentRequestId'] as String?;
      if (!mounted) {
        setState(() => _isLoadingAccept[requestId] = false);
        return;
      }
      if (directPaymentRequestId != null && directPaymentRequestId.isNotEmpty) {
        context.push(
          '/mohaffez/requests/confirm?directPaymentRequestId=$directPaymentRequestId',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم العثور على معرف طلب الدفع'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
      setState(() => _isLoadingAccept[requestId] = false);
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
      setState(() => _isLoadingAccept[requestId] = false);
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
              backgroundColor: AppThemeConstants.secondary,
            ),
            child: const Text(ArabicLabels.accept),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _isLoadingAccept[requestId] = false);
      return;
    }

    try {
      await ref
          .read(sessionActionsProvider.notifier)
          .acceptRequestAndCreateSession(requestId);

      if (!mounted) return;

      final mohaffezId = ref.read(currentUserProvider).value?.uid ?? '';
      ref.invalidate(pendingRequestsFirstPageProvider(mohaffezId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول الطلب بنجاح ✓'),
          backgroundColor: AppThemeConstants.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingAccept[requestId] = false);
    }
  }

  // ─── Reject Handler ───────────────────────────────────────────────────────

  Future<void> _handleReject(String requestId) async {
    final reasonController = TextEditingController();

    try {
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.error),
              child: const Text(ArabicLabels.reject),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

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
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } finally {
      reasonController.dispose();
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
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
      return;
    }

    // Capture the root navigator BEFORE any async gap.
    // showDialog() uses the root navigator (useRootNavigator: true by default).
    // Navigator.of(context) after an await targets the nearest navigator (the
    // GoRouter shell), which is a different object — so pop() was a no-op and
    // the dialog stayed on screen forever.
    final rootNav = Navigator.of(context, rootNavigator: true);

    void dismissDialog() {
      if (rootNav.canPop()) rootNav.pop();
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final callable = FirebaseFunctions.instance.httpsCallable(
        'confirmSubscriptionSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call({
        'requestId': request['id'] as String,
        'mohaffezId': currentUser.uid,
        'mohaffezName': request['mohaffezName'] as String? ?? '',
      });

      dismissDialog();

      final data = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};

      if (!mounted) return;

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول الجلسة بنجاح ✓'),
            backgroundColor: AppThemeConstants.success,
            duration: Duration(seconds: 3),
          ),
        );
        ref.invalidate(pendingRequestsFirstPageProvider(currentUser.uid));
        context.go('/pending-requests');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] as String? ?? 'فشل تأكيد الجلسة'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      dismissDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'خطأ في تأكيد الجلسة'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } catch (e) {
      dismissDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: AppThemeConstants.error,
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
    return InkWell(
      onTap: isSelected ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeConstants.primary
              : AppThemeConstants.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppThemeConstants.primary
                : AppThemeConstants.outline,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppThemeConstants.primary.withValues(alpha: 0.2),
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
                color: isSelected
                    ? AppThemeConstants.onPrimary
                    : AppThemeConstants.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppThemeConstants.onPrimary
                    : AppThemeConstants.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Info Helper
// ─────────────────────────────────────────────────────────────────────────────

class _StatusInfo {
  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final String label;

  const _StatusInfo({
    required this.color,
    required this.backgroundColor,
    required this.icon,
    required this.label,
  });

  static _StatusInfo fromStatus(String status) {
    final isConfirmed = status == RequestStatus.confirmed;
    final isAwaitingDirectConfirm =
        status == RequestStatus.awaitingDirectPayment;
    final isAwaitingPayment = status == RequestStatus.awaitingPayment;

    if (isConfirmed) {
      return const _StatusInfo(
        color: AppThemeConstants.success,
        backgroundColor: AppThemeConstants.successBackground,
        icon: Icons.check_circle,
        label: 'تم القبول',
      );
    } else if (isAwaitingDirectConfirm) {
      return _StatusInfo(
        color: AppThemeConstants.info,
        backgroundColor: AppThemeConstants.info.withValues(alpha: 0.1),
        icon: Icons.payments_outlined,
        label: 'في انتظار تأكيد الدفع المباشر',
      );
    } else if (isAwaitingPayment) {
      return const _StatusInfo(
        color: AppThemeConstants.warning,
        backgroundColor: AppThemeConstants.warningBackground,
        icon: Icons.payment,
        label: 'في انتظار الدفع',
      );
    } else {
      return _StatusInfo(
        color: AppThemeConstants.textSecondary,
        backgroundColor: AppThemeConstants.textSecondary.withValues(alpha: 0.1),
        icon: Icons.pending,
        label: 'قيد المراجعة',
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Request Card
// ─────────────────────────────────────────────────────────────────────────────

class _PendingRequestCard extends ConsumerWidget {
  final Map<String, dynamic> request;
  final String requestId;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingRequestCard({
    required this.request,
    required this.requestId,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = (request['status'] as String? ?? '').toLowerCase();
    final statusInfo = _StatusInfo.fromStatus(status);
    final studentName = request['studentName'] as String? ?? 'غير معروف';
    final studentAge = (request['studentAge'] as num?)?.toInt();
    final sessionType = request['sessionType'] as String? ?? '';
    final location = request['location'] as String? ?? '';

    final planType = request['planType'] as String?;
    final sessionsCount = request['sessionsCount'] as int?;
    final planTitle = request['planTitle'] as String?;
    final isBundlePlan = planType == 'bundle' || planType == 'subscription';

    DateTime? sessionDate;
    final dateField = request['sessionDate'] ?? request['slotDate'];
    sessionDate = _asDateTime(dateField);

    final timeSlot = request['preferredTimeSlot'] as String? ??
        request['timeSlot'] as String? ??
        '';

    final isAwaitingPayment = status == RequestStatus.awaitingPayment;
    final isAwaitingDirectConfirm =
        status == RequestStatus.awaitingDirectPayment;
    final isAnyPaymentState = isAwaitingPayment || isAwaitingDirectConfirm;
    final isConfirmed = status == RequestStatus.confirmed;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: AppThemeConstants.elevationSm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusInfo.color.withValues(alpha: 0.2),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusInfo.backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusInfo.color,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusInfo.icon,
                        size: 16,
                        color: statusInfo.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusInfo.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusInfo.color,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: planType == 'subscription'
                          ? AppThemeConstants.info.withValues(alpha: 0.1)
                          : AppThemeConstants.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: planType == 'subscription'
                            ? AppThemeConstants.info
                            : AppThemeConstants.warning,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_membership,
                          size: 13,
                          color: planType == 'subscription'
                              ? AppThemeConstants.info
                              : AppThemeConstants.warning,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          planType == 'subscription' ? 'اشتراك' : 'حزمة',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: planType == 'subscription'
                                ? AppThemeConstants.info
                                : AppThemeConstants.warning,
                          ),
                        ),
                        if (planTitle != null && planTitle.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(
                            '· $planTitle',
                            style: TextStyle(
                              fontSize: 11,
                              color: planType == 'subscription'
                                  ? AppThemeConstants.info
                                      .withValues(alpha: 0.7)
                                  : AppThemeConstants.warning
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                        const SizedBox(width: 5),
                        Text(
                          '${sessionsCount ?? 0} جلسة',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppThemeConstants.textSecondary),
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
                  color: AppThemeConstants.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppThemeConstants.info.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.payments_outlined,
                      color: AppThemeConstants.info, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الطالب أرسل إشعار دفع مباشر — اذهب لـ "تأكيد المدفوعات" لقبوله أو رفضه',
                      style: TextStyle(
                          fontSize: 13, color: AppThemeConstants.info),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final dpId = request['directPaymentRequestId'] as String?;
                    if (dpId != null && dpId.isNotEmpty) {
                      context.push(
                        '/mohaffez/requests/confirm?directPaymentRequestId=$dpId',
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline,
                      color: AppThemeConstants.onPrimary),
                  label: const Text('تأكيد الدفع المباشر',
                      style: TextStyle(
                          color: AppThemeConstants.onPrimary,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.info,
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

            if (studentAge != null) _buildDetailRow('العمر', '$studentAge سنة'),
            if (studentAge != null) const SizedBox(height: 8),

            if (sessionDate != null)
              _buildDetailRow(
                ArabicLabels.date,
                DateFormat('dd/MM/yyyy', 'ar').format(sessionDate),
              ),
            const SizedBox(height: 8),

            if (timeSlot.isNotEmpty)
              _buildDetailRow(
                  ArabicLabels.time, formatTimeToArabicAmPm(timeSlot)),
            const SizedBox(height: 8),

            if (location.isNotEmpty)
              _buildDetailRow(ArabicLabels.location, location),

            if (request['paymentAmount'] != null &&
                (request['paymentAmount'] as num) > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.payment,
                      size: 16, color: AppThemeConstants.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${request['planTitle'] ?? 'خطة دفع'} — '
                      '${(request['paymentAmount'] as num).toStringAsFixed(0)} جنيه',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppThemeConstants.success,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

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
                      foregroundColor: AppThemeConstants.error,
                      side: const BorderSide(color: AppThemeConstants.error),
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
                      isAnyPaymentState ? Icons.info_outline : Icons.check,
                      size: 18,
                    ),
                    label: Text(
                      isAnyPaymentState ? 'التفاصيل' : ArabicLabels.accept,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAwaitingDirectConfirm
                          ? AppThemeConstants.info
                          : isAwaitingPayment
                              ? AppThemeConstants.warning
                              : AppThemeConstants.secondary,
                      foregroundColor: AppThemeConstants.onPrimary,
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
        Text(
          '$label:',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppThemeConstants.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 14)),
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
}
