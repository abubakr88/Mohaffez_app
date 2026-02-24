import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../providers/booking_provider.dart';

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
      selectedMethod = BookingPaymentMethod.subscriptionCredit;
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
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: const Text('اختر طريقة الدفع'),
        ),
        body: RadioGroup<BookingPaymentMethod>(
          groupValue: selectedMethod,
          onChanged: (value) => setState(() => selectedMethod = value),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'كيف تريد الدفع؟',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (widget.hasActiveSubscription)
                      _buildPaymentOption(
                        method: BookingPaymentMethod.subscriptionCredit,
                        icon: Icons.card_membership,
                        title: 'استخدام رصيد الباقة',
                        benefits: [
                          'تأكيد فوري للجلسة',
                          'باقي لديك: ${widget.remainingCredits} جلسة',
                          'تكلفة: مجاناً (من الباقة)',
                        ],
                        backgroundColor: Colors.green.shade50,
                        borderColor: Colors.green,
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
                        'ثم لديك 10 ساعات للدفع',
                        'تكلفة: ${widget.singleSessionPrice.toStringAsFixed(0)} جنيه',
                      ],
                      warning: 'قد يرفض المحفظ الطلب',
                      backgroundColor: Colors.amber.shade50,
                      borderColor: Colors.amber,
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentOption(
                      method: BookingPaymentMethod.buyNewPackage,
                      icon: Icons.shopping_bag,
                      title: 'شراء باقة جديدة',
                      benefits: [
                        'وفر حتى ${_calculateSavings()}%',
                        'باقة ${widget.packageSessions} جلسات بـ ${widget.packagePrice.toStringAsFixed(0)} جنيه',
                        'متوسط الجلسة: ${(widget.packagePrice / widget.packageSessions).toStringAsFixed(0)} جنيه',
                      ],
                      backgroundColor: Colors.blue.shade50,
                      borderColor: Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    _buildComparisonTable(),
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
                    onPressed: selectedMethod == null
                        ? null
                        : () => Navigator.pop(context, selectedMethod),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: const Text(
                      'متابعة',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    return GestureDetector(
      onTap: () => setState(() => selectedMethod = method),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: borderColor.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                if (recommended)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'موصى به',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Radio<BookingPaymentMethod>(
                  value: method,
                  activeColor: borderColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(benefit, style: const TextStyle(fontSize: 14)),
              ),
            ),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
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
        border: Border.all(color: Colors.blue.shade200),
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
            border: TableBorder.all(color: Colors.grey.shade300),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
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
                    '${(widget.packagePrice / widget.packageSessions).toStringAsFixed(0)} ج',
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
    final packagePerSession = widget.packagePrice / widget.packageSessions;
    final savings = ((widget.singleSessionPrice - packagePerSession) /
            widget.singleSessionPrice) *
        100;
    return savings.round();
  }
}
