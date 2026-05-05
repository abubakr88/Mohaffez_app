import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import 'widgets/sidebar.dart';
import 'widgets/topbar.dart';

class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.child});
  final Widget child;

  static const _items = [
    SidebarItem(icon: Icons.dashboard_outlined,      label: 'الرئيسية',       path: '/s'),
    SidebarItem(icon: Icons.search_rounded,           label: 'البحث عن محفظ',  path: '/s/teachers'),
    SidebarItem(icon: Icons.calendar_month_outlined,  label: 'جلساتي',          path: '/s/sessions'),
    SidebarItem(icon: Icons.assignment_outlined,      label: 'مهامي',           path: '/s/assignments'),
    SidebarItem(icon: Icons.card_membership_outlined, label: 'اشتراكاتي',       path: '/s/subscriptions'),
    SidebarItem(icon: Icons.workspace_premium_outlined, label: 'مكافآتي',       path: '/s/rewards'),
    SidebarItem(icon: Icons.person_outline_rounded,   label: 'ملفي الشخصي',     path: '/s/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.surfaceMuted,
      body: Row(
        children: [
          const AppSidebar(items: _items, roleLabel: 'طالب'),
          Expanded(
            child: Column(
              children: [
                AppTopbar(title: _titleFor(context)),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleFor(BuildContext context) {
    // Will be refined per-route in Prompt 5
    return 'لوحة التحكم';
  }
}
