// lib/services/web_analytics_observer.dart
// NavigatorObserver that logs screen_view events to Firebase Analytics

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

class WebAnalyticsObserver extends NavigatorObserver {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logScreenView(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logScreenView(newRoute);
    }
  }

  void _logScreenView(Route<dynamic> route) {
    final routeName = route.settings.name ?? route.runtimeType.toString();
    _analytics.logScreenView(
      screenName: routeName,
      screenClass: route.runtimeType.toString(),
    );
  }
}
