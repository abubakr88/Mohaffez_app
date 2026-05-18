import 'dart:ui' as ui;
import 'package:mohaffez_core/mohaffez_core.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// booking_provider is exported from package:mohaffez_core/mohaffez_core.dart

class PaymentMethodSelectorScreen extends StatefulWidget {
  const PaymentMethodSelectorScreen({
    super.key,
    required this.mohaffezId,
    required this.mohaffezName,
    required this.hasActiveSubscription,
    required this.remainingCredits,
    required this.singleSessionPrice,
    required this.packagePrice,
    required this.packageSessions,
  });

  final String mohaffezId;
  final String mohaffezName;
  final bool hasActiveSubscription;
  final int remainingCredits;
  final double singleSessionPrice;
  final double packagePrice;
  final int packageSessions;

  @override
  State<PaymentMethodSelectorScreen> createState() =>
      _PaymentMethodSelectorScreenState();
}

class _PaymentMethodSelectorScreenState
    extends State<PaymentMethodSelectorScreen> {
  BookingPaymentMethod? selectedMethod;

  @override
  void initState() {
    super.initState();
    if (widget.hasActiveSubscription) {
      selectedMethod = BookingPaymentMethod.bundleCredit;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Text('اختر طريقة الدفع'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),
                    if (widget.hasActiveSubscription)
                      _buildPaymentOption(
                        method: BookingPaymentMethod.bundleCredit,
                        icon: Icons.card_membership,
                        title: 'استخدام رصيد الباقة',
                        benefits: [
                          'تأكيد فوري للجلسة',
                          'باقي لديك: ${widget.remainingCredits} جلسة',
                          'تكلفة: مجاناً (من الباقة)',
                        ],
                        backgroundColor: AppThemeConstants.successLight,
                        borderColor: AppThemeConstants.success,
                        recommended: true,
                      ),
                    if (widget.hasActiveSubscription)
                      const SizedBox(height: 12),
                    _buildPaymentOption(
                      method: BookingPaymentMethod.payAfterAcceptance,
                      icon: Icons.pending_actions,
                      title: 'الدفع بعد قبول المحفظ',
                      benefits: [
                        'انتظار قبول المحفظ',
                        'ثم لديك 10 ساعات للدفع (إلا الدفع = إلغاء تلقائي)',
                        'تكلفة: ${widget.singleSessionPrice.toStringAsFixed(0)} جنيه',
                      ],
                      warning: 'قد يرفض المحفظ الطلب',
                      backgroundColor: AppThemeConstants.accentAmberLight,
                      borderColor: AppThemeConstants.accentAmber,
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentOption(
                      method: BookingPaymentMethod.buyNewPackage,
                      icon: Icons.shopping_bag,
                      title: 'شراء باقة جديدة',
                      benefits: [
                        'وفر حتى ${_calculateSavings()}%',
                        'باقة ${widget.packageSessions} جلسات بـ ${widget.packagePrice.toStringAsFixed(0)} جنيه',
                        'متوسط الجلسة: ${_getAverageSessionPrice()} جنيه',
                      ],
                      backgroundColor: AppThemeConstants.accentBlueLight,
                      borderColor: AppThemeConstants.accentBlue,
                    ),
                    const SizedBox(height: 24),
                    if (!widget.hasActiveSubscription) _buildComparisonTable(),
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
                  onPressed: selectedMethod == null
                      ? null
                      : () => context.pop(selectedMethod),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.secondary,
                    disabledBackgroundColor: AppThemeConstants.grey300,
                  ),
                  child: Text(
                    _getButtonLabel(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required BookingPaymentMethod method,
    required IconData icon,
    required String title,
    required List<String> benefits,
    String? warning,
    required Color backgroundColor,
    required Color borderColor,
    bool recommended = false,
  }) {
    final isSelected = selectedMethod == method;
    return InkWell(
      onTap: () => setState(() => selectedMethod = method),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color:
                isSelected ? borderColor : borderColor.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: borderColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.textPrimary,
                    ),
                  ),
                ),
                if (recommended)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'موصى به',
                      style: TextStyle(
                        color: AppThemeConstants.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                // ignore: deprecated_member_use
                Radio<BookingPaymentMethod>(
                  value: method,
                  // ignore: deprecated_member_use
                  groupValue: selectedMethod,
                  // ignore: deprecated_member_use
                  onChanged: (value) => setState(() => selectedMethod = value),
                  activeColor: borderColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: borderColor.withAlpha(179)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(benefit,
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppThemeConstants.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppThemeConstants.warning,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppThemeConstants.accentBlue),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مقارنة سريعة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: AppThemeConstants.grey300),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AppThemeConstants.grey100),
                children: [
                  _tableCell('', isHeader: true),
                  _tableCell('باقة', isHeader: true),
                  _tableCell('جلسة واحدة', isHeader: true),
                ],
              ),
              TableRow(
                children: [
                  _tableCell('التأكيد'),
                  _tableCell('فوري'),
                  _tableCell('بعد قبول المحفظ'),
                ],
              ),
              TableRow(
                children: [
                  _tableCell('السعر/جلسة'),
                  _tableCell(
                    '${_getAverageSessionPrice()} ج',
                  ),
                  _tableCell(
                      '${widget.singleSessionPrice.toStringAsFixed(0)} ج'),
                ],
              ),
              TableRow(
                children: [
                  _tableCell('الوفر'),
                  _tableCell('${_calculateSavings()}%'),
                  _tableCell('0%'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 14 : 13,
        ),
      ),
    );
  }

  int _calculateSavings() {
    // Guard against division by zero
    if (widget.packageSessions <= 0 || widget.singleSessionPrice <= 0) {
      return 0;
    }
    final packagePerSession = widget.packagePrice / widget.packageSessions;
    final savings = ((widget.singleSessionPrice - packagePerSession) /
            widget.singleSessionPrice) *
        100;
    // Guard against negative savings (bad data)
    return savings.round().clamp(0, 99);
  }

  String _getButtonLabel() {
    switch (selectedMethod) {
      case BookingPaymentMethod.buyNewPackage:
        return 'شراء الباقة والحجز';
      case BookingPaymentMethod.payAfterAcceptance:
        return 'إرسال الطلب';
      case BookingPaymentMethod.bundleCredit:
        return 'تأكيد الحجز';
      default:
        return 'متابعة';
    }
  }

  String _getAverageSessionPrice() {
    if (widget.packageSessions <= 0) return 'غير محدد';
    return (widget.packagePrice / widget.packageSessions).toStringAsFixed(0);
  }
}
