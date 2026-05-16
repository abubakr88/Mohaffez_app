import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../tour_mode_state.dart';

Future<void> showTourRoleChooser(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppThemeConstants.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _TourRoleChooserSheet(),
  );
}

class _TourRoleChooserSheet extends ConsumerWidget {
  const _TourRoleChooserSheet();

  Future<void> _enter(
      BuildContext context, WidgetRef ref, TourRole role) async {
    // Sign out any stale Firebase session before entering tour mode.
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
    ref.read(tourModeProvider.notifier).enter(role);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    context.go(role == TourRole.student ? '/home' : '/mohaffez-home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppThemeConstants.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'جرّب التطبيق',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppThemeConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر الدور الذي تريد استكشاف التطبيق من خلاله. لن يتم حفظ أي بيانات.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppThemeConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.school_outlined,
                title: 'جرّب كطالب',
                subtitle: 'استعرض المحفظين، الحجز، والجلسات',
                onTap: () => _enter(context, ref, TourRole.student),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.menu_book_outlined,
                title: 'جرّب كمحفظ',
                subtitle: 'استعرض الطلاب، الطلبات، والجدول',
                onTap: () => _enter(context, ref, TourRole.mohaffez),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppThemeConstants.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppThemeConstants.primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppThemeConstants.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: AppThemeConstants.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppThemeConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppThemeConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios,
                  size: 14, color: AppThemeConstants.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
