// lib/screens/admin/admin_wallet_topups_screen.dart
//
// Admin queue: pending top-up requests submitted by users. Admin verifies
// the transfer in their bank app, then taps "تأكيد" to credit the user's
// wallet; or "رفض" with a reason if the transfer couldn't be found.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../shared/widgets/admin_app_bar.dart';

class AdminWalletTopupsScreen extends ConsumerWidget {
  const AdminWalletTopupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topUpsAsync = ref.watch(pendingTopUpsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        appBar: const AdminAppBar(title: 'التحقق من شحنات المحفظة'),
        body: topUpsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ: $e')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 64, color: AppThemeConstants.success),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد طلبات شحن معلقة',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppThemeConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppThemeConstants.spaceSm),
              itemBuilder: (_, i) => _TopUpCard(data: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _TopUpCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _TopUpCard({required this.data});

  @override
  ConsumerState<_TopUpCard> createState() => _TopUpCardState();
}

class _TopUpCardState extends ConsumerState<_TopUpCard> {
  bool _loading = false;

  String get _id => widget.data['id'] as String;
  String get _userId => widget.data['userId'] as String? ?? '';
  double get _amountEgp =>
      (widget.data['amountEgp'] as num?)?.toDouble() ?? 0;
  String get _method => widget.data['method'] as String? ?? '';
  String get _reference =>
      widget.data['referenceNumber'] as String? ?? '';
  DateTime? get _createdAt {
    final v = widget.data['createdAt'];
    if (v == null) return null;
    if (v is DateTime) return v;
    // Firestore Timestamp comes through as a Timestamp object on web, or
    // a Map with seconds/nanoseconds when serialized. The .fromFirestore
    // path uses Timestamp directly; here we get the raw Map so we cope.
    try {
      return (v as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _verify() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(walletRepositoryProvider)
          .verifyWalletTopUp(topUpRequestId: _id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.success,
          content: Text('تم تأكيد الشحن وإضافة الرصيد'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('فشل التأكيد: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final reason = await _promptReason(context);
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(walletRepositoryProvider).rejectWalletTopUp(
            topUpRequestId: _id,
            reason: reason.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.warning,
          content: Text('تم رفض الطلب وإبلاغ المستخدم'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('فشل الرفض: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _createdAt != null
        ? DateFormat('d MMM y · HH:mm', 'ar').format(_createdAt!)
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
                    AppThemeConstants.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.add_card,
                    color: AppThemeConstants.primary),
              ),
              const SizedBox(width: AppThemeConstants.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_amountEgp.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${_methodLabel(_method)} · مرجع: $_reference',
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
            ],
          ),
          const SizedBox(height: AppThemeConstants.spaceSm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppThemeConstants.grey100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 16, color: AppThemeConstants.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _userId,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppThemeConstants.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppThemeConstants.spaceMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _reject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('رفض'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppThemeConstants.error,
                    side: const BorderSide(color: AppThemeConstants.error),
                  ),
                ),
              ),
              const SizedBox(width: AppThemeConstants.spaceSm),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _verify,
                  icon: _loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppThemeConstants.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('تأكيد وإضافة الرصيد'),
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

String _methodLabel(String m) {
  switch (m) {
    case 'instapay':
      return 'إنستاباي';
    case 'vodafone_cash':
      return 'فودافون كاش';
    case 'bank_transfer':
      return 'تحويل بنكي';
    default:
      return m;
  }
}

Future<String?> _promptReason(BuildContext context) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'مثال: لم يصلنا التحويل بهذا الرقم',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeConstants.error,
              foregroundColor: AppThemeConstants.white,
            ),
            child: const Text('رفض'),
          ),
        ],
      ),
    ),
  );
}
