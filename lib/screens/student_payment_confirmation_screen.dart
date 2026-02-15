import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/payment_model.dart';
import '../models/pricing_plan_model.dart';
import '../providers/payment_provider.dart';
import '../providers/pricing_provider.dart';
import '../providers/user_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/empty_state.dart';
import '../utils/arabic_labels.dart';
import 'payment_webview_screen.dart';

class StudentPaymentConfirmationScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String mohaffezId;
  final String mohaffezName;
  final Map<String, dynamic>? sessionDetails;

  final String? sessionType;
  final DateTime? sessionDate;
  final String? timeSlot;
  final String? location;

  const StudentPaymentConfirmationScreen({
    super.key,
    required this.requestId,
    required this.mohaffezId,
    required this.mohaffezName,
    this.sessionDetails,
    this.sessionType,
    this.sessionDate,
    this.timeSlot,
    this.location,
  });

  @override
  ConsumerState<StudentPaymentConfirmationScreen> createState() =>
      _StudentPaymentConfirmationScreenState();
}

class _StudentPaymentConfirmationScreenState
    extends ConsumerState<StudentPaymentConfirmationScreen> {
  PricingPlanModel? selectedPlan;

  String get _sessionType =>
      widget.sessionType ??
      widget.sessionDetails?['sessionType'] as String? ??
      'online';

  DateTime? get _sessionDate {
    if (widget.sessionDate != null) return widget.sessionDate;
    final raw = widget.sessionDetails?['slotDate'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  String get _timeSlot =>
      widget.timeSlot ??
      widget.sessionDetails?['preferredTimeSlot'] as String? ??
      '';
  String get _location =>
      widget.location ??
      widget.sessionDetails?['imamAddressText'] as String? ??
      widget.sessionDetails?['location'] as String? ??
      ArabicLabels.notSpecified;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(activePricingPlansProvider(widget.mohaffezId));

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تأكيد الحجز بالدفع'),
          backgroundColor: AppThemeConstants.accentGreen,
        ),
        body: plansAsync.when(
          data: (plans) {
            final filteredPlans = plans.where((p) {
              if (_sessionType == 'home') return p.mode == SessionMode.home;
              if (_sessionType == 'mosque') return p.mode == SessionMode.mosque;
              if (_sessionType == 'online') return p.mode == SessionMode.online;
              return false;
            }).toList();

            if (filteredPlans.isEmpty) {
              return const EmptyState(
                icon: Icons.payments_outlined,
                title: 'لا توجد خطط متاحة',
                message: 'المحفظ لم يضف خطط تسعير مناسبة لهذا النوع',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _lockedCard(),
                const SizedBox(height: 12),
                ...filteredPlans.map(_planCard),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ: $e')),
        ),
        bottomNavigationBar: selectedPlan == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => _proceedToPayment(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      '${ArabicLabels.payNow} ${selectedPlan!.priceEGP.toStringAsFixed(0)} جنيه',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _lockedCard() {
    final dateLabel = _sessionDate != null
        ? DateFormat('EEEE، dd/MM/yyyy', 'ar').format(_sessionDate!)
        : ArabicLabels.notSpecified;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'تفاصيل الجلسة المطلوبة',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blue.shade700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('المحفظ: ${widget.mohaffezName}'),
          Text(
              '${ArabicLabels.type}: ${ArabicLabels.getSessionTypeLabel(_sessionType)}'),
          Text('${ArabicLabels.date}: $dateLabel'),
          Text(
              '${ArabicLabels.time}: ${_timeSlot.isEmpty ? ArabicLabels.notSpecified : _timeSlot}'),
          Text('${ArabicLabels.location}: $_location'),
        ],
      ),
    );
  }

  Widget _planCard(PricingPlanModel plan) {
    final selected = selectedPlan?.id == plan.id;
    return GestureDetector(
      onTap: () => setState(() => selectedPlan = plan),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected ? AppThemeConstants.accentGreen : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                color: AppThemeConstants.accentGreen),
            const SizedBox(width: 10),
            Expanded(
                child: Text(plan.title,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            Text('${plan.priceEGP.toStringAsFixed(0)} جنيه'),
          ],
        ),
      ),
    );
  }

  Future<void> _proceedToPayment(BuildContext context, WidgetRef ref) async {
    if (selectedPlan == null) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء تسجيل الدخول أولاً')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final basePayment = PaymentModel(
        studentId: user.uid,
        studentName: user.name,
        studentEmail: user.email,
        studentPhone: user.phoneNumber ?? '',
        mohaffezId: widget.mohaffezId,
        mohaffezName: widget.mohaffezName,
        planId: selectedPlan!.id!,
        planTitle: selectedPlan!.title,
        amount: selectedPlan!.priceEGP,
        method: PaymentMethod.card,
        status: PaymentStatus.pending,
        gateway: PaymentGateway.paymob,
        createdAt: DateTime.now(),
      );

      final metadata = <String, dynamic>{
        'requestId': widget.requestId,
        'confirmBooking': true,
        'sessionDetails': {
          'sessionType': _sessionType,
          'slotDate':
              _sessionDate != null ? Timestamp.fromDate(_sessionDate!) : null,
          'preferredTimeSlot': _timeSlot,
          'location': _location,
        },
      };

      final result = await ref
          .read(paymentActionsProvider.notifier)
          .startPaymentAndHandleResult(
            basePayment: basePayment,
            plan: selectedPlan!,
            extraMetadata: metadata,
          );

      if (!context.mounted) return;
      Navigator.pop(context);

      if (result == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل بدء عملية الدفع')));
        return;
      }

      if (result.paymentUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد الجلسة المجانية بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            paymentUrl: result.paymentUrl,
            paymentId: result.paymentId,
            plan: selectedPlan!,
          ),
        ),
      );

      if (success == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الدفع وتأكيد الحجز بنجاح')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${ArabicLabels.error}: $e')));
    }
  }
}
