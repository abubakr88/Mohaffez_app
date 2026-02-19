import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/direct_payment_model.dart';
import '../services/direct_payment_service.dart';

class CommissionDashboardScreen extends StatelessWidget {
  const CommissionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عمولات التطبيق (5%)'),
          backgroundColor: const Color(0xFFF59E0B),
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<List<WeeklyCommissionSummary>>(
          stream: DirectPaymentService.watchCommissions(uid),
          builder: (context, snap) {
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            final list = snap.data!;
            if (list.isEmpty)
              return const Center(
                child: Text('لا توجد عمولات بعد'),
              );

            // Stats at top
            final totalPending = list
                .where((w) => w.isPending || w.isOverdue)
                .fold(0.0, (s, w) => s + w.commissionAmount);

            return Column(children: [
              // Summary card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: totalPending > 0
                        ? [Colors.orange.shade700, Colors.orange.shade400]
                        : [Colors.green.shade700, Colors.green.shade400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Text(
                    totalPending > 0
                        ? 'مستحق عليك دفعه'
                        : 'لا يوجد مستحقات 🎉',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${totalPending.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text('5% من إجمالي المدفوعات المباشرة',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),

              // List
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _WeekSummaryCard(summary: list[i]),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  final WeeklyCommissionSummary summary;
  const _WeekSummaryCard({required this.summary});

  Color get _statusColor => switch (summary.status) {
    'paid' => Colors.green,
    'overdue' => Colors.red,
    _ => Colors.orange,
  };

  String get _statusLabel => switch (summary.status) {
    'paid' => '✅ مدفوع',
    'overdue' => '⚠️ متأخر',
    _ => '⏳ مستحق',
  };

  @override
  Widget build(BuildContext context) {
    final weekLabel = summary.weekStart != null
        ? 'الأسبوع ${summary.weekNumber} – '
            '${DateFormat('dd MMM', 'ar').format(summary.weekStart!)}'
        : 'الأسبوع ${summary.weekNumber}';
    final due = summary.dueDate != null
        ? DateFormat('dd/MM/yyyy').format(summary.dueDate!)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(weekLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${summary.totalSessions} جلسة • '
              'إجمالي: ${summary.totalRevenue.toStringAsFixed(0)} ج.م',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (due.isNotEmpty && !summary.isPaid)
              Text('الاستحقاق: $due',
                  style: TextStyle(
                      fontSize: 12,
                      color: summary.isOverdue ? Colors.red : Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${summary.commissionAmount.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _statusColor)),
            const SizedBox(height: 4),
            Text(_statusLabel,
                style: TextStyle(fontSize: 11, color: _statusColor)),
          ],
        ),
      ),
    );
  }
}
