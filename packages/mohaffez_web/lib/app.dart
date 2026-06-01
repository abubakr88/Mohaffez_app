import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/locale_provider.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'l10n/generated/app_localizations.dart';

class MohaffezWebApp extends ConsumerWidget {
  const MohaffezWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final router = ref.watch(webRouterProvider);

    return MaterialApp.router(
      title: 'Mohafezy | محفظي',
      debugShowCheckedModeBanner: false,
      theme: DSTheme.light(locale),
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
