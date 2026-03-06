import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../shared/theme/app_theme_constants.dart';
import '../models/direct_payment_model.dart';
import '../services/direct_payment_service.dart';

class DirectPaymentConfirmationsScreen extends StatelessWidget {
  const DirectPaymentConfirmationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mohaffezId = FirebaseAuth.instance.currentUser!.uid;
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
          title: const Text('تأكيد المدفوعات المباشرة'),
          backgroundColor: AppThemeConstants.primaryAmber,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث (بيانات مباشرة)',
              onPressed: () {},
            ),
          ],
        ),
        body: StreamBuilder<List<DirectPaymentModel>>(
          stream: DirectPaymentService.watchPendingConfirmations(mohaffezId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'خطأ في التحميل: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد مدفوعات بانتظار التأكيد',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) =>
                  _PaymentConfirmationCard(payment: items[i]),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentConfirmationCard extends StatefulWidget {
  final DirectPaymentModel payment;
  const _PaymentConfirmationCard({required this.payment});

  @override
  State<_PaymentConfirmationCard> createState() =>
      _PaymentConfirmationCardState();
}

class _PaymentConfirmationCardState extends State<_PaymentConfirmationCard> {
  bool _loading = false;

  // ── Confirm ───────────────────────────────────────────────────────────────
  Future<void> _confirm() async {
    // ✅ Capture BEFORE any await — context may be invalid after await
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _loading = true);
    try {
      await DirectPaymentService.mohaffezConfirm(widget.payment.id);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ تم قبول الجلسة وإشعار الطالب!'),
          backgroundColor: Colors.green,
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Reject ────────────────────────────────────────────────────────────────
  Future<void> _reject() async {
    // ✅ Capture BEFORE showDialog — showDialog is also async
    final messenger = ScaffoldMessenger.of(context);

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('سبب الرفض'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'مثال: لم يصلني أي تحويل',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('رفض', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    // ✅ Check mounted BEFORE setState after showDialog returns
    if (reason == null) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      await DirectPaymentService.mohaffezReject(
          widget.payment.id, reason.isEmpty ? null : reason);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم إرسال إشعار الرفض للطالب'),
          backgroundColor: Colors.orange,
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final method = DirectPaymentMethod.fromValue(p.paymentMethod);
    final dateStr = p.studentConfirmedAt != null
        ? DateFormat('dd/MM HH:mm').format(p.studentConfirmedAt!)
        : '–';
    final sessionDateStr = p.sessionDate != null
        ? DateFormat('EEEE d MMMM', 'ar').format(p.sessionDate!)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(children: [
              CircleAvatar(
                backgroundColor:
                    AppThemeConstants.accentGreen.withValues(alpha: 0.15),
                child: Text(
                  p.studentName.isNotEmpty ? p.studentName[0] : '؟',
                  style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.studentName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('أرسل إشعار الدفع: $dateStr',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppThemeConstants.accentGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${p.amount.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ]),

            const Divider(height: 20),

            // ── Info rows ───────────────────────────────────────────────────
            _row(Icons.payment, 'طريقة الدفع', method.label),
            _row(Icons.schedule, 'الموعد', p.preferredTimeSlot),
            if (sessionDateStr != null)
              _row(Icons.calendar_today, 'تاريخ الجلسة', sessionDateStr),
            if (p.studentNote != null && p.studentNote!.isNotEmpty)
              _row(Icons.note_outlined, 'ملاحظة الطالب', p.studentNote!),

            // ── Commission hint ──────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'عمولة التطبيق (5%): '
                    '${p.commissionAmount.toStringAsFixed(2)} ج.م  —  '
                    'يصلك صافي: '
                    '${(p.amount - p.commissionAmount).toStringAsFixed(2)} ج.م',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ]),
            ),

            // ── Action buttons ───────────────────────────────────────────────
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'استلمت الدفع',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _reject,
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('لم أستلم',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
      );
}


