import 'package:cloud_functions/cloud_functions.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class AppVersionService {
  static Future<void> checkOnStartup(BuildContext context) async {
    try {
      final container = ProviderScope.containerOf(context);
      final devMode = container.read(devModeProvider).valueOrNull;
      if (devMode?.skipAppVersionCheck == true) {
        debugPrint('⏭️ Version check skipped (dev mode)');
        return;
      }

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final callable =
          FirebaseFunctions.instance.httpsCallable('checkAppVersion');
      final result = await callable.call({'currentVersion': currentVersion});
      final data =
          (result.data as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
      final status = data['status']?.toString() ?? 'ok';
      final version = data['version']?.toString() ?? '';

      if (!context.mounted) return;

      if (status == 'required') {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('يجب تحديث التطبيق'),
              content: Text('الإصدار المطلوب: $version'),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    final uri = Uri.parse('https://play.google.com/store');
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: const Text('تحديث الآن'),
                ),
              ],
            ),
          ),
        );
        return;
      }

      if (status == 'recommended') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يتوفر تحديث جديد')),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Version check failed silently: $e');
    }
  }
}
