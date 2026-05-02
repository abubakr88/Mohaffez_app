import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/admin_app_bar.dart';
import '../../shared/widgets/admin_empty_state.dart';

class AdminPromoCodesScreen extends ConsumerStatefulWidget {
  const AdminPromoCodesScreen({super.key});

  @override
  ConsumerState<AdminPromoCodesScreen> createState() =>
      _AdminPromoCodesScreenState();
}

class _AdminPromoCodesScreenState extends ConsumerState<AdminPromoCodesScreen> {
  final Set<String> _loadingDeletes = {};
  final Set<String> _loadingToggles = {};
  // ignore: unused_field
  final bool _isLoadingCreate = false;

  @override
  Widget build(BuildContext context) {
    final codes = ref.watch(allPromoCodesProvider);
    final actions = ref.read(adminActionsProvider.notifier);

    Future<void> run(Future<void> Function() op) async {
      await op();
      if (!context.mounted) return;
      final st = ref.read(adminActionsProvider);
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
        appBar: const AdminAppBar(title: ArabicLabels.promoCodes),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppThemeConstants.primary,
          child: const Icon(Icons.add),
          onPressed: () => _showCreateSheet(context, actions, run),
        ),
        body: codes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (list) => list.isEmpty
              ? const AdminEmptyState(
                  icon: Icons.local_offer_outlined,
                  message: 'لا توجد أكواد خصم',
                )
              : RefreshIndicator(
            onRefresh: () async => ref.invalidate(allPromoCodesProvider),
            child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              final promoId = p['id'].toString();
              final active = p['isActive'] == true;
              final expiry = p['expiryDate'];
              final expiryText = expiry is Timestamp
                  ? expiry.toDate().toString().split(' ').first
                  : '-';
              final isDeleting = _loadingDeletes.contains(promoId);
              final isToggling = _loadingToggles.contains(promoId);
              final isLoading = isDeleting || isToggling;

              return Card(
                margin: const EdgeInsets.all(AppThemeConstants.spaceSm),
                child: ListTile(
                  title: InkWell(
                    onTap: () async {
                      final code = p['code']?.toString() ?? '';
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ الكود'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p['code']?.toString() ?? '-'),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy, size: 16, color: AppThemeConstants.primary),
                      ],
                    ),
                  ),
                  subtitle: Text(
                      '${ArabicLabels.discountPercent}: ${p['discountPercent'] ?? 0}%\n${ArabicLabels.usedCount}: ${p['usedCount'] ?? 0}/${p['usageLimit'] ?? 0}\n${ArabicLabels.expiryDate}: $expiryText'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, color: AppThemeConstants.primary),
                        tooltip: 'نسخ الكود',
                        onPressed: () async {
                          final code = p['code']?.toString() ?? '';
                          await Clipboard.setData(ClipboardData(text: code));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم نسخ الكود'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      if (isDeleting)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppThemeConstants.error),
                          onPressed: isLoading ? null : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text(ArabicLabels.deleteCode),
                                content: const Text(ArabicLabels.confirmDelete),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(dialogContext, false),
                                      child: const Text(ArabicLabels.cancel)),
                                  ElevatedButton(
                                      onPressed: () => Navigator.pop(dialogContext, true),
                                      child: const Text(ArabicLabels.delete)),
                                ],
                              ),
                            );
                            if (ok == true) {
                              setState(() => _loadingDeletes.add(promoId));
                              try {
                                await run(() => actions.deletePromoCode(promoId));
                              } finally {
                                if (mounted) setState(() => _loadingDeletes.remove(promoId));
                              }
                            }
                          },
                        ),
                      if (isToggling)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Switch(
                          value: active,
                          onChanged: isLoading ? null : (v) async {
                            setState(() => _loadingToggles.add(promoId));
                            try {
                              await run(() => actions.togglePromoCode(promoId, v));
                            } finally {
                              if (mounted) setState(() => _loadingToggles.remove(promoId));
                            }
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
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
    bool isLoading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
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
                      onChanged: (v) => setSheetState(() => discount = v)),
                  TextField(
                      controller: usageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: ArabicLabels.usageLimit)),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) => setSheetState(() => isActive = v),
                    title: const Text(ArabicLabels.isActive),
                  ),
                  TextButton(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (selected != null) setSheetState(() => expiry = selected);
                    },
                    child: Text(expiry == null
                        ? ArabicLabels.noExpirySet
                        : expiry.toString().split(' ').first),
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      setSheetState(() => isLoading = true);
                      try {
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
                        if (context.mounted) context.pop();
                      } finally {
                        if (context.mounted) setSheetState(() => isLoading = false);
                      }
                    },
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(ArabicLabels.createPromoCode),
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


