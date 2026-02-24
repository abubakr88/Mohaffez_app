import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminPromoCodesScreen extends ConsumerWidget {
  const AdminPromoCodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = ref.watch(allPromoCodesProvider);
    final actions = ref.read(adminActionsProvider.notifier);

    Future<void> run(Future<void> Function() op) async {
      await op();
      final st = ref.read(adminActionsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              st.hasError ? AppThemeConstants.error : AppThemeConstants.success,
          content: Text(st.hasError
              ? st.error.toString()
              : ArabicLabels.operationSuccess),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text(ArabicLabels.promoCodes)),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppThemeConstants.primaryAmber,
          child: const Icon(Icons.add),
          onPressed: () => _showCreateSheet(context, actions, run),
        ),
        body: codes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (list) => ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              final active = p['isActive'] == true;
              final expiry = p['expiryDate'];
              final expiryText = expiry is Timestamp
                  ? expiry.toDate().toString().split(' ').first
                  : '-';
              return GestureDetector(
                onLongPress: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text(ArabicLabels.deleteCode),
                      content: const Text(ArabicLabels.confirmDelete),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(ArabicLabels.cancel)),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(ArabicLabels.delete)),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await run(
                        () => actions.deletePromoCode(p['id'].toString()));
                  }
                },
                child: Card(
                  margin: const EdgeInsets.all(AppThemeConstants.spaceSm),
                  child: ListTile(
                    title: Text(p['code']?.toString() ?? '-'),
                    subtitle: Text(
                        '${ArabicLabels.discountPercent}: ${p['discountPercent'] ?? 0}%\n${ArabicLabels.usedCount}: ${p['usedCount'] ?? 0}/${p['usageLimit'] ?? 0}\n${ArabicLabels.expiryDate}: $expiryText'),
                    trailing: Switch(
                      value: active,
                      onChanged: (v) => run(
                          () => actions.togglePromoCode(p['id'].toString(), v)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateSheet(
    BuildContext context,
    AdminActionsNotifier actions,
    Future<void> Function(Future<void> Function()) run,
  ) async {
    final codeCtrl = TextEditingController();
    final usageCtrl = TextEditingController(text: '100');
    double discount = 10;
    bool isActive = true;
    DateTime? expiry;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppThemeConstants.spaceMd,
              right: AppThemeConstants.spaceMd,
              top: AppThemeConstants.spaceMd,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  AppThemeConstants.spaceMd,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                          labelText: ArabicLabels.promoCodeValue)),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  Row(
                    children: [
                      Expanded(
                          child: Text(
                              '${ArabicLabels.discountPercent}: ${discount.toStringAsFixed(0)}%')),
                    ],
                  ),
                  Slider(
                      value: discount,
                      min: 0,
                      max: 100,
                      onChanged: (v) => setState(() => discount = v)),
                  TextField(
                      controller: usageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: ArabicLabels.usageLimit)),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) => setState(() => isActive = v),
                    title: const Text(ArabicLabels.isActive),
                  ),
                  TextButton(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (selected != null) setState(() => expiry = selected);
                    },
                    child: Text(expiry == null
                        ? ArabicLabels.noExpirySet
                        : expiry.toString().split(' ').first),
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  ElevatedButton(
                    onPressed: () async {
                      await run(() => actions.createPromoCode({
                            'code': codeCtrl.text.trim().toUpperCase(),
                            'discountPercent': discount,
                            'usageLimit':
                                int.tryParse(usageCtrl.text.trim()) ?? 0,
                            'expiryDate': expiry != null
                                ? Timestamp.fromDate(expiry!)
                                : null,
                            'isActive': isActive,
                          }));
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text(ArabicLabels.createPromoCode),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
