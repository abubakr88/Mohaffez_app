import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

/// Shown when an account with the `admin` role signs in on the mobile app.
///
/// Platform administration was intentionally removed from the consumer mobile
/// app (it now lives only on the web console). Admins get a clear notice and a
/// way to sign out — no admin UI ships in the public build.
class AdminWebOnlyScreen extends ConsumerWidget {
  const AdminWebOnlyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppThemeConstants.spaceXl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppThemeConstants.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 48,
                      color: AppThemeConstants.primary,
                    ),
                  ),
                  const SizedBox(height: AppThemeConstants.spaceLg),
                  const Text(
                    'لوحة الإدارة على الويب',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppThemeConstants.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppThemeConstants.spaceMd),
                  const Text(
                    'إدارة المنصة متاحة عبر لوحة التحكم على الويب فقط، لأسباب أمنية. '
                    'يرجى استخدام متصفح الويب لتسجيل الدخول إلى لوحة الإدارة.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: AppThemeConstants.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppThemeConstants.spaceXl),
                  SizedBox(
                    width: double.infinity,
                    height: AppThemeConstants.buttonHeightLarge,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(authNotifierProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeConstants.primary,
                        foregroundColor: AppThemeConstants.onPrimary,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppThemeConstants.borderRadiusMd,
                        ),
                      ),
                    ),
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
