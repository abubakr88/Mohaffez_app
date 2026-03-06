import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/suspension_provider.dart';
import '../providers/user_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class SuspendedScreen extends ConsumerStatefulWidget {
  const SuspendedScreen({super.key});

  @override
  ConsumerState<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends ConsumerState<SuspendedScreen> {
  bool _hadSuspension = false;
  bool _isRedirectingAfterLift = false;

  String _homeByRole(String? role) =>
      role == 'admin' ? '/admin-home' : (role == 'mohaffez' ? '/mohaffez-home' : '/home');

  Future<void> _contactSupport() async {
    final whatsappUri = Uri.parse('https://wa.me/201000000000');
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: 'support@mohaffez.com',
      queryParameters: <String, String>{
        'subject': ArabicLabels.accountSuspended,
      },
    );

    final canOpenWhatsApp = await canLaunchUrl(whatsappUri);
    if (!mounted) return;
    if (canOpenWhatsApp) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      if (!mounted) return; // WHY: Guard context after async launch.
      return;
    }

    final canOpenMail = await canLaunchUrl(mailtoUri);
    if (!mounted) return; // WHY: Guard context after async capability check.
    if (canOpenMail) {
      await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      if (!mounted) return; // WHY: Guard context after async launch.
    }
  }

  Future<void> _logout() async {
    // WHY: `AuthNotifier` exposes `logout()` in this codebase (sign-out behavior).
    await ref.read(authNotifierProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final suspensionAsync = ref.watch(currentUserSuspensionProvider);

    ref.listen<AsyncValue<dynamic>>(currentUserSuspensionProvider, (previous, next) {
      next.whenData((suspension) {
        if (suspension != null) {
          _hadSuspension = true;
          _isRedirectingAfterLift = false;
          return;
        }
        if (!_hadSuspension || _isRedirectingAfterLift) return;

        _isRedirectingAfterLift = true;
        // WHY: Route/snackbar are deferred to avoid build-phase navigation.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final homeRoute = _homeByRole(ref.read(currentUserRoleProvider));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(ArabicLabels.suspensionLifted)),
          );
          context.go(homeRoute);
        });
      });
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppThemeConstants.backgroundLight,
          body: SafeArea(
            child: suspensionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (suspension) {
                if (suspension == null) return const SizedBox.shrink();

                _hadSuspension = true;
                final isPermanent = suspension.isPermanent;
                final expiresAt = suspension.expiresAt;
                final theme = Theme.of(context).textTheme;

                return Padding(
                  padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.gpp_bad_rounded,
                            size: 80, // WHY: Required fixed icon size.
                            color: AppThemeConstants.error,
                          ),
                          const SizedBox(height: AppThemeConstants.space2xl),
                          Text(
                            ArabicLabels.accountSuspended,
                            textAlign: TextAlign.center,
                            style: theme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppThemeConstants.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppThemeConstants.spaceMd),
                          Text(
                            ArabicLabels.accountSuspendedSubtitle,
                            textAlign: TextAlign.center,
                            style: theme.bodyMedium?.copyWith(
                              color: AppThemeConstants.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppThemeConstants.spaceLg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
                            decoration: BoxDecoration(
                              // WHY: Use amber-tinted suspension reason card.
                              color: AppThemeConstants.primaryAmber.withValues(alpha: 0.08),
                              borderRadius: AppThemeConstants.borderRadiusMd,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ArabicLabels.suspensionReason,
                                  style: theme.labelLarge?.copyWith(
                                    color: AppThemeConstants.primaryAmber,
                                  ),
                                ),
                                const SizedBox(height: AppThemeConstants.spaceXs),
                                Text(
                                  suspension.reason,
                                  style: theme.bodyMedium?.copyWith(
                                    color: AppThemeConstants.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isPermanent && expiresAt != null) ...[
                            const SizedBox(height: AppThemeConstants.spaceMd),
                            Text(
                              '${ArabicLabels.suspensionExpiry}: ${DateFormat('dd/MM/yyyy', 'ar').format(expiresAt)}',
                              style: theme.bodyMedium?.copyWith(
                                color: AppThemeConstants.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (isPermanent) ...[
                            const SizedBox(height: AppThemeConstants.spaceMd),
                            Text(
                              ArabicLabels.permanentSuspension,
                              style: theme.bodyMedium?.copyWith(
                                color: AppThemeConstants.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: AppThemeConstants.spaceXl),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _contactSupport,
                              icon: const Icon(Icons.support_agent),
                              label: const Text(ArabicLabels.contactSupport),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemeConstants.primaryAmber,
                                foregroundColor: AppThemeConstants.textOnPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppThemeConstants.spaceMd),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _logout,
                              icon: const Icon(Icons.logout),
                              label: const Text(ArabicLabels.logout),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppThemeConstants.error,
                                side: const BorderSide(
                                  color: AppThemeConstants.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
