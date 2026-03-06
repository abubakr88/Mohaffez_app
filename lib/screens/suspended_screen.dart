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
  bool _isRedirecting = false;

  String _homeByRole(String? role) {
    if (role == 'admin') return '/admin-home';
    if (role == 'mohaffez') return '/mohaffez-home';
    return '/home';
  }

  void _redirectAfterUnsuspend() {
    if (_isRedirecting) return;
    _isRedirecting = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final role = ref.read(currentUserRoleProvider);
      final home = _homeByRole(role);

      // WHY: Inform the user in real-time that access has been restored.
      if (_hadSuspension) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ArabicLabels.suspensionLifted)),
        );
      }
      context.go(home);
    });
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@almohaffez.app',
      queryParameters: <String, String>{
        'subject': ArabicLabels.accountSuspended,
      },
    );

    final canLaunch = await canLaunchUrl(uri);
    if (!mounted) return;

    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final suspensionStream = ref.watch(currentUserSuspensionProvider.stream);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppThemeConstants.backgroundLight,
          body: SafeArea(
            child: StreamBuilder(
              stream: suspensionStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final suspension = snapshot.data;
                if (suspension == null) {
                  _redirectAfterUnsuspend();
                  return const SizedBox.shrink();
                }

                _hadSuspension = true;

                final hasExpiry =
                    !suspension.isPermanent && suspension.expiresAt != null;
                final expiryText = hasExpiry
                    ? DateFormat('dd/MM/yyyy', 'ar')
                        .format(suspension.expiresAt!)
                    : ArabicLabels.permanentSuspension;

                return Padding(
                  padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.gpp_bad_rounded,
                            size: AppThemeConstants.icon3xl,
                            color: AppThemeConstants.error,
                          ),
                          const SizedBox(height: AppThemeConstants.spaceLg),
                          const Text(
                            ArabicLabels.accountSuspended,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppThemeConstants.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppThemeConstants.spaceSm),
                          const Text(
                            ArabicLabels.accountSuspendedSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppThemeConstants.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppThemeConstants.spaceLg),
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.all(AppThemeConstants.spaceMd),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.surfaceWhite,
                              borderRadius: AppThemeConstants.borderRadiusMd,
                              border: Border.all(color: AppThemeConstants.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  ArabicLabels.suspensionReason,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppThemeConstants.textPrimary,
                                  ),
                                ),
                                const SizedBox(
                                  height: AppThemeConstants.spaceSm,
                                ),
                                Text(
                                  suspension.reason,
                                  style: const TextStyle(
                                    color: AppThemeConstants.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppThemeConstants.spaceMd),
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.all(AppThemeConstants.spaceMd),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.surfaceWhite,
                              borderRadius: AppThemeConstants.borderRadiusMd,
                              border: Border.all(color: AppThemeConstants.divider),
                            ),
                            child: Text(
                              '${ArabicLabels.suspensionExpiry}: $expiryText',
                              style: const TextStyle(
                                color: AppThemeConstants.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppThemeConstants.spaceLg),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _contactSupport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemeConstants.primaryAmber,
                                foregroundColor: AppThemeConstants.textOnPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppThemeConstants.spaceMd,
                                ),
                              ),
                              child: const Text(ArabicLabels.contactSupport),
                            ),
                          ),
                          const SizedBox(height: AppThemeConstants.spaceSm),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _logout,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppThemeConstants.textPrimary,
                                side: const BorderSide(
                                  color: AppThemeConstants.divider,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppThemeConstants.spaceMd,
                                ),
                              ),
                              child: const Text(ArabicLabels.logout),
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
