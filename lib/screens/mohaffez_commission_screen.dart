import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/direct_payment_model.dart';
import '../services/direct_payment_service.dart';

class MohaffezCommissionScreen extends StatelessWidget {
  final String mohaffezId;

  const MohaffezCommissionScreen({
    super.key,
    required this.mohaffezId,
  });

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
          title: const Text('عمولاتي'),
          backgroundColor: const Color(0xFFF59E0B),
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<List<WeeklyCommissionSummary>>(
          stream: DirectPaymentService.watchCommissions(mohaffezId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data!;
            if (list.isEmpty) {
              return const Center(
                child: Text('لا توجد عمولات بعد'),
              );
            }

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
                        ? [Colors.amber.shade700, Colors.amber.shade400]
                        : [Colors.green.shade700, Colors.green.shade400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Text(
                    totalPending > 0 ? 'إجمالي المستحق للمنصة' : 'لا يوجد مستحقات 🎉',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
                  const Text('معدل العمولة: 5%',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),

              // List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _MohaffezWeekSummaryCard(
                    summary: list[i],
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _MohaffezWeekSummaryCard extends StatelessWidget {
  final WeeklyCommissionSummary summary;

  const _MohaffezWeekSummaryCard({
    required this.summary,
  });

  Color get _statusColor => switch (summary.status) {
        'paid' => Colors.green,
        'overdue' => Colors.red,
        _ => Colors.orange,
      };

  String get _statusLabel => switch (summary.status) {
        'paid' => 'مدفوع',
        'overdue' => 'متأخر',
        _ => 'قيد الانتظار',
      };

  @override
  Widget build(BuildContext context) {
    final weekLabel = summary.weekStart != null
        ? 'الأسبوع ${summary.weekNumber} — ${DateFormat('yyyy', 'ar').format(summary.weekStart!)}'
        : 'الأسبوع ${summary.weekNumber}';
    final due = summary.dueDate != null
        ? DateFormat('dd/MM/yyyy', 'ar').format(summary.dueDate!)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  weekLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _statusColor),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    label: 'الجلسات',
                    value: '${summary.totalSessions}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoChip(
                    label: 'الإجمالي',
                    value: '${summary.totalRevenue.toStringAsFixed(0)} ج.م',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (due.isNotEmpty)
                  Text(
                    'الاستحقاق: $due',
                    style: TextStyle(
                      fontSize: 12,
                      color: summary.isOverdue ? Colors.red : Colors.grey,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  '${summary.commissionAmount.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
