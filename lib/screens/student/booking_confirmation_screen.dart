import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/booking_provider.dart' show legacyBookingFlowProvider, BookingPaymentMethod;

class BookingConfirmationDetails {
  final String mohaffezId;
  final String studentId;
  final String studentName;
  final String mohaffezName;
  final String sessionType;
  final DateTime slotDate;
  final DateTime slotStart;
  final DateTime slotEnd;
  final String preferredTimeSlot;
  final String location;
  final double? locationLat;
  final double? locationLng;
  final String? mohaffezPhone;
  final BookingPaymentMethod paymentMethod;
  final double cost;
  final String? subscriptionId;
  final int remainingCredits;
  final String? mohaffezPhotoUrl;
  final double rating;
  final int reviewCount;
  final String? slotLockId;
  final String? planId;
  final String? planTitle;
  final double? paymentAmount;
  final int? sessionsCount;
  final String? planType;

  const BookingConfirmationDetails({
    required this.mohaffezId,
    required this.studentId,
    required this.studentName,
    required this.mohaffezName,
    required this.sessionType,
    required this.slotDate,
    required this.slotStart,
    required this.slotEnd,
    required this.preferredTimeSlot,
    required this.location,
    required this.paymentMethod,
    required this.cost,
    required this.remainingCredits,
    this.locationLat,
    this.locationLng,
    this.mohaffezPhone,
    this.subscriptionId,
    this.mohaffezPhotoUrl,
    this.rating = 0,
    this.reviewCount = 0,
    this.slotLockId,
    this.planId,
    this.planTitle,
    this.paymentAmount,
    this.sessionsCount,
    this.planType,
  });
}

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.bookingDetails,
  });

  final BookingConfirmationDetails bookingDetails;

  @override
  ConsumerState<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends ConsumerState<BookingConfirmationScreen> {
  bool _agreedToPolicy = false;
  bool _isSubmitting = false;

  bool get _isUsingSubscription =>
      widget.bookingDetails.paymentMethod ==
      BookingPaymentMethod.subscriptionCredit;

  @override
  Widget build(BuildContext context) {
    final details = widget.bookingDetails;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: const Text('تأكيد الحجز'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildSessionDetailsCard(),
                  _buildCancellationPolicyCard(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CheckboxListTile(
                      title: const Text('أوافق على سياسة الإلغاء وشروط الخدمة'),
                      value: _agreedToPolicy,
                      onChanged: (val) =>
                          setState(() => _agreedToPolicy = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_agreedToPolicy && !_isSubmitting)
                      ? _confirmBooking
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isUsingSubscription
                              ? 'تأكيد الحجز (من الباقة)'
                              : 'تأكيد الحجز (${details.cost.toStringAsFixed(0)} جنيه)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancellationPolicyCard() {
    return Card(
      color: Colors.red.shade50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text(
                  'سياسة الإلغاء',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _policyItem('-  إلغاء مجاني قبل 24 ساعة من موعد الجلسة'),
            _policyItem('-  خصم 50% من المبلغ للإلغاء قبل 12 ساعة'),
            _policyItem('-  خصم 100% (لا يمكن استرداد المبلغ) للإلغاء بعد ذلك'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'في حالة استخدام الباقة، سيتم خصم جلسة واحدة عند الإلغاء المتأخر',
                      style:
                          TextStyle(fontSize: 12, color: Colors.red.shade700),
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

  Widget _policyItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
    );
  }

  Widget _buildSessionDetailsCard() {
    final details = widget.bookingDetails;
    final teacherPhoto = details.mohaffezPhotoUrl;
    final formattedDate =
        DateFormat('EEEE dd MMMM yyyy', 'ar').format(details.slotDate);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      (teacherPhoto != null && teacherPhoto.isNotEmpty)
                          ? NetworkImage(teacherPhoto)
                          : null,
                  child: (teacherPhoto == null || teacherPhoto.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.mohaffezName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${details.rating.toStringAsFixed(1)}/5',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${details.reviewCount} تقييم)',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _detailRow(Icons.calendar_today, 'التاريخ', formattedDate),
            _detailRow(Icons.access_time, 'الوقت', details.preferredTimeSlot),
            _detailRow(
              Icons.timer,
              'المدة',
              '${details.slotEnd.difference(details.slotStart).inMinutes} دقيقة',
            ),
            _detailRow(Icons.location_on, 'المكان', details.location),
            _detailRow(
                Icons.book, 'النوع', _sessionTypeLabel(details.sessionType)),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.payments, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'التكلفة',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_isUsingSubscription) ...[
                      const Text(
                        'من الباقة (مجاناً)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text(
                        'سيتم خصم جلسة واحدة',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ] else
                      Text(
                        '${details.cost.toStringAsFixed(0)} جنيه',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _sessionTypeLabel(String type) {
    switch (type) {
      case 'home':
        return 'جلسة منزلية';
      case 'mosque':
        return 'جلسة في المسجد';
      case 'online':
        return 'جلسة أونلاين';
      default:
        return type;
    }
  }

  Future<void> _confirmBooking() async {
    // ── DEBUG START ──────────────────────────────────────────────
    debugPrint('🟡 [Booking] _confirmBooking() called');
    debugPrint('🟡 [Booking] agreedToPolicy=$_agreedToPolicy');
    debugPrint('🟡 [Booking] isSubmitting=$_isSubmitting');
    debugPrint('🟡 [Booking] isUsingSubscription=$_isUsingSubscription');
    debugPrint(
        '🟡 [Booking] paymentMethod=${widget.bookingDetails.paymentMethod}');
    debugPrint('🟡 [Booking] mohaffezId=${widget.bookingDetails.mohaffezId}');
    debugPrint('🟡 [Booking] studentId=${widget.bookingDetails.studentId}');
    debugPrint('🟡 [Booking] slotLockId=${widget.bookingDetails.slotLockId}');
    debugPrint(
        '🟡 [Booking] subscriptionId=${widget.bookingDetails.subscriptionId}');
    debugPrint(
        '🟡 [Booking] remainingCredits=${widget.bookingDetails.remainingCredits}');
    debugPrint('🟡 [Booking] cost=${widget.bookingDetails.cost}');
    debugPrint('🟡 [Booking] sessionType=${widget.bookingDetails.sessionType}');
    debugPrint('🟡 [Booking] slotDate=${widget.bookingDetails.slotDate}');
    debugPrint(
        '🟡 [Booking] preferredTimeSlot=${widget.bookingDetails.preferredTimeSlot}');
    // ── DEBUG END ────────────────────────────────────────────────

    final d = widget.bookingDetails;

    if (_isUsingSubscription &&
        (d.subscriptionId == null || d.remainingCredits <= 0)) {
      debugPrint('🔴 [Booking] BLOCKED: insufficient subscription credits');
      _showError('لا يوجد رصيد باقة كافٍ لإتمام الحجز');
      return;
    }

    debugPrint(
        '🟢 [Booking] Subscription check passed — calling createSessionRequest...');

    setState(() => _isSubmitting = true);
    try {
      final result =
          await ref.read(legacyBookingFlowProvider.notifier).createSessionRequest(
                mohaffezId: d.mohaffezId,
                studentId: d.studentId,
                studentName: d.studentName,
                mohaffezName: d.mohaffezName,
                sessionType: d.sessionType,
                preferredTimeSlot: d.preferredTimeSlot,
                slotStart: d.slotStart,
                slotEnd: d.slotEnd,
                slotDate: d.slotDate,
                imamAddressText: d.location,
                imamAddressLat: d.locationLat,
                imamAddressLng: d.locationLng,
                mohaffezPhone: d.mohaffezPhone,
                subscriptionId: _isUsingSubscription ? d.subscriptionId : null,
                isPaid: false,
                requiresPaymentOnAcceptance:
                    d.paymentMethod == BookingPaymentMethod.payAfterAcceptance,
                paymentMethod: d.paymentMethod,
                slotLockId: d.slotLockId,
                planId: d.planId,
                planTitle: d.planTitle,
                paymentAmount: d.paymentAmount ?? d.cost,
                sessionsCount: d.sessionsCount,
                planType: d.planType,
              );

      debugPrint(
          '🟢 [Booking] createSessionRequest returned: isSuccess=${result.isSuccess} error=${result.errorMessage} sessionId=${result.sessionId}');

      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الحجز بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        debugPrint('🔴 [Booking] FAILED: ${result.errorMessage}');
        _showError(result.errorMessage ?? 'فشل في إرسال طلب الحجز');
      }
    } catch (e, stack) {
      debugPrint('🔴 [Booking] EXCEPTION: $e');
      debugPrint('🔴 [Booking] STACK: $stack');
      if (mounted) _showError('فشل في إرسال الطلب: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعذر إتمام العملية'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}
