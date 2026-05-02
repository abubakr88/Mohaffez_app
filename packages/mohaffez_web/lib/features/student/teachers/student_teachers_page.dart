import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
class StudentTeachersPage extends ConsumerWidget {
  const StudentTeachersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby  = ref.watch(nearbyMohaffezProvider(NearbyParams()));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'البحث عن محفظ',
            subtitle: 'اعثر على محفظ مناسب لبدء رحلة الحفظ',
          ),
          const SizedBox(height: DSSpacing.xxl),
          nearby.when(
            loading: () => const DSSkeletonCard(),
            error:   (_, __) => const DSCard(
              child: DSEmptyState(
                title: 'تعذّر تحميل المحفظين',
                subtitle: 'يرجى المحاولة لاحقاً',
                icon: Icons.person_search_outlined,
              ),
            ),
            data: (teachers) {
              if (teachers.isEmpty) {
                return const DSEmptyState(
                  title: 'لا يوجد محفظون قريبون',
                  subtitle: 'جرّب توسيع نطاق البحث',
                  icon: Icons.person_search_outlined,
                );
              }
              return DSGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 3,
                children: teachers.map((t) => _TeacherCard(teacher: t)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher});
  final MohaffezModel teacher;

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DSAvatar(imageUrl: teacher.photoUrl, name: teacher.name, size: 48),
              const SizedBox(width: DSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teacher.name, style: DSText.bodyMedium(context)),
                    if (teacher.specialization != null)
                      Text(teacher.specialization!, style: DSText.caption(context, color: DSColors.text3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.md),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 14, color: DSColors.secondary),
              const SizedBox(width: 4),
              Text(
                teacher.rating.toStringAsFixed(1),
                style: DSText.caption(context, color: DSColors.text2),
              ),
              const SizedBox(width: DSSpacing.sm),
              Text(
                '(${teacher.followerCount} متابع)',
                style: DSText.caption(context, color: DSColors.text3),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.md),
          SizedBox(
            width: double.infinity,
            child: DSButton(label: 'حجز جلسة', onPressed: () {}),
          ),
        ],
      ),
    );
  }
}
