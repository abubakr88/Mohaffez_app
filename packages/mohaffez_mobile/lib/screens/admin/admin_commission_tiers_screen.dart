// Admin screen for editing the per-teacher commission tier ladder.
//
// Edits `systemConfig/global.commissionTiers` (array). Changes take effect
// for new payments immediately, but each teacher's stored
// `commissionRate` is refreshed only when `recomputeTeacherTiers` runs
// (scheduled weekly, or manually triggered via the button at the bottom).

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../shared/widgets/admin_app_bar.dart';

class AdminCommissionTiersScreen extends ConsumerStatefulWidget {
  const AdminCommissionTiersScreen({super.key});

  @override
  ConsumerState<AdminCommissionTiersScreen> createState() =>
      _AdminCommissionTiersScreenState();
}

class _AdminCommissionTiersScreenState
    extends ConsumerState<AdminCommissionTiersScreen> {
  // Working copy edited in-place; saved to Firestore on demand.
  List<CommissionTierModel>? _draft;
  bool _saving = false;
  bool _recomputing = false;

  void _initDraftFrom(SystemConfigModel cfg) {
    _draft ??= cfg.commissionTiers
        .map((t) => t.copyWith())
        .toList(growable: true);
  }

  List<CommissionTierModel> get _tiers => _draft ?? const [];

  void _addTier() {
    final next = _tiers.isEmpty
        ? const CommissionTierModel(
            id: 'tier_new',
            labelAr: 'مستوى جديد',
            minSessions: 0,
            rate: 0.10,
          )
        : CommissionTierModel(
            id: 'tier_${_tiers.length + 1}',
            labelAr: 'مستوى جديد',
            minSessions: _tiers.last.minSessions + 10,
            rate: (_tiers.last.rate - 0.01).clamp(0.0, 1.0),
          );
    setState(() => _draft = [..._tiers, next]);
  }

  void _removeTier(int index) {
    setState(() => _draft = [..._tiers]..removeAt(index));
  }

  void _patch(int index, CommissionTierModel updated) {
    final next = [..._tiers];
    next[index] = updated;
    setState(() => _draft = next);
  }

  String? _validate() {
    if (_tiers.isEmpty) return 'يجب إضافة مستوى واحد على الأقل';
    final ids = <String>{};
    for (final t in _tiers) {
      if (t.id.trim().isEmpty) return 'كل مستوى يجب أن يكون له معرف';
      if (!ids.add(t.id)) return 'المعرفات يجب أن تكون فريدة (تكرار: ${t.id})';
      if (t.rate < 0 || t.rate > 1) {
        return 'نسبة العمولة في "${t.labelAr}" خارج المدى (0–100%)';
      }
      if (t.minSessions < 0) {
        return 'حد الحلقات في "${t.labelAr}" لا يمكن أن يكون سالباً';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppThemeConstants.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final sorted = [..._tiers]
        ..sort((a, b) => a.minSessions.compareTo(b.minSessions));
      await ref
          .read(systemConfigNotifierProvider.notifier)
          .updateGlobalConfig({
        'commissionTiers': sorted.map((t) => t.toMap()).toList(),
      });
      if (!mounted) return;
      setState(() => _draft = sorted);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ شرائح العمولة'),
          backgroundColor: AppThemeConstants.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runRecomputeNow() async {
    setState(() => _recomputing = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('recomputeTeacherTiersNow');
      final result = await callable.call();
      final processed = (result.data as Map?)?['teachersProcessed'] ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إعادة احتساب $processed محفظ'),
          backgroundColor: AppThemeConstants.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل: $e'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _recomputing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfgAsync = ref.watch(systemConfigProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: 'شرائح العمولة'),
        body: cfgAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (cfg) {
            _initDraftFrom(cfg);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _IntroCard(),
                const SizedBox(height: 12),
                for (var i = 0; i < _tiers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TierEditor(
                      key: ValueKey('tier_$i'),
                      tier: _tiers[i],
                      onChanged: (updated) => _patch(i, updated),
                      onRemove: () => _removeTier(i),
                    ),
                  ),
                Center(
                  child: TextButton.icon(
                    onPressed: _addTier,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة مستوى'),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('حفظ المستويات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary,
                    foregroundColor: AppThemeConstants.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _recomputing ? null : _runRecomputeNow,
                  icon: _recomputing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('إعادة احتساب المستويات الآن'),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeConstants.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppThemeConstants.primary.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  color: AppThemeConstants.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'كيف تعمل المستويات؟',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppThemeConstants.primary),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'يُحسب عدد حلقات كل محفظ المكتملة في وقتها خلال آخر 14 يوماً '
            'تلقائياً مرتين شهرياً (يومَي 1 و15 من كل شهر). كلما زاد عدد '
            'حلقاته، انتقل لشريحة أعلى وانخفضت نسبة العمولة المخصومة. '
            'يمكنك تعديل الحدود والنسب أدناه، ثم الضغط على '
            '"إعادة احتساب الآن" لتطبيق التغييرات فوراً بدلاً من انتظار '
            'الدورة التلقائية.',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _TierEditor extends StatefulWidget {
  final CommissionTierModel tier;
  final ValueChanged<CommissionTierModel> onChanged;
  final VoidCallback onRemove;

  const _TierEditor({
    super.key,
    required this.tier,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_TierEditor> createState() => _TierEditorState();
}

class _TierEditorState extends State<_TierEditor> {
  late final TextEditingController _idCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _badgeCtrl;
  late final TextEditingController _minSessionsCtrl;
  late final TextEditingController _rateCtrl;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: widget.tier.id);
    _labelCtrl = TextEditingController(text: widget.tier.labelAr);
    _badgeCtrl = TextEditingController(text: widget.tier.badge ?? '');
    _minSessionsCtrl = TextEditingController(
        text: widget.tier.minSessions.toString());
    _rateCtrl = TextEditingController(
        text: (widget.tier.rate * 100).toStringAsFixed(2));
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _labelCtrl.dispose();
    _badgeCtrl.dispose();
    _minSessionsCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final minSessions = int.tryParse(_minSessionsCtrl.text) ?? 0;
    final ratePct = double.tryParse(_rateCtrl.text) ?? 0;
    widget.onChanged(widget.tier.copyWith(
      id: _idCtrl.text.trim(),
      labelAr: _labelCtrl.text.trim(),
      badge: _badgeCtrl.text.trim().isEmpty ? null : _badgeCtrl.text.trim(),
      minSessions: minSessions,
      rate: (ratePct / 100).clamp(0.0, 1.0),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppThemeConstants.grey300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالعربية',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _badgeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'شارة',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _emit(),
                ),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline,
                    color: AppThemeConstants.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _idCtrl,
            decoration: const InputDecoration(
              labelText: 'المعرف (id) — أحرف لاتينية',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minSessionsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الحد الأدنى من الحلقات',
                    suffixText: 'حلقة / 14 يوم',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'نسبة العمولة',
                    suffixText: '%',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _emit(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
