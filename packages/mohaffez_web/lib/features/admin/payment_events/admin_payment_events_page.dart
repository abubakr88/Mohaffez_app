import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/design_system.dart';
import '../payments/admin_payment_formatters.dart';

class AdminPaymentEventsPage extends ConsumerStatefulWidget {
  const AdminPaymentEventsPage({
    super.key,
    this.initialTypeFilter,
  });

  final String? initialTypeFilter;

  @override
  ConsumerState<AdminPaymentEventsPage> createState() =>
      _AdminPaymentEventsPageState();
}

class _AdminPaymentEventsPageState
    extends ConsumerState<AdminPaymentEventsPage> {
  static const _pageSize = 50;
  static const _eventTypes = <String, String>{
    'payment_created': 'إنشاء عملية دفع',
    'payment_processing': 'بدء معالجة الدفع',
    'webhook_received': 'استلام تأكيد البوابة',
    'payment_completed': 'اكتمال الدفع',
    'payment_failed': 'فشل الدفع',
    'booking_confirmed': 'تأكيد الحجز',
    'subscription_created': 'تفعيل الباقة',
  };

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _eventDocs = [];
  String? _typeFilter;
  String _query = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.initialTypeFilter;
    Future<void>.microtask(() => _loadEvents(reset: true));
  }

  @override
  void didUpdateWidget(covariant AdminPaymentEventsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTypeFilter != widget.initialTypeFilter) {
      _typeFilter = widget.initialTypeFilter;
    }
  }

  Future<void> _loadEvents({required bool reset}) async {
    if (_loadingMore || (!reset && !_hasMore)) return;
    setState(() {
      if (reset) {
        _loading = true;
        _loadError = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('paymentEvents')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);
      if (!reset && _eventDocs.isNotEmpty) {
        query = query.startAfterDocument(_eventDocs.last);
      }
      final snapshot = await query.get();
      if (!mounted) return;
      setState(() {
        if (reset) _eventDocs.clear();
        _eventDocs.addAll(snapshot.docs);
        _hasMore = snapshot.docs.length == _pageSize;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _events {
    final normalizedQuery = _query.trim().toLowerCase();
    return _eventDocs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .where((event) {
      final type = _eventType(event);
      if (_typeFilter != null && type != _typeFilter) return false;
      if (normalizedQuery.isEmpty) return true;
      final metadata = adminMap(event['metadata']);
      final data = adminMap(event['data']);
      final values = <dynamic>[
        event['id'],
        type,
        adminPaymentEventLabel(type),
        event['paymentId'],
        event['userId'],
        event['studentId'],
        event['mohaffezId'],
        metadata['transactionId'],
        data['transactionId'],
        data['sessionId'],
        data['subscriptionId'],
        data['requestId'],
      ];
      return values.any(
        (value) => '$value'.toLowerCase().contains(normalizedQuery),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'أحداث الدفع',
            subtitle: 'مسار زمني واضح لما حدث داخل كل عملية دفع',
            actions: [
              DSButton(
                label: 'تحديث الأحداث',
                onPressed: _loading ? null : () => _loadEvents(reset: true),
                variant: DSButtonVariant.secondary,
                leading: const Icon(Icons.refresh_rounded, size: 17),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          const DSBanner(
            title: 'تحميل منخفض التكلفة',
            message:
                'يتم تحميل 50 حدثاً عند الطلب بدون بث حي مستمر. البحث والتصفية يعملان محلياً داخل السجلات المحملة.',
            variant: DSBannerVariant.info,
          ),
          const SizedBox(height: DSSpacing.xxl),
          Wrap(
            spacing: DSSpacing.md,
            runSpacing: DSSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 380,
                child: DSSearchField(
                  hint: 'Payment ID أو Transaction ID أو User ID',
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              SizedBox(
                width: 240,
                child: DSSelect<String?>(
                  hint: 'كل الأحداث',
                  value: _typeFilter,
                  items: [
                    const DSSelectItem<String?>(
                      label: 'كل الأحداث',
                      value: null,
                    ),
                    ..._eventTypes.entries.map(
                      (entry) => DSSelectItem<String?>(
                        label: entry.value,
                        value: entry.key,
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _typeFilter = value),
                ),
              ),
              Text(
                'المحمّل: ${_eventDocs.length} حدث',
                style: DSText.caption(context, color: DSColors.text3),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          if (_loading)
            const DSSkeletonCard()
          else if (_loadError != null)
            DSBanner(
              title: 'تعذر تحميل أحداث الدفع',
              message: '$_loadError',
              variant: DSBannerVariant.error,
              action: DSButton(
                label: 'إعادة المحاولة',
                onPressed: () => _loadEvents(reset: true),
                size: DSButtonSize.sm,
              ),
            )
          else if (_events.isEmpty)
            const DSCard(
              child: DSEmptyState(
                title: 'لا توجد أحداث مطابقة',
                subtitle: 'غيّر البحث أو نوع الحدث لعرض نتائج أخرى',
                icon: Icons.event_note_outlined,
              ),
            )
          else
            _EventsTable(
              events: _events,
              onOpen: (event) => _showEventDetails(context, event),
            ),
          if (!_loading && _hasMore) ...[
            const SizedBox(height: DSSpacing.lg),
            Center(
              child: DSButton(
                label: 'تحميل 50 حدثاً آخر',
                onPressed:
                    _loadingMore ? null : () => _loadEvents(reset: false),
                loading: _loadingMore,
                variant: DSButtonVariant.secondary,
                leading: const Icon(Icons.expand_more_rounded, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEventDetails(
    BuildContext context,
    Map<String, dynamic> event,
  ) async {
    final type = _eventType(event);
    final data = adminMap(event['data']);
    final metadata = adminMap(event['metadata']);
    final reference = adminTransactionReference(event);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(adminPaymentEventLabel(type)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EventSummary(
                  description: adminPaymentEventDescription(event),
                  variant: adminPaymentEventVariant(type),
                ),
                const SizedBox(height: DSSpacing.md),
                _EventDetailLine(
                  label: 'الوقت الدقيق',
                  value: adminExactTimestamp(
                    event['timestamp'] ?? event['createdAt'],
                  ),
                ),
                _EventDetailLine(
                  label: 'المصدر',
                  value: _sourceLabel('${metadata['source'] ?? '—'}'),
                ),
                _CopyEventDetailLine(
                  label: 'Payment ID',
                  value: '${event['paymentId'] ?? '—'}',
                ),
                _CopyEventDetailLine(
                  label: 'Transaction ID',
                  value: reference,
                ),
                _CopyEventDetailLine(
                  label: 'User ID',
                  value:
                      '${event['userId'] ?? event['studentId'] ?? event['mohaffezId'] ?? '—'}',
                ),
                if ('${data['requestId'] ?? ''}'.isNotEmpty)
                  _CopyEventDetailLine(
                    label: 'Request ID',
                    value: '${data['requestId']}',
                  ),
                if ('${data['sessionId'] ?? ''}'.isNotEmpty)
                  _CopyEventDetailLine(
                    label: 'Session ID',
                    value: '${data['sessionId']}',
                  ),
                if ('${data['subscriptionId'] ?? ''}'.isNotEmpty)
                  _CopyEventDetailLine(
                    label: 'Subscription ID',
                    value: '${data['subscriptionId']}',
                  ),
                if (data['amount'] != null)
                  _EventDetailLine(
                    label: 'المبلغ',
                    value: adminMoney(
                        data['amount'], '${data['currency'] ?? 'EGP'}'),
                  ),
                if ('${data['promoCode'] ?? ''}'.isNotEmpty)
                  _EventDetailLine(
                    label: 'كود الخصم',
                    value: '${data['promoCode']}',
                  ),
                if ('${data['error'] ?? data['failureReason'] ?? ''}'
                    .isNotEmpty)
                  _EventDetailLine(
                    label: 'سبب الفشل',
                    value: '${data['error'] ?? data['failureReason']}',
                    valueColor: DSColors.error,
                  ),
                const SizedBox(height: DSSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    adminBrowserTimezoneLabel(),
                    style: DSText.caption(
                      dialogContext,
                      color: DSColors.text3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          DSButton(
            label: 'إغلاق',
            onPressed: () => Navigator.of(dialogContext).pop(),
            variant: DSButtonVariant.ghost,
          ),
        ],
      ),
    );
  }
}

class _EventsTable extends StatelessWidget {
  const _EventsTable({required this.events, required this.onOpen});

  final List<Map<String, dynamic>> events;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    return DSDataTable<Map<String, dynamic>>(
      initialSortKey: 'timestamp',
      initialSortAsc: false,
      onRowTap: onOpen,
      columns: [
        DSColumnDef(
          key: 'eventType',
          label: 'الحدث',
          width: 180,
          cellBuilder: (ctx, event) {
            final type = _eventType(event);
            return DSBadge(
              label: adminPaymentEventLabel(type),
              variant: adminPaymentEventVariant(type),
            );
          },
        ),
        DSColumnDef(
          key: 'description',
          label: 'ما الذي حدث؟',
          cellBuilder: (ctx, event) => Text(
            adminPaymentEventDescription(event),
            style: DSText.body(ctx),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DSColumnDef(
          key: 'paymentId',
          label: 'Payment ID',
          cellBuilder: (ctx, event) {
            final id = '${event['paymentId'] ?? '—'}';
            return Tooltip(
              message: id,
              child: Text(
                adminShortId(id),
                style: DSText.body(ctx, color: DSColors.text2),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        DSColumnDef(
          key: 'transactionId',
          label: 'Transaction ID',
          cellBuilder: (ctx, event) {
            final reference = adminTransactionReference(event);
            return Tooltip(
              message: reference,
              child: Text(
                adminShortId(reference),
                style: DSText.body(ctx, color: DSColors.text2),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        DSColumnDef(
          key: 'source',
          label: 'المصدر',
          width: 105,
          cellBuilder: (ctx, event) => Text(
            _sourceLabel('${adminMap(event['metadata'])['source'] ?? '—'}'),
            style: DSText.body(ctx, color: DSColors.text2),
          ),
        ),
        DSColumnDef(
          key: 'timestamp',
          label: 'وقت الحدث الدقيق',
          width: 215,
          sortable: true,
          sortValue: (event) =>
              adminPaymentDate(event['timestamp'] ?? event['createdAt']) ??
              DateTime(1970),
          cellBuilder: (ctx, event) => Text(
            adminExactTimestamp(event['timestamp'] ?? event['createdAt']),
            style: DSText.body(ctx, color: DSColors.text2),
          ),
        ),
      ],
      rows: events,
    );
  }
}

class _EventSummary extends StatelessWidget {
  const _EventSummary({required this.description, required this.variant});

  final String description;
  final DSBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final bannerVariant = switch (variant) {
      DSBadgeVariant.success => DSBannerVariant.success,
      DSBadgeVariant.error => DSBannerVariant.error,
      DSBadgeVariant.warning => DSBannerVariant.warning,
      _ => DSBannerVariant.info,
    };
    return DSBanner(message: description, variant: bannerVariant);
  }
}

class _EventDetailLine extends StatelessWidget {
  const _EventDetailLine(
      {required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: DSText.caption(context, color: DSColors.text3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DSText.body(
                context,
                color: valueColor ?? DSColors.text1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyEventDetailLine extends StatelessWidget {
  const _CopyEventDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: DSText.caption(context, color: DSColors.text3),
            ),
          ),
          Expanded(child: SelectableText(value, style: DSText.body(context))),
          IconButton(
            tooltip: 'نسخ',
            onPressed: value == '—'
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم النسخ')),
                    );
                  },
            icon: const Icon(Icons.copy_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

String _eventType(Map<String, dynamic> event) =>
    '${event['eventType'] ?? event['type'] ?? ''}'.trim().toLowerCase();

String _sourceLabel(String source) => switch (source.toLowerCase()) {
      'webhook' => 'بوابة الدفع',
      'client' => 'التطبيق',
      'admin' => 'الإدارة',
      _ => source == '—' || source.isEmpty ? 'غير محدد' : source,
    };
