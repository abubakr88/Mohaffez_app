// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Mohafezy';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get students => 'Students';

  @override
  String get teachers => 'Teachers';

  @override
  String get sessions => 'Sessions';

  @override
  String get schedule => 'Schedule';

  @override
  String get profile => 'Profile';

  @override
  String get search => 'Search';

  @override
  String get notifications => 'Notifications';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get settings => 'Settings';

  @override
  String get assignments => 'Assignments';

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get payments => 'Payments';

  @override
  String get rewards => 'Rewards';

  @override
  String get earnings => 'Earnings';

  @override
  String get certificates => 'Certificates';

  @override
  String get pricing => 'Pricing';

  @override
  String get reports => 'Reports';

  @override
  String get users => 'Users';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'An error occurred';

  @override
  String get retry => 'Retry';

  @override
  String get noData => 'No data available';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get findTeacher => 'Find a Teacher';

  @override
  String get mySessions => 'My Sessions';

  @override
  String get myAssignments => 'My Assignments';

  @override
  String get mySubscriptions => 'My Subscriptions';

  @override
  String get overview => 'Overview';

  @override
  String get myStudents => 'My Students';

  @override
  String get pendingApprovals => 'Pending Approvals';

  @override
  String get systemConfig => 'System Config';

  @override
  String get promoCodes => 'Promo Codes';

  @override
  String get badgesAndRecognition => 'Badges and Recognition';

  @override
  String get foundingTeacher => 'Founding Teacher';

  @override
  String get foundingTeacherBadge => 'Founding Teacher Badge';

  @override
  String get grantBadge => 'Grant Badge';

  @override
  String get revokeBadge => 'Revoke Badge';

  @override
  String get grantBadgeTitle => 'Grant Founding Teacher Badge';

  @override
  String get grantBadgeMessage =>
      'Do you want to grant the Founding Teacher badge to this account? The badge will appear on the teacher\'s profile and teacher cards.';

  @override
  String get revokeBadgeTitle => 'Revoke Founding Teacher Badge';

  @override
  String get revokeBadgeMessage =>
      'Do you want to revoke the Founding Teacher badge from this account? It will no longer appear on the teacher\'s profile or teacher cards.';

  @override
  String get grantReasonOptional => 'Grant reason - optional';

  @override
  String get revocationReasonOptional => 'Revocation reason - optional';

  @override
  String get badgeActive => 'Active';

  @override
  String get badgeInactive => 'Inactive';

  @override
  String get grantedAt => 'Granted at';

  @override
  String get grantedBy => 'Granted by';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get internalReason => 'Internal reason';

  @override
  String get reasonTooLong => 'The reason must not exceed 500 characters.';

  @override
  String get badgeGrantedSuccess =>
      'The Founding Teacher badge was granted successfully.';

  @override
  String get badgeRevokedSuccess =>
      'The Founding Teacher badge was revoked successfully.';

  @override
  String get badgePermissionDenied =>
      'You do not have permission to manage teacher badges.';

  @override
  String get badgeInvalidTeacher =>
      'This badge can only be assigned to an active teacher account.';

  @override
  String get badgeActionFailed =>
      'The badge could not be updated. Please try again.';
}
