// lib/screens/direct_booking_request_screen.dart
// WHY THIS SCREEN EXISTS: Path C direct single-session booking previously jumped
// straight to the payment screen, forcing the student to pay before the teacher
// agreed to the slot. This screen inserts the missing "request first" step:
//   Student sends request → Teacher accepts (PendingRequestsScreen) →
//   Student gets notified → Student pays (StudentRequestsScreen "pay-now") →
//   Teacher confirms receipt (DirectPaymentConfirmationsScreen) → Session created

import 'dart:ui' as ui;
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DirectBookingRequestScreen extends ConsumerStatefulWidget {
  const DirectBookingRequestScreen({super.key});

  @override
  ConsumerState<DirectBookingRequestScreen> createState() =>
      _DirectBookingRequestScreenState();
}

class _DirectBookingRequestScreenState
    extends ConsumerState<DirectBookingRequestScreen> {
  bool _submitting = false;
  bool _acknowledged = false;

  // True only after a successful request is sent.
  // Prevents dispose from resetting the provider too early during navigation.
  bool _navigatingAway = false;

  // FIX[BUNDLE-ORPHAN]: Cache the notifier reference early — before any disposal can occur.
  // This is the canonical Riverpod pattern for using notifiers in dispose().
  late final BookingFlowNotifier _bookingFlowNotifier;

  @override
  void initState() {
    super.initState();
    // Cache the notifier reference early
    _bookingFlowNotifier = ref.read(bookingFlowProvider.notifier);
  }

  @override
  void dispose() {
    // If the user backed out without sending, reset the flow so the slot
    // isn't left in a dirty state for the next booking attempt.
    if (!_navigatingAway) {
      // ✅ Uses cached reference — no ref access, safe after widget disposal
      _bookingFlowNotifier.reset();
    }
    super.dispose();
  }

  // Send request
  Future<void> sendRequest() async {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    final currentUser = ref.read(currentUserProvider).value;

    if (slotContext == null || currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ. أعد المحاولة'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
      return;
    }

    // Capture messenger BEFORE any await
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable(
            'createSessionRequest',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 30),
            ),
          )
          .call({
        'mohaffezId': slotContext.mohaffezId,
        'mohaffezName': slotContext.mohaffezName,
        'studentName': currentUser.name,
        'sessionType': slotContext.sessionType,
        'preferredTimeSlot': slotContext.preferredTimeSlot,
        'slotDate': slotContext.slotDate,
        'slotStart': slotContext.slotStart,
        'slotEnd': slotContext.slotEnd,
        if (slotContext.imamAddressText?.isNotEmpty == true)
          'imamAddressText': slotContext.imamAddressText,
        if (slotContext.imamAddressLat != null)
          'imamAddressLat': slotContext.imamAddressLat,
        if (slotContext.imamAddressLng != null)
          'imamAddressLng': slotContext.imamAddressLng,
        if (slotContext.mohaffezPhone?.isNotEmpty == true)
          'mohaffezPhone': slotContext.mohaffezPhone,
        // Tells the CF this is a direct-payment request (not free, not Paymob).
        // The CF will create the doc with status 'pending' so the teacher sees it
        // in PendingRequestsScreen and can accept/reject before the student is
        // asked to transfer money.
        'selectedPaymentMethod': 'directpayment',
      });

      if (!mounted) return;

      final data = Map<String, dynamic>.from(result.data as Map);
      final success = data['success'] == true;

      if (success) {
        _navigatingAway = true;
        ref.read(bookingFlowProvider.notifier).reset();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الطلب! سيتم إعلامك عندما يقبل المحفظ'),
            backgroundColor: AppThemeConstants.success,
            duration: Duration(seconds: 5),
          ),
        );
        context.go('/home');
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'فشل إرسال الطلب'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      // Idempotent: if the same request was already sent, treat as success.
      if (e.code == 'already-exists') {
        _navigatingAway = true;
        ref.read(bookingFlowProvider.notifier).reset();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الطلب بالفعل'),
            backgroundColor: AppThemeConstants.warning,
          ),
        );
        context.go('/requests');
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message ?? e.code),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppThemeConstants.error),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Build
  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);
    final slotContext = flow.slotContext;

    // Guard: if slot context was lost (e.g. hot-restart), go home.
    if (slotContext == null) {
      if (!_navigatingAway) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/home');
        });
      }
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final DateTime? slotDate = DateTime.tryParse(slotContext.slotDate);
    final String dateStr = slotDate != null
        ? DateFormat('EEEE d MMMM yyyy', 'ar').format(slotDate)
        : slotContext.slotDate;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إرسال طلب حجز'),
          backgroundColor: AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            tooltip: 'رجوع',
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session summary
              SummaryCard(
                mohaffezName: slotContext.mohaffezName,
                sessionType: slotContext.sessionType,
                timeSlot: slotContext.preferredTimeSlot,
                dateStr: dateStr,
                address: slotContext.imamAddressText,
              ),
              const SizedBox(height: 16),
              // Payment method note
              const InfoCard(
                icon: Icons.account_balance_wallet_outlined,
                color: AppThemeConstants.primary,
                title: 'طريقة الدفع',
                body: 'ستدفع بعد قبول المحفظ للطلب. لا يُطلب منك الدفع الآن.',
              ),
              const SizedBox(height: 12),
              // How it works
              const InfoCard(
                icon: Icons.info_outline,
                color: AppThemeConstants.primary,
                title: 'كيف يعمل؟',
                body:
                    '١. ترسل الطلب.\n٢. يقبل المحفظ.\n٣. تستلم إشعار بالقبول.\n٤. تحوّل المبلغ مباشرة.\n٥. يؤكد المحفظ الاستلام.',
              ),
              const SizedBox(height: 16),
              // Acknowledgment checkbox
              Container(
                decoration: BoxDecoration(
                  color: _acknowledged
                      ? AppThemeConstants.primary.withValues(alpha: 0.08)
                      : AppThemeConstants.grey50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _acknowledged
                        ? AppThemeConstants.primary.withValues(alpha: 0.4)
                        : AppThemeConstants.grey300,
                  ),
                ),
                child: CheckboxListTile(
                  value: _acknowledged,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _acknowledged = v ?? false),
                  activeColor: AppThemeConstants.primary,
                  title: const Text(
                    'أتفهم أنني سأحوّل المبلغ مباشرةً بعد قبول المحفظ للطلب',
                    style: TextStyle(fontSize: 13),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              const SizedBox(height: 20),
              // Send button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_submitting || !_acknowledged) ? null : sendRequest,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: AppThemeConstants.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined, color: AppThemeConstants.white),
                  label: Text(
                    _submitting ? 'جاري الإرسال...' : 'إرسال الطلب',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppThemeConstants.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary,
                    disabledBackgroundColor:
                        AppThemeConstants.primary.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Cancel
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _submitting ? null : () => context.pop(),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: AppThemeConstants.grey500, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class SummaryCard extends StatelessWidget {
  final String mohaffezName;
  final String sessionType;
  final String timeSlot;
  final String dateStr;
  final String? address;

  const SummaryCard({
    required this.mohaffezName,
    required this.sessionType,
    required this.timeSlot,
    required this.dateStr,
    this.address,
    super.key,
  });

  String translateSessionType(String type) {
    switch (type) {
      case 'home':
        return 'منزل';
      case 'mosque':
        return 'مسجد';
      case 'online':
        return 'أونلاين';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.assignment_outlined,
                  color: AppThemeConstants.primary),
              SizedBox(width: 8),
              Text('تفاصيل الجلسة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const Divider(height: 20),
            _row(Icons.person_outline, 'المحفظ: ', mohaffezName),
            const SizedBox(height: 8),
            _row(Icons.category_outlined, 'نوع الجلسة: ',
                translateSessionType(sessionType)),
            const SizedBox(height: 8),
            // LTR wrapper prevents RTL from flipping "08:00-09:00" → "09:00-08:00"
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time, size: 16, color: AppThemeConstants.grey500),
                const SizedBox(width: 8),
                const Text('الوقت: ',
                    style: TextStyle(color: AppThemeConstants.grey500, fontSize: 13)),
                Expanded(
                  child: Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      timeSlot,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row(Icons.calendar_today, 'التاريخ: ', dateStr),
            if (address != null && address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _row(Icons.location_on_outlined, 'العنوان: ', address!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: AppThemeConstants.grey500),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(color: AppThemeConstants.grey500, fontSize: 13)),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13))),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────

class InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color)),
                const SizedBox(height: 4),
                Text(body,
                    style:
                        const TextStyle(fontSize: 13, height: 1.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
