import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../shared/utils/time_formatter.dart';
import '../../shared/widgets/admin_app_bar.dart';

class BookingStatusScreen extends StatelessWidget {
  const BookingStatusScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: 'حالة طلب الحجز'),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('sessionRequests')
              .doc(requestId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _StatusError(
                title: 'تعذر تحميل حالة الطلب',
                message: 'يرجى المحاولة مرة أخرى بعد لحظات.',
                onRetry: () => context.go('/requests'),
              );
            }

            final data = snapshot.data?.data();
            if (data == null) {
              return _StatusError(
                title: 'الطلب غير موجود',
                message: 'ربما تم حذف الطلب أو لا تملك صلاحية الوصول إليه.',
                onRetry: () => context.go('/requests'),
              );
            }

            return _BookingStatusContent(
              requestId: requestId,
              request: data,
            );
          },
        ),
      ),
    );
  }
}

class _BookingStatusContent extends StatelessWidget {
  const _BookingStatusContent({
    required this.requestId,
    required this.request,
  });

  final String requestId;
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final status = _normalizedStatus(request['status']);
    final statusInfo = _statusInfo(status);
    final mohaffezId = request['mohaffezId']?.toString() ?? '';
    final mohaffezName = request['mohaffezName']?.toString().trim() ?? '';
    final learnerName = _firstNonEmpty([
      request['studentProfileName'],
      request['studentName'],
    ]);
    final guardianName = request['guardianName']?.toString().trim();
    final planTitle = _firstNonEmpty([
      request['planTitle'],
      request['planType'] == 'bundle' ? 'باقة جلسات' : 'جلسة واحدة',
    ]);
    final amount = (request['displayAmount'] as num?)?.toDouble() ??
        (request['paymentAmount'] as num?)?.toDouble() ??
        (request['chargedAmountEGP'] as num?)?.toDouble();
    final currencyLabel =
        request['displayCurrencyLabel']?.toString().trim().isNotEmpty == true
            ? request['displayCurrencyLabel'].toString().trim()
            : 'ج.م';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _HeroStatusCard(
          icon: statusInfo.icon,
          color: statusInfo.color,
          title: statusInfo.title,
          body: statusInfo.body,
        ),
        const SizedBox(height: 16),
        _RequestSummaryCard(
          learnerName: learnerName,
          guardianName: guardianName,
          mohaffezName: mohaffezName,
          sessionType: request['sessionType']?.toString() ?? '',
          preferredTimeSlot: request['preferredTimeSlot']?.toString() ?? '',
          slotDate: _asDateTime(request['slotDate']),
          address: request['imamAddressText']?.toString(),
          planTitle: planTitle,
          amount: amount,
          currencyLabel: currencyLabel,
        ),
        const SizedBox(height: 16),
        _TimelineCard(status: status),
        const SizedBox(height: 20),
        if (_needsPayment(status) && mohaffezId.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () {
              final qs = Uri(
                queryParameters: {
                  'requestId': requestId,
                  if (mohaffezName.isNotEmpty) 'name': mohaffezName,
                },
              ).query;
              context.push(
                '/payment/$mohaffezId?$qs',
                extra: {'lockedRequest': request},
              );
            },
            icon: const Icon(Icons.payment_rounded),
            label: const Text('إتمام الدفع'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeConstants.secondary,
              foregroundColor: AppThemeConstants.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: AppThemeConstants.borderRadiusMd,
              ),
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.go('/requests'),
          icon: const Icon(Icons.list_alt_rounded),
          label: const Text('عرض طلباتي'),
        ),
        if (_isConfirmed(status)) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => context.go('/my-sessions'),
            icon: const Icon(Icons.event_available_rounded),
            label: const Text('عرض جلساتي'),
          ),
        ],
      ],
    );
  }
}

class _HeroStatusCard extends StatelessWidget {
  const _HeroStatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppThemeConstants.borderRadiusLg,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: AppThemeConstants.borderRadiusMd,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppThemeConstants.titleMedium.copyWith(
                    color: AppThemeConstants.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: AppThemeConstants.bodySmall.copyWith(
                    color: AppThemeConstants.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({
    required this.learnerName,
    required this.guardianName,
    required this.mohaffezName,
    required this.sessionType,
    required this.preferredTimeSlot,
    required this.slotDate,
    required this.address,
    required this.planTitle,
    required this.amount,
    required this.currencyLabel,
  });

  final String learnerName;
  final String? guardianName;
  final String mohaffezName;
  final String sessionType;
  final String preferredTimeSlot;
  final DateTime? slotDate;
  final String? address;
  final String planTitle;
  final double? amount;
  final String currencyLabel;

  @override
  Widget build(BuildContext context) {
    final amountText = amount == null
        ? null
        : '${NumberFormat('#,##0.##', 'ar').format(amount)} $currencyLabel';

    return Card(
      elevation: AppThemeConstants.elevationSm,
      shape: const RoundedRectangleBorder(
        borderRadius: AppThemeConstants.borderRadiusLg,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص الطلب',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              icon: Icons.child_care_rounded,
              label: 'الطالب',
              value: learnerName.isEmpty ? 'غير محدد' : learnerName,
              subValue: guardianName != null && guardianName!.isNotEmpty
                  ? 'ولي الأمر: $guardianName'
                  : null,
            ),
            _SummaryRow(
              icon: Icons.person_rounded,
              label: 'المحفظ',
              value: mohaffezName.isEmpty ? 'غير محدد' : mohaffezName,
            ),
            _SummaryRow(
              icon: Icons.video_camera_back_rounded,
              label: 'نوع الجلسة',
              value: _sessionTypeLabel(sessionType),
            ),
            _SummaryRow(
              icon: Icons.access_time_rounded,
              label: 'الموعد',
              value: preferredTimeSlot.isEmpty
                  ? 'غير محدد'
                  : formatTimeToArabicAmPm(preferredTimeSlot),
              subValue: slotDate == null
                  ? null
                  : DateFormat('EEEE d MMMM yyyy', 'ar').format(slotDate!),
            ),
            if (sessionType.trim().toLowerCase() != 'online' &&
                address != null &&
                address!.trim().isNotEmpty)
              _SummaryRow(
                icon: Icons.location_on_rounded,
                label: 'المكان',
                value: address!.trim(),
              ),
            _SummaryRow(
              icon: Icons.sell_rounded,
              label: 'الخطة',
              value: planTitle.isEmpty ? 'جلسة واحدة' : planTitle,
              subValue: amountText,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subValue,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppThemeConstants.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppThemeConstants.bodySmall.copyWith(
                    color: AppThemeConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppThemeConstants.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subValue != null && subValue!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subValue!,
                    style: AppThemeConstants.bodySmall.copyWith(
                      color: AppThemeConstants.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final steps = [
      const _TimelineStep('تم إرسال الطلب', Icons.send_rounded, true),
      _TimelineStep(
        'بانتظار قبول المحفظ',
        Icons.hourglass_top_rounded,
        _stepReached(status, 'teacher'),
      ),
      _TimelineStep(
        'بانتظار الدفع',
        Icons.payment_rounded,
        _stepReached(status, 'payment'),
      ),
      _TimelineStep(
        'جاري تأكيد الدفع',
        Icons.pending_actions_rounded,
        _stepReached(status, 'confirmation'),
      ),
      _TimelineStep(
        'تم تأكيد الحجز',
        Icons.verified_rounded,
        _isConfirmed(status),
      ),
    ];

    return Card(
      elevation: AppThemeConstants.elevationSm,
      shape: const RoundedRectangleBorder(
        borderRadius: AppThemeConstants.borderRadiusLg,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مسار الطلب',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final step in steps)
              _TimelineRow(
                label: step.label,
                icon: step.icon,
                done: step.done,
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep {
  const _TimelineStep(this.label, this.icon, this.done);
  final String label;
  final IconData icon;
  final bool done;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.icon,
    required this.done,
  });

  final String label;
  final IconData icon;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: done
                ? AppThemeConstants.success.withValues(alpha: 0.15)
                : AppThemeConstants.grey100,
            child: Icon(
              done ? Icons.check_rounded : icon,
              size: 17,
              color: done
                  ? AppThemeConstants.success
                  : AppThemeConstants.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppThemeConstants.bodyMedium.copyWith(
                color: done
                    ? AppThemeConstants.textPrimary
                    : AppThemeConstants.textSecondary,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusError extends StatelessWidget {
  const _StatusError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppThemeConstants.error,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppThemeConstants.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppThemeConstants.bodyMedium.copyWith(
                color: AppThemeConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('العودة إلى طلباتي'),
            ),
          ],
        ),
      ),
    );
  }
}

({String title, String body, Color color, IconData icon}) _statusInfo(
  String status,
) {
  switch (status) {
    case 'pending':
      return (
        title: 'تم إرسال الطلب',
        body: 'طلبك وصل للمحفظ. ستصلك رسالة عند القبول أو الرفض.',
        color: AppThemeConstants.warning,
        icon: Icons.hourglass_top_rounded,
      );
    case 'awaitingpayment':
    case 'awaiting_payment':
    case 'awaitingdirectpayment':
      return (
        title: 'المحفظ وافق على الطلب',
        body: 'يمكنك الآن إتمام الدفع. بعد الدفع ستظهر حالة التأكيد هنا.',
        color: AppThemeConstants.secondary,
        icon: Icons.payment_rounded,
      );
    case 'paymentprocessing':
    case 'processing':
    case 'awaitingdirectpaymentconfirmation':
    case 'awaiting_direct_payment_confirmation':
      return (
        title: 'جاري تأكيد الدفع',
        body: 'تم تسجيل إشعار الدفع. ننتظر التأكيد النهائي قبل تفعيل الجلسة.',
        color: AppThemeConstants.accentBlue,
        icon: Icons.pending_actions_rounded,
      );
    case 'accepted':
    case 'confirmed':
    case 'completed':
      return (
        title: 'تم تأكيد الحجز',
        body: 'الجلسة جاهزة الآن وستظهر في جلساتك القادمة.',
        color: AppThemeConstants.success,
        icon: Icons.verified_rounded,
      );
    case 'rejected':
    case 'declined':
      return (
        title: 'تم رفض الطلب',
        body: 'يمكنك اختيار موعد آخر أو محفظ آخر من صفحة البحث.',
        color: AppThemeConstants.error,
        icon: Icons.cancel_rounded,
      );
    case 'cancelled':
    case 'canceled':
      return (
        title: 'تم إلغاء الطلب',
        body: 'هذا الطلب لم يعد نشطًا.',
        color: AppThemeConstants.grey500,
        icon: Icons.block_rounded,
      );
    default:
      return (
        title: 'حالة الطلب',
        body: 'يتم تحديث حالة الطلب تلقائيًا عند حدوث أي تغيير.',
        color: AppThemeConstants.primary,
        icon: Icons.info_outline_rounded,
      );
  }
}

bool _needsPayment(String status) =>
    status == 'awaitingpayment' ||
    status == 'awaiting_payment' ||
    status == 'awaitingdirectpayment';

bool _isConfirmed(String status) =>
    status == 'accepted' || status == 'confirmed' || status == 'completed';

bool _stepReached(String status, String step) {
  final order = <String, int>{
    'pending': 1,
    'awaitingpayment': 2,
    'awaiting_payment': 2,
    'awaitingdirectpayment': 2,
    'paymentprocessing': 3,
    'processing': 3,
    'awaitingdirectpaymentconfirmation': 3,
    'awaiting_direct_payment_confirmation': 3,
    'accepted': 4,
    'confirmed': 4,
    'completed': 4,
  };
  final current = order[status] ?? 1;
  return switch (step) {
    'teacher' => current >= 1,
    'payment' => current >= 2,
    'confirmation' => current >= 3,
    _ => false,
  };
}

String _normalizedStatus(Object? value) =>
    value?.toString().trim().toLowerCase() ?? 'pending';

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return '';
}

String _sessionTypeLabel(String type) {
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
