// screens/pending_requests_screen.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../utils/arabic_labels.dart';
import 'direct_payment_confirmations_screen.dart';

class PendingRequestsScreen extends ConsumerStatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  ConsumerState<PendingRequestsScreen> createState() =>
      _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends ConsumerState<PendingRequestsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'pending', 'awaiting_payment'

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
            // App Bar with Counter
            _buildAppBar(user.uid),

            // Search Bar
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
                              setState(() {
                                _searchQuery = '';
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
            ),

            // Filter Chips
            SliverToBoxAdapter(
              child: _buildFilterChips(),
            ),

            // Requests List
            _buildRequestsList(user.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(String mohaffezId) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Color(0xFFFF6F00)],
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
                          color: Colors.white.withOpacity(0.2),
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
                      // Counter Badge - Fixed to include awaiting_payment
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('sessionRequests')
                            .where('mohaffezId', isEqualTo: mohaffezId)
                            .where('status', whereIn: ['pending', 'awaitingpayment', 'awaiting_direct_payment_confirmation'])
                            .snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.docs.length ?? 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
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
              isSelected: _selectedFilter == 'pending',
              onTap: () => setState(() => _selectedFilter = 'pending'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'في انتظار الدفع',
              icon: Icons.payment,
              isSelected: _selectedFilter == 'awaitingpayment',
              onTap: () => setState(() => _selectedFilter = 'awaitingpayment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(String mohaffezId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessionRequests')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', whereIn: ['pending', 'awaitingpayment', 'awaiting_direct_payment_confirmation'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: ErrorDisplay.dataLoad(
              onRetry: () => setState(() {}),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverFillRemaining(
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'لا توجد طلبات معلقة',
              message: 'ستظهر الطلبات الجديدة هنا',
              animated: true,
            ),
          );
        }

        var requests = snapshot.data!.docs;

        // Apply status filter
        if (_selectedFilter != 'all') {
          requests = requests.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] as String? ?? '').toLowerCase();
            
            if (_selectedFilter == 'pending') {
              return status == 'pending';
            } else if (_selectedFilter == 'awaitingpayment') {
              return status == 'awaitingpayment' ||
                  status == 'awaiting_direct_payment_confirmation';
            }
            return true;
          }).toList();
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          requests = requests.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final studentName = (data['studentName'] as String? ?? '').toLowerCase();
            return studentName.contains(_searchQuery);
          }).toList();
        }

        if (requests.isEmpty) {
          return SliverFillRemaining(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'لا توجد نتائج',
              message: 'جرب تغيير الفلتر أو البحث',
              animated: true,
              action: TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedFilter = 'all';
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('مسح الفلاتر'),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final data = requests[index].data() as Map<String, dynamic>;
                final requestId = requests[index].id;
                return PendingRequestCard(
                  request: data,
                  requestId: requestId,
                  onAccept: () => _handleAccept(requestId, data),
                  onReject: () => _handleReject(requestId),
                );
              },
              childCount: requests.length,
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleAccept(String requestId, Map<String, dynamic> data) async {
    final status = (data['status'] as String? ?? '').toLowerCase();
    
    if (status == 'awaiting_direct_payment_confirmation') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('في انتظار تأكيد الدفع المباشر'),
          content: const Text(
            'هذا الطلب بانتظار تأكيد الدفع المباشر من شاشة "تأكيد المدفوعات".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ArabicLabels.ok),
            ),
          ],
        ),
      );
      return;
    }

    // Check if payment is required
    if (status == 'awaitingpayment' || status == 'awaitingpayment') {
      // Show dialog that payment is pending
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
              child: Text(ArabicLabels.ok),
            ),
          ],
        ),
      );
      return;
    }

    // Show confirmation dialog for pending requests
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
            child: Text(ArabicLabels.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
            ),
            child: Text(ArabicLabels.accept),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // ✅ USE PROVIDER: Handles subscription credits, payment deadlines, notifications
      await ref.read(sessionActionsProvider.notifier).acceptRequestAndCreateSession(requestId);

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
    }
  }

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
            child: Text(ArabicLabels.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(ArabicLabels.reject),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final reason = reasonController.text.trim().isEmpty
          ? 'لم يذكر سبب'
          : reasonController.text.trim();
      
      // ✅ USE PROVIDER: Handles slot lock release and notifications
      await ref.read(sessionActionsProvider.notifier).rejectRequest(requestId, reason);

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
}

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PendingRequestCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final status = (request['status'] as String? ?? '').toLowerCase();
    final studentName = request['studentName'] as String? ?? 'غير معروف';
    final sessionType = request['sessionType'] as String? ?? '';
    final location = request['location'] as String? ?? '';
    
    DateTime? sessionDate;
    final dateField = request['sessionDate'] ?? request['slotDate'];
    if (dateField is Timestamp) {
      sessionDate = dateField.toDate();
    } else if (dateField is DateTime) {
      sessionDate = dateField;
    }
    
    final timeSlot = request['preferredTimeSlot'] as String? ??
        request['timeSlot'] as String? ?? '';

    final isAwaitingPayment = status == 'awaitingpayment' || status == 'awaitingpayment';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAwaitingPayment ? Colors.orange.shade200 : Colors.grey.shade200,
          width: isAwaitingPayment ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    studentName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAwaitingPayment
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAwaitingPayment ? Colors.orange : Colors.grey,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAwaitingPayment ? Icons.payment : Icons.pending,
                        size: 16,
                        color: isAwaitingPayment ? Colors.orange : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAwaitingPayment ? 'في انتظار الدفع' : 'قيد المراجعة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAwaitingPayment ? Colors.orange : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (status == 'awaiting_direct_payment_confirmation') ...[
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
                  Icon(Icons.payments_outlined, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الطالب أرسل إشعار دفع مباشر — اذهب لـ "تأكيد المدفوعات" لقبوله أو رفضه',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DirectPaymentConfirmationsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text('تأكيد الدفع المباشر',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],

            // Session details
            _buildDetailRow(
              ArabicLabels.type,
              ArabicLabels.getSessionTypeLabel(sessionType),
            ),
            const SizedBox(height: 8),
            
            if (sessionDate != null)
              _buildDetailRow(
                ArabicLabels.date,
                DateFormat('dd/MM/yyyy', 'ar').format(sessionDate),
              ),
            const SizedBox(height: 8),
            
            if (timeSlot.isNotEmpty)
              _buildDetailRow(
                ArabicLabels.time,
                timeSlot,
              ),
            const SizedBox(height: 8),
            
            if (location.isNotEmpty)
              _buildDetailRow(
                ArabicLabels.location,
                location,
              ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(ArabicLabels.reject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: Icon(
                      isAwaitingPayment ? Icons.info_outline : Icons.check,
                      size: 18,
                    ),
                    label: Text(
                      isAwaitingPayment ? 'التفاصيل' : ArabicLabels.accept,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAwaitingPayment
                          ? Colors.orange
                          : AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
