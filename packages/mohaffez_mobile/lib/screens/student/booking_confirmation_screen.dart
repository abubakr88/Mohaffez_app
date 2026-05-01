import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/booking_provider.dart' show legacyBookingFlowProvider, BookingPaymentMethod;
import 'package:mohaffez_core/src/theme/app_theme_constants.dart';

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
                  icon: const Icon(Icons.arrow_back),
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
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _buildSessionDetailsCard(),
                  _buildCancellationPolicyCard(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CheckboxListTile(
                      title: InkWell(
                        onTap: _showPolicyDetails,
                        child: const Text(
                          'أوافق على سياسة الإلغاء وشروط الخدمة',
                          style: TextStyle(
                            color: AppThemeConstants.secondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
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
                color: AppThemeConstants.white,
                boxShadow: [
                  BoxShadow(
                    color: AppThemeConstants.black.withValues(alpha: 0.1),
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
                    backgroundColor: AppThemeConstants.secondary,
                    disabledBackgroundColor: AppThemeConstants.grey300,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppThemeConstants.white,
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
      color: AppThemeConstants.errorLight,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: AppThemeConstants.error, size: 24),
                SizedBox(width: 8),
                Text(
                  'سياسة الإلغاء',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.errorDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _policyItem(Icons.check_circle, AppThemeConstants.success, 'إلغاء مجاني قبل 24 ساعة من موعد الجلسة'),
            _policyItem(Icons.warning_amber, AppThemeConstants.warning, 'خصم 50% من المبلغ للإلغاء قبل 12 ساعة'),
            _policyItem(Icons.cancel, AppThemeConstants.error, 'خصم 100% (لا يمكن استرداد المبلغ) للإلغاء بعد ذلك'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppThemeConstants.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppThemeConstants.error),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'في حالة استخدام الباقة، سيتم خصم جلسة واحدة عند الإلغاء المتأخر',
                      style:
                          TextStyle(fontSize: 12, color: AppThemeConstants.error),
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

  Widget _policyItem(IconData icon, Color iconColor, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        ],
      ),
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
                          const Icon(Icons.star, color: AppThemeConstants.accentAmber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${details.rating.toStringAsFixed(1)}/10',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${details.reviewCount} تقييم)',
                            style: const TextStyle(
                                color: AppThemeConstants.grey500, fontSize: 12),
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
              _formatDuration(details.slotStart, details.slotEnd),
            ),
            _detailRow(Icons.location_on, 'المكان', details.location),
            _detailRow(
                Icons.book, 'النوع', _sessionTypeLabel(details.sessionType)),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.payments, color: AppThemeConstants.success),
                const SizedBox(width: 8),
                const Text(
                  'التكلفة',
                  style: TextStyle(fontSize: 16, color: AppThemeConstants.grey700),
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
                          color: AppThemeConstants.success,
                        ),
                      ),
                      const Text(
                        'سيتم خصم جلسة واحدة',
                        style: TextStyle(fontSize: 12, color: AppThemeConstants.grey500),
                      ),
                    ] else
                      Text(
                        '${details.cost.toStringAsFixed(0)} جنيه',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppThemeConstants.success,
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
          Icon(icon, size: 20, color: AppThemeConstants.grey600),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 14, color: AppThemeConstants.grey700)),
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
      case 'بيت':
        return 'جلسة منزلية';
      case 'مسجد':
        return 'جلسة في المسجد';
      case 'أونلاين':
        return 'جلسة أونلاين';
      default:
        return type;
    }
  }

  Future<void> _confirmBooking() async {
    final d = widget.bookingDetails;

    if (_isUsingSubscription &&
        (d.subscriptionId == null || d.remainingCredits <= 0)) {
      _showError('لا يوجد رصيد باقة كافٍ لإتمام الحجز');
      return;
    }

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

      if (!mounted) return;
      if (result.isSuccess) {
        // Navigate to home and show success message
        context.go('/home');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال طلب الحجز بنجاح'),
              backgroundColor: AppThemeConstants.success,
            ),
          );
        });
      } else {
        _showError(result.errorMessage ?? 'فشل في إرسال طلب الحجز');
      }
    } catch (e) {
      if (mounted) _showError('تعذر إتمام الحجز، يرجى المحاولة مرة أخرى');
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
            onPressed: () => ctx.pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showPolicyDetails() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سياسة الإلغاء وشروط الخدمة'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'سياسة الإلغاء:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• إلغاء مجاني قبل 24 ساعة من موعد الجلسة'),
              Text('• خصم 50% من المبلغ للإلغاء قبل 12 ساعة'),
              Text('• خصم 100% (لا يمكن استرداد المبلغ) للإلغاء بعد ذلك'),
              SizedBox(height: 16),
              Text(
                'شروط الخدمة:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• يجب على الطالب الالتزام بموعد الجلسة'),
              Text('• في حالة التأخير أكثر من 15 دقيقة، يعتبر الطالب غائباً'),
              Text('• يمكن إعادة جدولة الجلسة مرة واحدة فقط'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final minutes = diff.inMinutes;
    if (minutes <= 0) return 'غير محدد';
    return '$minutes دقيقة';
  }
}
