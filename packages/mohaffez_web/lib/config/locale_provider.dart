import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(_loadSaved());

  static Locale _loadSaved() {
    try {
      final saved = html.window.localStorage['locale'];
      if (saved == 'en') return const Locale('en');
    } catch (_) {}
    return const Locale('ar');
  }

  void setLocale(Locale locale) {
    state = locale;
    try {
      html.window.localStorage['locale'] = locale.languageCode;
      html.document.documentElement?.setAttribute('lang', locale.languageCode);
      html.document.documentElement?.setAttribute(
        'dir',
        locale.languageCode == 'ar' ? 'rtl' : 'ltr',
      );
    } catch (_) {}
  }

  void toggleLocale() {
    setLocale(state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);
