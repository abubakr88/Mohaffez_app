import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import 'widgets/sidebar.dart';
import 'widgets/topbar.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  static const _items = [
    SidebarItem(icon: Icons.dashboard_outlined,      label: 'الرئيسية',      path: '/admin'),
    SidebarItem(icon: Icons.people_outline_rounded,  label: 'المستخدمون',    path: '/admin/users'),
    SidebarItem(icon: Icons.verified_user_outlined,  label: 'طلبات التحقق', path: '/admin/approvals'),
    SidebarItem(icon: Icons.video_call_outlined,     label: 'الجلسات',       path: '/admin/sessions'),
    SidebarItem(icon: Icons.payments_outlined,       label: 'المدفوعات',     path: '/admin/payments'),
    SidebarItem(icon: Icons.account_balance_wallet_outlined, label: 'طلبات السحب', path: '/admin/payouts'),
    SidebarItem(icon: Icons.add_card_outlined,       label: 'طلبات الشحن',   path: '/admin/topups'),
    SidebarItem(icon: Icons.discount_outlined,       label: 'أكواد الخصم',   path: '/admin/promos'),
    SidebarItem(icon: Icons.tune_rounded,            label: 'إعدادات النظام', path: '/admin/config'),
    SidebarItem(icon: Icons.bar_chart_rounded,       label: 'التقارير',      path: '/admin/reports'),
    SidebarItem(icon: Icons.campaign_outlined,       label: 'إشعارات جماعية', path: '/admin/broadcast'),
    SidebarItem(icon: Icons.lock_clock_outlined,     label: 'قفل الفترات',   path: '/admin/slot-locks'),
    SidebarItem(icon: Icons.event_note_outlined,     label: 'أحداث الدفع',  path: '/admin/payment-events'),
    SidebarItem(icon: Icons.history_rounded,         label: 'سجل العمليات', path: '/admin/audit-log'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.surfaceMuted,
      body: Row(
        children: [
          const AppSidebar(items: _items, roleLabel: 'مدير'),
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
}
