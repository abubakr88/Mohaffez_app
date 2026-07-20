import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../design_system/design_system.dart';

DateTime? adminPaymentDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

String adminExactTimestamp(dynamic value) {
  final date = adminPaymentDate(value);
  if (date == null) return '—';
  return DateFormat('dd/MM/yyyy - HH:mm:ss', 'ar').format(date);
}

String adminMoney(dynamic value, [String? currency]) {
  final amount = value is num ? value.toDouble() : double.tryParse('$value');
  if (amount == null) return '—';
  final code = (currency ?? 'EGP').trim().toUpperCase();
  final label = code == 'EGP' ? 'ج.م' : code;
  return '${NumberFormat('#,##0.00', 'ar').format(amount)} $label';
}

String adminPaymentStatusLabel(String value) => switch (_normalized(value)) {
      'pending' => 'قيد الانتظار',
      'processing' => 'قيد المعالجة',
      'completed' || 'paid' || 'success' => 'مكتملة',
      'failed' => 'فشلت',
      'refunded' => 'مستردة',
      'cancelled' || 'canceled' => 'ملغاة',
      _ => value.trim().isEmpty ? 'غير محدد' : value,
    };

DSBadgeVariant adminPaymentStatusVariant(String value) =>
    switch (_normalized(value)) {
      'completed' || 'paid' || 'success' => DSBadgeVariant.success,
      'failed' || 'cancelled' || 'canceled' => DSBadgeVariant.error,
      'processing' => DSBadgeVariant.info,
      'pending' => DSBadgeVariant.warning,
      'refunded' => DSBadgeVariant.neutral,
      _ => DSBadgeVariant.neutral,
    };

String adminPaymentMethodLabel(Map<String, dynamic> data) {
  final metadata = _map(data['metadata']);
  final amount = data['amount'] is num
      ? (data['amount'] as num).toDouble()
      : double.tryParse('${data['amount'] ?? ''}');
  final promoCode = _firstText(data, const ['promoCode']) ??
      _firstText(metadata, const ['promoCode']);
  if (amount != null && amount <= 0.01 && promoCode != null) {
    return 'كوبون خصم 100%';
  }
  final method = _normalized('${data['method'] ?? ''}');
  final gateway = _normalized('${data['gateway'] ?? ''}');
  if (gateway == 'paymob' || method == 'card') return 'بطاقة عبر Paymob';
  return switch (method) {
    'wallet' => 'محفظة التطبيق',
    'cash' => 'دفع مباشر',
    'banktransfer' => 'تحويل بنكي',
    'instapay' => 'InstaPay',
    'vodafonecash' => 'Vodafone Cash',
    'orangemoney' => 'Orange Money',
    'etisalatcash' => 'Etisalat Cash',
    'wepay' => 'WE Pay',
    'free' => 'كوبون مجاني',
    _ => method.isEmpty ? 'غير محدد' : '${data['method']}',
  };
}

String adminPlanTypeLabel(dynamic value) => switch (_normalized('$value')) {
      'single' => 'جلسة واحدة',
      'bundle' => 'باقة جلسات',
      'subscription' => 'اشتراك',
      _ => '$value'.trim().isEmpty || value == null ? 'غير محدد' : '$value',
    };

String adminPaymentEventLabel(String value) => switch (_normalized(value)) {
      'paymentcreated' => 'إنشاء عملية دفع',
      'paymentprocessing' => 'بدء معالجة الدفع',
      'paymentcompleted' => 'اكتمال الدفع',
      'paymentfailed' => 'فشل الدفع',
      'webhookreceived' => 'استلام تأكيد البوابة',
      'bookingconfirmed' => 'تأكيد الحجز',
      'subscriptioncreated' => 'تفعيل الباقة',
      'subscriptionrepaired' => 'إصلاح ربط الباقة',
      _ => value.trim().isEmpty ? 'حدث غير محدد' : value,
    };

DSBadgeVariant adminPaymentEventVariant(String value) =>
    switch (_normalized(value)) {
      'paymentcompleted' ||
      'bookingconfirmed' ||
      'subscriptioncreated' =>
        DSBadgeVariant.success,
      'subscriptionrepaired' => DSBadgeVariant.success,
      'paymentfailed' => DSBadgeVariant.error,
      'webhookreceived' || 'paymentprocessing' => DSBadgeVariant.info,
      'paymentcreated' => DSBadgeVariant.warning,
      _ => DSBadgeVariant.neutral,
    };

String adminPaymentEventDescription(Map<String, dynamic> event) {
  final type = '${event['eventType'] ?? event['type'] ?? ''}';
  final data = _map(event['data']);
  return switch (_normalized(type)) {
    'paymentcreated' => 'تم إنشاء سجل الدفع وبدء انتظار الإتمام.',
    'paymentprocessing' => 'بدأت بوابة الدفع معالجة العملية.',
    'paymentcompleted' => 'تم اعتماد العملية المالية بنجاح.',
    'paymentfailed' => 'فشلت العملية: ${_firstText(data, const [
              'error',
              'reason',
              'failureReason'
            ]) ?? 'لم يسجل سبب'}',
    'webhookreceived' => 'وصل إشعار من بوابة الدفع إلى الخادم.',
    'bookingconfirmed' => 'تم إنشاء الجلسة وتأكيد الحجز بعد الدفع.',
    'subscriptioncreated' => 'تم إنشاء وتفعيل اشتراك الباقة.',
    'subscriptionrepaired' =>
      'تم إنشاء اشتراك الباقة المفقود وربطه بالدفعة والطلب والجلسة الأولى دون حركة مالية جديدة.',
    _ => 'تم تسجيل حدث دفع جديد.',
  };
}

String adminTransactionReference(Map<String, dynamic> data) {
  final metadata = _map(data['metadata']);
  final nested = _map(data['data']);
  return _firstText(data, const [
        'gatewayTransactionId',
        'paymentTransactionId',
        'transactionReference',
        'gatewayOrderId',
      ]) ??
      _firstText(metadata, const ['transactionId']) ??
      _firstText(nested, const ['transactionId']) ??
      '—';
}

String adminShortId(String value, {int visible = 8}) {
  if (value == '—' || value.length <= visible * 2 + 1) return value;
  return '${value.substring(0, visible)}…${value.substring(value.length - visible)}';
}

String adminBrowserTimezoneLabel() {
  final offset = DateTime.now().timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return 'توقيت المتصفح UTC$sign$hours:$minutes';
}

Map<String, dynamic> adminMap(dynamic value) => _map(value);

String _normalized(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const <String, dynamic>{};
}

String? _firstText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && '$value'.trim().isNotEmpty) return '$value';
  }
  return null;
}
