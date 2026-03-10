// lib/screens/confirm_bundle_session_screen.dart

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/user_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../models/slot_context.dart';
import '../models/subscription_model.dart';
import '../shared/theme/app_theme_constants.dart';

class ConfirmBundleSessionScreen extends ConsumerStatefulWidget {
  const ConfirmBundleSessionScreen({super.key});

  @override
  ConsumerState<ConfirmBundleSessionScreen> createState() =>
      _ConfirmBundleSessionScreenState();
}

class _ConfirmBundleSessionScreenState
    extends ConsumerState<ConfirmBundleSessionScreen> {
  
  bool _isLoading = false;
  ActiveBundleInfo? _activeSubscription;
  bool _loadingSubscription = true;
  String? _subscriptionError;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    final currentUser = ref.read(currentUserProvider).value;

    if (slotContext == null || currentUser == null) {
      setState(() {
        _subscriptionError = 'بيانات الجلسة غير مكتملة';
        _loadingSubscription = false;
      });
      return;
    }

    try {
      final repo = ref.read(sessionRepositoryProvider);
      final sub = await repo.getActiveBundle(
        studentId: currentUser.uid,
        mohaffezId: slotContext.mohaffezId,
        sessionType: slotContext.sessionType,
      );

    if (!mounted) return;

    if (sub == null) {
      setState(() {
        _subscriptionError = 'لا توجد باقة نشطة لهذا النوع من الجلسات';
        _loadingSubscription = false;
      });
    } else {
      setState(() {
        _activeSubscription = sub;
        _loadingSubscription = false;
      });
    }
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _subscriptionError = 'حدث خطأ أثناء تحميل الباقة: $e';
      _loadingSubscription = false;
    });
  }
  }

  Future<void> _confirmSession() async {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    final currentUser = ref.read(currentUserProvider).value;
    final sub = _activeSubscription;

    if (slotContext == null || currentUser == null || sub == null) return;

    setState(() => _isLoading = true);

    try {
      final bookingService = ref.read(bookingServiceProvider);
      
      // Parse ISO strings to DateTime
      final slotDate = DateTime.parse(slotContext.slotDate);
      final slotStart = DateTime.parse(slotContext.slotStart);
      final slotEnd = DateTime.parse(slotContext.slotEnd);

      final result = await bookingService.createSessionRequest(
        mohaffezId: slotContext.mohaffezId,
        studentId: currentUser.uid,
        studentName: currentUser.name,
        mohaffezName: slotContext.mohaffezName,
        sessionType: slotContext.sessionType,
        preferredTimeSlot: slotContext.preferredTimeSlot,
        slotDate: slotDate,
        slotStart: slotStart,
        slotEnd: slotEnd,
        imamAddressText: slotContext.imamAddressText,
        imamAddressLat: slotContext.imamAddressLat,
        imamAddressLng: slotContext.imamAddressLng,
        mohaffezPhone: slotContext.mohaffezPhone,
        subscriptionId: sub.id,
        isPaid: true,
        requiresPaymentOnAcceptance: false,
        paymentMethod: BookingPaymentMethod.subscriptionCredit,
        planTitle: sub.planTitle,
        planType: 'bundle',
        sessionsCount: sub.totalSessions,
      );

      if (!mounted) return;

      if (result.success) {
        // Reset the entire booking flow
        ref.read(bookingFlowProvider.notifier).reset();
        
        // Show success then navigate home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الجلسة بنجاح ✓'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'فشل إرسال الطلب، حاول مرة أخرى'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);
    final slotContext = flow.slotContext;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.backgroundLight,
        appBar: AppBar(
          title: const Text('تأكيد الحجز'),
          backgroundColor: AppThemeConstants.primaryAmber,
          foregroundColor: Colors.white,
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: context.pop,
                )
              : null,
        ),
        body: _loadingSubscription
            ? const Center(child: CircularProgressIndicator())
            : _subscriptionError != null
                ? _buildErrorState()
                : slotContext == null
                    ? _buildNoContextState()
                    : _buildContent(slotContext),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _subscriptionError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loadingSubscription = true;
                  _subscriptionError = null;
                });
                _loadSubscription();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoContextState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('لم يتم تحديد موعد الجلسة'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('العودة للرئيسية'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SlotContext slotContext) {
    final sub = _activeSubscription!;
    
    // Parse slot date for display
    DateTime? displayDate;
    try {
      displayDate = DateTime.parse(slotContext.slotDate);
    } catch (_) {}

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeConstants.primaryAmber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeConstants.primaryAmber),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.collections_bookmark_outlined,
                        color: AppThemeConstants.primaryAmber),
                    SizedBox(width: 8),
                    Text(
                      'استخدام باقة حالية',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppThemeConstants.primaryAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Bundle name
                _infoRow(Icons.bookmark_outline, 'اسم الباقة', sub.planTitle),
                const SizedBox(height: 6),
                // Remaining sessions
                _infoRow(
                  Icons.confirmation_number_outlined,
                  'الجلسات المتبقية',
                  '${sub.remainingSessions - 1} من ${sub.totalSessions} (بعد هذه الجلسة)',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Session Details Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تفاصيل الجلسة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(height: 20),
                _infoRow(Icons.person_outline, 'المحفظ', slotContext.mohaffezName),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.category_outlined,
                  'نوع الجلسة',
                  _translateSessionType(slotContext.sessionType),
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.access_time,
                  'الوقت',
                  slotContext.preferredTimeSlot,
                ),
                if (displayDate != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.calendar_today,
                    'التاريخ',
                    DateFormat('EEEE، d MMMM yyyy', 'ar').format(displayDate),
                  ),
                ],
                if (slotContext.imamAddressText != null &&
                    slotContext.imamAddressText!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.location_on_outlined,
                    'العنوان',
                    slotContext.imamAddressText!,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Warning if last session
          if (sub.remainingSessions == 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذه آخر جلسة في باقتك الحالية',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _confirmSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isLoading ? 'جارٍ الإرسال...' : 'تأكيد الحجز',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Cancel Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : context.pop,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('رجوع'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  String _translateSessionType(String type) {
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
