import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../shared/widgets/admin_app_bar.dart';
import '../../shared/widgets/admin_empty_state.dart';
import '../../shared/theme/app_theme_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class AdminPaymentEventsScreen extends ConsumerStatefulWidget {
  const AdminPaymentEventsScreen({super.key});

  @override
  ConsumerState<AdminPaymentEventsScreen> createState() =>
      _AdminPaymentEventsScreenState();
}

class _AdminPaymentEventsScreenState
    extends ConsumerState<AdminPaymentEventsScreen> {
  String? _selectedEventType;
  DateTime? _fromDate;
  DateTime? _toDate;

  static const Map<String, Map<String, dynamic>> _eventTypeConfig = {
    'paymentcompleted': {'label': 'مكتمل', 'color': AppThemeConstants.success},
    'paymentfailed': {'label': 'فشل', 'color': AppThemeConstants.error},
    'webhookreceived': {'label': 'Webhook', 'color': AppThemeConstants.info},
    'bookingconfirmed': {'label': 'حجز', 'color': AppThemeConstants.primary},
    'subscriptioncreated': {'label': 'اشتراك', 'color': AppThemeConstants.accentPurple},
    'paymentcreated': {'label': 'جديد', 'color': AppThemeConstants.warning},
  };

  static const List<Map<String, dynamic>> _filterChips = [
    {'label': 'الكل', 'value': null},
    {'label': 'مكتمل', 'value': 'paymentcompleted'},
    {'label': 'فشل', 'value': 'paymentfailed'},
    {'label': 'Webhook', 'value': 'webhookreceived'},
    {'label': 'حجز', 'value': 'bookingconfirmed'},
    {'label': 'اشتراك', 'value': 'subscriptioncreated'},
    {'label': 'جديد', 'value': 'paymentcreated'},
  ];

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDate: _fromDate ?? DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _fromDate ?? DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDate: _toDate ?? DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _toDate = picked);
    }
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterEvents(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.where((doc) {
      final data = doc.data();
      
      // Filter by event type
      if (_selectedEventType != null) {
        final eventType = data['eventType']?.toString();
        if (eventType != _selectedEventType) return false;
      }

      // Filter by date range
      final timestamp = data['timestamp'];
      if (timestamp != null) {
        final eventDate = (timestamp as Timestamp).toDate();
        
        if (_fromDate != null) {
          final fromStart = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
          if (eventDate.isBefore(fromStart)) return false;
        }

        if (_toDate != null) {
          final toEnd = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
          if (eventDate.isAfter(toEnd)) return false;
        }
      }

      return true;
    }).toList();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label ✓'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy', 'ar');
    final timeFormat = DateFormat('d MMM • HH:mm', 'ar');

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AdminAppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: 'أحداث المدفوعات',
        ),
        body: Column(
          children: [
            // Section 1: Event Type Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _filterChips.map((chip) {
                  final isSelected = _selectedEventType == chip['value'];
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(
                        chip['label'] as String,
                        style: TextStyle(
                          color: isSelected ? AppThemeConstants.onPrimary : AppThemeConstants.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppThemeConstants.warning,
                      checkmarkColor: AppThemeConstants.onPrimary,
                      onSelected: (selected) {
                        setState(() {
                          _selectedEventType = selected ? chip['value'] as String? : null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // Section 2: Date Range Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _selectFromDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _fromDate != null
                          ? 'من: ${dateFormat.format(_fromDate!)}'
                          : 'من: أي تاريخ',
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _selectToDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _toDate != null
                          ? 'إلى: ${dateFormat.format(_toDate!)}'
                          : 'إلى: الآن',
                    ),
                  ),
                  if (_fromDate != null || _toDate != null)
                    TextButton.icon(
                      onPressed: _clearDateFilter,
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('مسح'),
                    ),
                ],
              ),
            ),

            const Divider(),

            // Section 3: Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('paymentEvents')
                    .orderBy('timestamp', descending: true)
                    .limit(300)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Card(
                        color: AppThemeConstants.errorLight,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'خطأ في تحميل الأحداث: ${snapshot.error}',
                            style: const TextStyle(color: AppThemeConstants.error),
                          ),
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final filteredDocs = _filterEvents(docs);

                  if (filteredDocs.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'لا توجد أحداث مطابقة للفلتر الحالي',
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data();

                      final eventType = data['eventType']?.toString() ?? 'unknown';
                      final timestamp = data['timestamp'] as Timestamp?;
                      final paymentId = data['paymentId']?.toString();
                      final userId = data['userId']?.toString();
                      final transactionId = data['transactionId']?.toString();
                      final extraData = data['data'] as Map<String, dynamic>?;

                      // Get event type config
                      final config = _eventTypeConfig[eventType];
                      final label = config?['label'] as String? ?? eventType;
                      final color = config?['color'] as Color? ?? AppThemeConstants.grey500;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Chip(
                                    label: Text(
                                      label,
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    backgroundColor: color.withValues(alpha: 0.15),
                                    side: BorderSide(color: color, width: 0.8),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  if (timestamp != null)
                                    Text(
                                      timeFormat.format(timestamp.toDate()),
                                      style: const TextStyle(
                                        color: AppThemeConstants.grey600,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Middle rows
                              if (paymentId != null && paymentId.isNotEmpty)
                                _buildIdRow('paymentId', paymentId, 'معرف الدفع'),
                              if (userId != null && userId.isNotEmpty)
                                _buildIdRow('userId', userId, 'معرف المستخدم'),
                              if (transactionId != null && transactionId.isNotEmpty)
                                _buildIdRow('transactionId', transactionId, 'معرف المعاملة'),

                              // Bottom: ExpansionTile
                              if (extraData != null && extraData.isNotEmpty)
                                ExpansionTile(
                                  title: const Text(
                                    'بيانات إضافية',
                                    style: TextStyle(
                                      color: AppThemeConstants.grey600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: EdgeInsets.zero,
                                  children: extraData.entries
                                      .where((e) => e.value != null)
                                      .map((e) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Text(
                                                  e.key,
                                                  style: const TextStyle(
                                                    color: AppThemeConstants.accentAmber,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  e.value.toString(),
                                                  style: const TextStyle(
                                                    color: AppThemeConstants.grey700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdRow(String field, String value, String label) {
    final displayValue = value.length > 14
        ? '${value.substring(0, 14)}...'
        : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppThemeConstants.grey600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            displayValue,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () => _copyToClipboard(value, label),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}



