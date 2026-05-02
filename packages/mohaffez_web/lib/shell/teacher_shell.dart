import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import 'widgets/sidebar.dart';
import 'widgets/topbar.dart';

class TeacherShell extends StatelessWidget {
  const TeacherShell({super.key, required this.child});
  final Widget child;

  static const _items = [
    SidebarItem(icon: Icons.dashboard_outlined,              label: 'الرئيسية',      path: '/t'),
    SidebarItem(icon: Icons.people_outline_rounded,          label: 'طلابي',          path: '/t/students'),
    SidebarItem(icon: Icons.calendar_today_outlined,         label: 'الجدول',         path: '/t/schedule'),
    SidebarItem(icon: Icons.video_call_outlined,             label: 'الجلسات',        path: '/t/sessions'),
    SidebarItem(icon: Icons.sell_outlined,                   label: 'التسعير',        path: '/t/pricing'),
    SidebarItem(icon: Icons.workspace_premium_outlined,      label: 'الشهادات',       path: '/t/certificates'),
    SidebarItem(icon: Icons.account_balance_wallet_outlined, label: 'الأرباح',        path: '/t/earnings'),
    SidebarItem(icon: Icons.person_outline_rounded,          label: 'ملفي الشخصي',   path: '/t/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.surfaceMuted,
      body: Row(
        children: [
          const AppSidebar(items: _items, roleLabel: 'محفظ'),
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
