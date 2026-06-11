import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../design_system/design_system.dart';
import 'widgets/sidebar.dart';
import 'widgets/topbar.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(currentAdminAccessProvider).valueOrNull ??
        AdminAccessState.none();

    return Scaffold(
      backgroundColor: DSColors.surfaceMuted,
      body: Row(
        children: [
          AppSidebar(
            items: _itemsFor(access),
            roleLabel: access.isSuperAdmin ? 'Super Admin' : 'Admin',
          ),
          Expanded(
            child: Column(
              children: [
                const AppTopbar(title: 'لوحة التحكم'),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<SidebarItem> _itemsFor(AdminAccessState access) {
    final canOpenUsers = access.isSuperAdmin ||
        access.can(AdminPermission.manageUsers) ||
        access.can(AdminPermission.manageUserRoles) ||
        access.can(AdminPermission.deleteUsers);
    final canOpenFinance = access.can(AdminPermission.manageFinance);

    return [
      const SidebarItem(
        icon: Icons.dashboard_outlined,
        label: 'الرئيسية',
        path: '/admin',
      ),
      if (canOpenUsers)
        const SidebarItem(
          icon: Icons.people_outline_rounded,
          label: 'المستخدمون',
          path: '/admin/users',
        ),
      if (access.can(AdminPermission.reviewTeachers))
        const SidebarItem(
          icon: Icons.verified_user_outlined,
          label: 'طلبات التحقق',
          path: '/admin/approvals',
        ),
      if (access.can(AdminPermission.manageUsers) || canOpenFinance)
        const SidebarItem(
          icon: Icons.video_call_outlined,
          label: 'الجلسات',
          path: '/admin/sessions',
        ),
      if (canOpenFinance) ...[
        const SidebarItem(
          icon: Icons.payments_outlined,
          label: 'المدفوعات',
          path: '/admin/payments',
        ),
        const SidebarItem(
          icon: Icons.account_balance_wallet_outlined,
          label: 'طلبات السحب',
          path: '/admin/payouts',
        ),
        const SidebarItem(
          icon: Icons.add_card_outlined,
          label: 'طلبات الشحن',
          path: '/admin/topups',
        ),
        const SidebarItem(
          icon: Icons.discount_outlined,
          label: 'أكواد الخصم',
          path: '/admin/promos',
        ),
        const SidebarItem(
          icon: Icons.bar_chart_rounded,
          label: 'التقارير',
          path: '/admin/reports',
        ),
        const SidebarItem(
          icon: Icons.event_note_outlined,
          label: 'أحداث الدفع',
          path: '/admin/payment-events',
        ),
      ],
      if (access.can(AdminPermission.sendBroadcasts))
        const SidebarItem(
          icon: Icons.campaign_outlined,
          label: 'إشعارات جماعية',
          path: '/admin/broadcast',
        ),
      if (access.can(AdminPermission.runMaintenance))
        const SidebarItem(
          icon: Icons.lock_clock_outlined,
          label: 'قفل الفترات',
          path: '/admin/slot-locks',
        ),
      if (access.isSuperAdmin) ...[
        const SidebarItem(
          icon: Icons.tune_rounded,
          label: 'إعدادات النظام',
          path: '/admin/config',
        ),
        const SidebarItem(
          icon: Icons.history_rounded,
          label: 'سجل العمليات',
          path: '/admin/audit-log',
        ),
      ],
    ];
  }
}
