import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/add_pricing_plan_sheet.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';
import '../../tour/tour_guard_helper.dart';

class MohaffezPricingScreen extends ConsumerWidget {
  const MohaffezPricingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(child: Text('الرجاء تسجيل الدخول')),
            ),
          );
        }

        final mohaffezId = user.uid;
        final plansAsync = ref.watch(pricingPlansProvider(mohaffezId));

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              // CHANGED: Clean Arabic UTF-8 text.
              title: const Text('إدارة الأسعار'),
            ),
            body: plansAsync.when(
              data: (plans) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(pricingPlansProvider(mohaffezId));
                  await ref
                      .read(pricingPlansProvider(mohaffezId).future)
                      .catchError((_) => <PricingPlanModel>[]);
                },
                child: _buildPlansList(context, ref, plans, mohaffezId),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorDisplay.dataLoad(
                onRetry: () {
                  ref.invalidate(pricingPlansProvider(mohaffezId));
                },
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                if (guardWriteInTour(ref, context)) return;
                _showAddPlanDialog(context, ref, mohaffezId);
              },
              icon: const Icon(Icons.add),
              label: const Text('إضافة خطة تسعير'),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('حدث خطأ. يرجى المحاولة مرة أخرى')),
      ),
    );
  }

  Widget _buildPlansList(
    BuildContext context,
    WidgetRef ref,
    List<PricingPlanModel> plans,
    String mohaffezId,
  ) {
    if (plans.isEmpty) {
      return const EmptyState(
        icon: Icons.payments_outlined,
        title: 'لم تقم بإضافة أي خطط تسعير',
        message: 'أضف خططك الآن لتمكين الطلاب من الحجز',
      );
    }

    final onlinePlans =
        plans.where((p) => p.mode == SessionMode.online).toList();
    final homePlans = plans.where((p) => p.mode == SessionMode.home).toList();
    final mosquePlans =
        plans.where((p) => p.mode == SessionMode.mosque).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (onlinePlans.isNotEmpty) ...[
          _buildSectionHeader(ArabicLabels.onlineSession, Icons.videocam),
          ...onlinePlans.map((plan) => PricingPlanCard(
                plan: plan,
                mohaffezId: mohaffezId,
              )),
          const SizedBox(height: 24),
        ],
        if (homePlans.isNotEmpty) ...[
          _buildSectionHeader(ArabicLabels.homeSession, Icons.home),
          ...homePlans.map((plan) => PricingPlanCard(
                plan: plan,
                mohaffezId: mohaffezId,
              )),
          const SizedBox(height: 24),
        ],
        if (mosquePlans.isNotEmpty) ...[
          _buildSectionHeader(ArabicLabels.mosqueSession, Icons.mosque),
          ...mosquePlans.map((plan) => PricingPlanCard(
                plan: plan,
                mohaffezId: mohaffezId,
              )),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 8),
      child: Row(
        children: [
          Icon(icon, color: AppThemeConstants.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPlanDialog(
    BuildContext context,
    WidgetRef ref,
    String mohaffezId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddPricingPlanSheet(mohaffezId: mohaffezId),
    );
  }
}

class PricingPlanCard extends ConsumerWidget {
  final PricingPlanModel plan;
  final String mohaffezId;

  const PricingPlanCard({
    super.key,
    required this.plan,
    required this.mohaffezId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getPlanDescription(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppThemeConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${plan.priceEGP.toStringAsFixed(0)} ${ArabicLabels.currency}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppThemeConstants.secondary,
                      ),
                    ),
                    if (plan.sessionsCount > 1)
                      Text(
                        '${(plan.priceEGP / plan.sessionsCount).toStringAsFixed(0)} ${ArabicLabels.currency}/${ArabicLabels.singleSession}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppThemeConstants.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  '${plan.sessionsCount} جلسة',
                  Icons.event_available,
                ),
                if (plan.sessionsPerWeek != null)
                  _buildChip(
                    '${plan.sessionsPerWeek}x أسبوعياً',
                    Icons.calendar_today,
                  ),
                if (plan.validityDays != null)
                  _buildChip(
                    'صالح لـ ${plan.validityDays} يوم',
                    Icons.schedule,
                  ),
              ],
            ),
            if (plan.description != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeConstants.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  plan.description!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppThemeConstants.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: plan.isActive,
                  onChanged: (val) => _togglePlanStatus(context, ref, val),
                  activeThumbColor: AppThemeConstants.secondary,
                ),
                const Text('مفعل'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () {
                    if (guardWriteInTour(ref, context)) return;
                    _editPlan(context, ref);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: AppThemeConstants.error),
                  onPressed: () {
                    if (guardWriteInTour(ref, context)) return;
                    _deletePlan(context, ref);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? AppThemeConstants.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (color ?? AppThemeConstants.primary).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppThemeConstants.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? AppThemeConstants.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _getPlanDescription() {
    switch (plan.type) {
      case PlanType.single:
        return ArabicLabels.singleSession;
      case PlanType.bundle:
        return '${ArabicLabels.sessionPackage} ${plan.sessionsCount}';
    }
  }

  void _togglePlanStatus(BuildContext context, WidgetRef ref, bool isActive) {
    ref.read(pricingActionsProvider.notifier).updatePlanStatus(
          mohaffezId,
          plan.id!,
          isActive,
        );
  }

  void _editPlan(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddPricingPlanSheet(
        mohaffezId: mohaffezId,
        existingPlan: plan,
      ),
    );
  }

  void _deletePlan(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف خطة التسعير'),
          content: const Text('هل أنت متأكد من حذف هذه الخطة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppThemeConstants.error),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await ref.read(pricingActionsProvider.notifier).deletePlan(
            plan.id!,
            mohaffezId,
          );
    }
  }
}
