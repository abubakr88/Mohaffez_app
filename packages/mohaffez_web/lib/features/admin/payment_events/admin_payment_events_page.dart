import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../design_system/design_system.dart';

final _paymentEventsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('paymentEvents')
      .orderBy('timestamp', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

class AdminPaymentEventsPage extends ConsumerStatefulWidget {
  const AdminPaymentEventsPage({super.key});

  @override
  ConsumerState<AdminPaymentEventsPage> createState() =>
      _AdminPaymentEventsPageState();
}

class _AdminPaymentEventsPageState
    extends ConsumerState<AdminPaymentEventsPage> {
  String? _typeFilter;
  String _query = '';

  static const Map<String, String> _typeLabels = {
    'paymentcompleted': 'مكتمل',
    'paymentfailed': 'فشل',
    'webhookreceived': 'Webhook',
    'bookingconfirmed': 'حجز',
    'subscriptioncreated': 'اشتراك',
    'paymentcreated': 'جديد',
  };

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(_paymentEventsProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'أحداث الدفع',
            subtitle:
                'سجل عمليات الدفع وتفاعلات بوابات الدفع (آخر ٢٠٠ حدث)',
          ),
          const SizedBox(height: DSSpacing.lg),
          Row(
            children: [
              SizedBox(
                width: 320,
                child: DSSearchField(
                  hint: 'بحث في النوع، الـ paymentId، أو studentId',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: DSSpacing.md),
              SizedBox(
                width: 220,
                child: DSSelect<String?>(
                  hint: 'كل الأنواع',
                  value: _typeFilter,
                  items: [
                    const DSSelectItem<String?>(label: 'كل الأنواع', value: null),
                    ..._typeLabels.entries.map((e) =>
                        DSSelectItem<String?>(label: e.value, value: e.key)),
                  ],
                  onChanged: (v) => setState(() => _typeFilter = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          Expanded(
            child: eventsAsync.when(
              loading: () => const DSSkeletonCard(),
              error: (e, _) =>
                  DSBanner(message: '$e', variant: DSBannerVariant.error),
              data: (rows) {
                final filtered = rows.where((r) {
                  final type = (r['type'] as String? ?? '').toLowerCase();
                  if (_typeFilter != null &&
                      type != _typeFilter!.toLowerCase()) {
                    return false;
                  }
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  return type.contains(q) ||
                      (r['paymentId'] as String? ?? '')
                          .toLowerCase()
                          .contains(q) ||
                      (r['studentId'] as String? ?? '')
                          .toLowerCase()
                          .contains(q) ||
                      (r['mohaffezId'] as String? ?? '')
                          .toLowerCase()
                          .contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const DSCard(
                    child: DSEmptyState(
                      title: 'لا توجد أحداث',
                      icon: Icons.event_note_outlined,
                    ),
                  );
                }

                return DSCard(
                  child: DSDataTable<Map<String, dynamic>>(
                    columns: [
                      DSColumnDef(
                        key: 'type',
                        label: 'النوع',
                        width: 140,
                        cellBuilder: (ctx, r) => DSBadge(
                          label: _typeLabels[r['type'] as String? ?? ''] ??
                              (r['type'] as String? ?? '—'),
                          variant: _variantFor(r['type'] as String? ?? ''),
                        ),
                      ),
                      DSColumnDef(
                        key: 'paymentId',
                        label: 'paymentId',
                        cellBuilder: (ctx, r) => Text(
                          r['paymentId'] as String? ?? '—',
                          style: DSText.body(ctx),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DSColumnDef(
                        key: 'amount',
                        label: 'المبلغ',
                        width: 120,
                        cellBuilder: (ctx, r) {
                          final amt = r['amount'];
                          if (amt == null) {
                            return Text('—',
                                style: DSText.body(ctx,
                                    color: DSColors.text3));
                          }
                          return Text(
                              '${(amt as num).toStringAsFixed(2)} ج.م',
                              style: DSText.bodyMedium(ctx));
                        },
                      ),
                      DSColumnDef(
                        key: 'userId',
                        label: 'الطالب / المحفظ',
                        cellBuilder: (ctx, r) => Text(
                          r['studentId'] as String? ??
                              r['mohaffezId'] as String? ??
                              r['userId'] as String? ??
                              '—',
                          style: DSText.body(ctx, color: DSColors.text2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DSColumnDef(
                        key: 'timestamp',
                        label: 'التاريخ',
                        width: 160,
                        cellBuilder: (ctx, r) {
                          final ts = r['timestamp'] ?? r['createdAt'];
                          if (ts == null) return const Text('—');
                          try {
                            final dt =
                                ts is DateTime ? ts : (ts as Timestamp).toDate();
                            return Text(
                              DateFormat('dd/MM HH:mm', 'ar').format(dt),
                              style: DSText.body(ctx, color: DSColors.text2),
                            );
                          } catch (_) {
                            return const Text('—');
                          }
                        },
                      ),
                    ],
                    rows: filtered,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DSBadgeVariant _variantFor(String type) {
    switch (type) {
      case 'paymentcompleted':
      case 'bookingconfirmed':
        return DSBadgeVariant.success;
      case 'paymentfailed':
        return DSBadgeVariant.error;
      case 'webhookreceived':
        return DSBadgeVariant.primary;
      default:
        return DSBadgeVariant.neutral;
    }
  }
}
