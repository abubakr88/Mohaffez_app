import 'package:flutter/material.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

class EmptyStateIllustrations {
  EmptyStateIllustrations._();

  /// No sessions illustration
  static Widget noSessions() {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(
        color: AppThemeConstants.accentBlueLight,
        shape: BoxShape.circle,
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 100,
            color: AppThemeConstants.accentBlue,
          ),
          Positioned(
            bottom: 40,
            child: Icon(
              Icons.close,
              size: 40,
              color: AppThemeConstants.accentBlue,
            ),
          ),
        ],
      ),
    );
  }

  /// No mohaffez nearby illustration
  static Widget noMohaffezNearby() {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(
        color: AppThemeConstants.warningLight,
        shape: BoxShape.circle,
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: 80,
            color: AppThemeConstants.accentOrange,
          ),
          Positioned(
            top: 50,
            right: 50,
            child: Icon(
              Icons.search,
              size: 50,
              color: AppThemeConstants.accentOrange,
            ),
          ),
        ],
      ),
    );
  }

  /// No notifications illustration
  static Widget noNotifications() {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(
        color: AppThemeConstants.accentPurpleLight,
        shape: BoxShape.circle,
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 100,
            color: AppThemeConstants.accentPurple,
          ),
        ],
      ),
    );
  }

  /// No assignments illustration
  static Widget noAssignments() {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(
        color: AppThemeConstants.successLight,
        shape: BoxShape.circle,
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 100,
            color: AppThemeConstants.accentGreenAlt,
          ),
        ],
      ),
    );
  }

  /// No requests illustration
  static Widget noRequests() {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(
        color: AppThemeConstants.accentAmberLight,
        shape: BoxShape.circle,
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.pending_actions,
            size: 100,
            color: AppThemeConstants.accentAmber,
          ),
        ],
      ),
    );
  }

  /// No credentials illustration
  static Widget noCredentials() {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(
        color: AppThemeConstants.accentBlueLight,
        shape: BoxShape.circle,
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.workspace_premium,
            size: 100,
            color: AppThemeConstants.accentBlue,
          ),
        ],
      ),
    );
  }
}
