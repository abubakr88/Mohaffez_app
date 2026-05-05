import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';

class TeacherSchedulePage extends StatelessWidget {
  const TeacherSchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'الجدول الزمني',
            subtitle: 'إدارة مواعيد جلساتك',
          ),
          SizedBox(height: DSSpacing.xxl),
          DSCard(
            child: DSEmptyState(
              title: 'عرض الجدول قريباً',
              subtitle: 'سيتم إضافة التقويم التفاعلي لإدارة المواعيد في التحديث القادم',
              icon: Icons.calendar_month_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
