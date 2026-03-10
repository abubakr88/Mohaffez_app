// lib/screens/direct_booking_request_screen.dart
//
// WHY THIS SCREEN EXISTS:
//   Path C (direct single-session booking) previously jumped straight to the
//   payment screen, forcing the student to pay before the teacher agreed to
//   the slot.  This screen inserts the missing "request first" step:
//
//   Student sends request  →  Teacher accepts (PendingRequestsScreen)
//     →  Student gets notified  →  Student pays (StudentRequestsScreen → pay-now)
//     →  Teacher confirms receipt (DirectPaymentConfirmationsScreen)
//     →  Session created

import 'dart:ui' as ui;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/user_provider.dart';
import '../shared/theme/app_theme_constants.dart';

class DirectBookingRequestScreen extends ConsumerStatefulWidget {
  const DirectBookingRequestScreen({super.key});

  @override
  ConsumerState<DirectBookingRequestScreen> createState() =>
      _DirectBookingRequestScreenState();
}

class _DirectBookingRequestScreenState
    extends ConsumerState<DirectBookingRequestScreen> {
  bool _submitting = false;

  /// True only after a successful request is sent.
  /// Prevents dispose() from resetting the provider too early during navigation.
  bool _navigatingAway = false;

  @override
  void dispose() {
    // If the user backed out without sending, reset the flow so the slot
    // isn't left in a dirty state for the next booking attempt.
    if (!_navigatingAway) {
      ref.read(bookingFlowProvider.notifier).reset();
    }
    super.dispose();
  }

  // ── Send request ──────────────────────────────────────────────────────────

  Future<void> _sendRequest() async {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    final currentUser = ref.read(currentUserProvider).value;

    if (slotContext == null || currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بيانات الجلسة غير مكتملة، يرجى المحاولة مرة أخرى'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // ✅ Capture messenger BEFORE any await
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
        'studentName': currentUser.name ?? '',
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
        // The CF will create the doc with status = 'pending' so the teacher
        // sees it in PendingRequestsScreen and can accept/reject before
        // the student is asked to transfer money.
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
            content: Text('✅ تم إرسال طلب الحجز — يمكنك متابعة حالته من "طلباتي"'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        context.go('/home');
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'فشل إرسال الطلب'),
            backgroundColor: Colors.red,
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
            content: Text('الطلب مُرسَل بالفعل — تحقق من قائمة طلباتك'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/requests');
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('خطأ: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          backgroundColor: AppThemeConstants.primaryAmber,
          foregroundColor: Colors.white,
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
              // ── Session summary ──────────────────────────────────────────
              _SummaryCard(
                mohaffezName: slotContext.mohaffezName,
                sessionType: slotContext.sessionType,
                timeSlot: slotContext.preferredTimeSlot,
                dateStr: dateStr,
                address: slotContext.imamAddressText,
              ),
              const SizedBox(height: 16),

              // ── Payment method note ──────────────────────────────────────
              _InfoCard(
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.teal,
                title: 'طريقة الدفع',
                body: 'دفع مباشر — كاش أو محفظة إلكترونية\n'
                    'ستصلك أرقام المحفظة بعد موافقة المعلم على الموعد.',
              ),
              const SizedBox(height: 12),

              // ── How it works ─────────────────────────────────────────────
              _InfoCard(
                icon: Icons.info_outline,
                color: AppThemeConstants.primaryAmber,
                title: 'خطوات الحجز',
                body: '١. ترسل الطلب الآن\n'
                    '٢. ينظر المعلم في الطلب ويوافق على الموعد\n'
                    '٣. تصلك إشعار بالموافقة وتفاصيل الدفع\n'
                    '٤. تحول المبلغ وتضغط "دفعت"\n'
                    '٥. المعلم يؤكد الاستلام وتُحجز الجلسة',
              ),
              const SizedBox(height: 32),

              // ── Send button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _sendRequest,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_outlined, color: Colors.white),
                  label: Text(
                    _submitting ? 'جاري الإرسال...' : 'إرسال طلب الحجز',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primaryAmber,
                    disabledBackgroundColor:
                        AppThemeConstants.primaryAmber.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Cancel ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _submitting ? null : () => context.pop(),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
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

class _SummaryCard extends StatelessWidget {
  final String mohaffezName;
  final String sessionType;
  final String timeSlot;
  final String dateStr;
  final String? address;

  const _SummaryCard({
    required this.mohaffezName,
    required this.sessionType,
    required this.timeSlot,
    required this.dateStr,
    this.address,
  });

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

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.assignment_outlined,
                  color: AppThemeConstants.primaryAmber),
              const SizedBox(width: 8),
              const Text(
                'تفاصيل الجلسة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ]),
            const Divider(height: 20),
            _row(Icons.person_outline, 'المعلم', mohaffezName),
            const SizedBox(height: 8),
            _row(Icons.category_outlined, 'نوع الجلسة',
                _translateSessionType(sessionType)),
            const SizedBox(height: 8),
            // LTR wrapper prevents RTL from flipping "08:00 - 09:00" → "09:00 - 08:00"
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('الموعد: ',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
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
            ]),
            const SizedBox(height: 8),
            _row(Icons.calendar_today, 'التاريخ', dateStr),
            if (address != null && address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _row(Icons.location_on_outlined, 'الموقع', address!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(body,
                  style: const TextStyle(fontSize: 13, height: 1.7)),
            ],
          ),
        ),
      ]),
    );
  }
}
