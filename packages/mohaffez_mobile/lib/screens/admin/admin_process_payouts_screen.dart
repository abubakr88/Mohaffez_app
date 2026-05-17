// lib/screens/admin/admin_process_payouts_screen.dart
//
// Admin queue: active payout requests (requested + processing).
//
// Flow on each card:
//   requested  → [بدء المعالجة]  → calls startPayout    (debits teacher)
//   processing → [تم التحويل]    → calls completePayout (admin sent the bank transfer)
//              → [فشل التحويل]   → calls failPayout     (reverses the debit)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../shared/widgets/admin_app_bar.dart';

class AdminProcessPayoutsScreen extends ConsumerWidget {
  const AdminProcessPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(activePayoutsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        appBar: const AdminAppBar(title: 'معالجة طلبات السحب'),
        body: payoutsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ: $e')),
          data: (payouts) {
            if (payouts.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 64, color: AppThemeConstants.success),
                    SizedBox(height: 16),
                    Text('لا توجد طلبات سحب نشطة',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppThemeConstants.textSecondary,
                        )),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
              itemCount: payouts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppThemeConstants.spaceSm),
              itemBuilder: (_, i) => _PayoutCard(payout: payouts[i]),
            );
          },
        ),
      ),
    );
  }
}

class _PayoutCard extends ConsumerStatefulWidget {
  final PayoutRequestModel payout;
  const _PayoutCard({required this.payout});

  @override
  ConsumerState<_PayoutCard> createState() => _PayoutCardState();
}

class _PayoutCardState extends ConsumerState<_PayoutCard> {
  bool _loading = false;

  Future<void> _run(Future<void> Function() op, String successMsg) async {
    setState(() => _loading = true);
    try {
      await op();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.success,
          content: Text(successMsg),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('فشل: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start() => _run(
        () => ref
            .read(walletRepositoryProvider)
            .startPayout(widget.payout.id!),
        'تم بدء المعالجة. خصم الرصيد من المحفظ.',
      );

  Future<void> _complete() async {
    final ref = await _promptReference(context);
    if (ref == null) return;
    return _run(
      () => this
          .ref
          .read(walletRepositoryProvider)
          .completePayout(widget.payout.id!, bankReference: ref),
      'تم تأكيد التحويل',
    );
  }

  Future<void> _fail() async {
    final reason = await _promptReason(
      context,
      title: 'سبب فشل التحويل',
      hint: 'مثال: رقم محفظة غير صحيح',
    );
    if (reason == null || reason.trim().isEmpty) return;
    return _run(
      () => ref
          .read(walletRepositoryProvider)
          .failPayout(widget.payout.id!, reason.trim()),
      'تم تسجيل فشل التحويل وإرجاع الرصيد للمحفظ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payout;
    final isProcessing = p.status == PayoutStatus.processing;
    final dateStr = p.createdAt != null
        ? DateFormat('d MMM y · HH:mm', 'ar').format(p.createdAt!)
        : '';

    return Container(
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeConstants.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    AppThemeConstants.secondary.withValues(alpha: 0.15),
                child: const Icon(Icons.account_balance,
                    color: AppThemeConstants.secondary),
              ),
              const SizedBox(width: AppThemeConstants.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.amountEgp.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        )),
                    Text(
                      p.mohaffezName.isNotEmpty
                          ? p.mohaffezName
                          : p.mohaffezId,
                      style: const TextStyle(
                        color: AppThemeConstants.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Text(dateStr,
                          style: const TextStyle(
                            color: AppThemeConstants.textSecondary,
                            fontSize: 11,
                          )),
                  ],
                ),
              ),
              _StatusBadge(status: p.status),
            ],
          ),
          const SizedBox(height: AppThemeConstants.spaceSm),
          _AccountRow(method: p.method, details: p.accountDetails),
          const SizedBox(height: AppThemeConstants.spaceMd),
          if (!isProcessing)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _start,
                icon: _loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppThemeConstants.white),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('بدء المعالجة (خصم الرصيد)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.primary,
                  foregroundColor: AppThemeConstants.white,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _fail,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('فشل التحويل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemeConstants.error,
                      side:
                          const BorderSide(color: AppThemeConstants.error),
                    ),
                  ),
                ),
                const SizedBox(width: AppThemeConstants.spaceSm),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _complete,
                    icon: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppThemeConstants.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('تم التحويل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.success,
                      foregroundColor: AppThemeConstants.white,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PayoutStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isProcessing = status == PayoutStatus.processing;
    final color =
        isProcessing ? AppThemeConstants.primary : AppThemeConstants.warning;
    final label = isProcessing ? 'قيد المعالجة' : 'بانتظار';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          )),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final PayoutMethod method;
  final String details;
  const _AccountRow({required this.method, required this.details});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppThemeConstants.grey100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(_iconFor(method),
              size: 18, color: AppThemeConstants.textSecondary),
          const SizedBox(width: 8),
          Text(_methodLabel(method),
              style: const TextStyle(
                fontSize: 12,
                color: AppThemeConstants.textSecondary,
              )),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              details,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(PayoutMethod m) {
    switch (m) {
      case PayoutMethod.instapay:
        return Icons.bolt;
      case PayoutMethod.vodafoneCash:
        return Icons.phone_android;
      case PayoutMethod.bankTransfer:
        return Icons.account_balance;
    }
  }

  String _methodLabel(PayoutMethod m) {
    switch (m) {
      case PayoutMethod.instapay:
        return 'إنستاباي';
      case PayoutMethod.vodafoneCash:
        return 'فودافون';
      case PayoutMethod.bankTransfer:
        return 'بنكي';
    }
  }
}

Future<String?> _promptReason(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _promptReference(BuildContext context) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('رقم مرجع التحويل'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اختياري — رقم العملية البنكية',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('تم'),
          ),
        ],
      ),
    ),
  );
}
