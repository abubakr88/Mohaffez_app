import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'Mohafezy'**
  String get appName;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @students.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get students;

  /// No description provided for @teachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get teachers;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @assignments.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get assignments;

  /// No description provided for @subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptions;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @rewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewards;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @certificates.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get certificates;

  /// No description provided for @pricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get pricing;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @findTeacher.
  ///
  /// In en, this message translates to:
  /// **'Find a Teacher'**
  String get findTeacher;

  /// No description provided for @mySessions.
  ///
  /// In en, this message translates to:
  /// **'My Sessions'**
  String get mySessions;

  /// No description provided for @myAssignments.
  ///
  /// In en, this message translates to:
  /// **'My Assignments'**
  String get myAssignments;

  /// No description provided for @mySubscriptions.
  ///
  /// In en, this message translates to:
  /// **'My Subscriptions'**
  String get mySubscriptions;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @myStudents.
  ///
  /// In en, this message translates to:
  /// **'My Students'**
  String get myStudents;

  /// No description provided for @pendingApprovals.
  ///
  /// In en, this message translates to:
  /// **'Pending Approvals'**
  String get pendingApprovals;

  /// No description provided for @systemConfig.
  ///
  /// In en, this message translates to:
  /// **'System Config'**
  String get systemConfig;

  /// No description provided for @promoCodes.
  ///
  /// In en, this message translates to:
  /// **'Promo Codes'**
  String get promoCodes;

  /// No description provided for @badgesAndRecognition.
  ///
  /// In en, this message translates to:
  /// **'Badges and Recognition'**
  String get badgesAndRecognition;

  /// No description provided for @foundingTeacher.
  ///
  /// In en, this message translates to:
  /// **'Founding Teacher'**
  String get foundingTeacher;

  /// No description provided for @foundingTeacherBadge.
  ///
  /// In en, this message translates to:
  /// **'Founding Teacher Badge'**
  String get foundingTeacherBadge;

  /// No description provided for @grantBadge.
  ///
  /// In en, this message translates to:
  /// **'Grant Badge'**
  String get grantBadge;

  /// No description provided for @revokeBadge.
  ///
  /// In en, this message translates to:
  /// **'Revoke Badge'**
  String get revokeBadge;

  /// No description provided for @grantBadgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant Founding Teacher Badge'**
  String get grantBadgeTitle;

  /// No description provided for @grantBadgeMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to grant the Founding Teacher badge to this account? The badge will appear on the teacher\'s profile and teacher cards.'**
  String get grantBadgeMessage;

  /// No description provided for @revokeBadgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke Founding Teacher Badge'**
  String get revokeBadgeTitle;

  /// No description provided for @revokeBadgeMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to revoke the Founding Teacher badge from this account? It will no longer appear on the teacher\'s profile or teacher cards.'**
  String get revokeBadgeMessage;

  /// No description provided for @grantReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Grant reason - optional'**
  String get grantReasonOptional;

  /// No description provided for @revocationReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Revocation reason - optional'**
  String get revocationReasonOptional;

  /// No description provided for @badgeActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get badgeActive;

  /// No description provided for @badgeInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get badgeInactive;

  /// No description provided for @grantedAt.
  ///
  /// In en, this message translates to:
  /// **'Granted at'**
  String get grantedAt;

  /// No description provided for @grantedBy.
  ///
  /// In en, this message translates to:
  /// **'Granted by'**
  String get grantedBy;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

  /// No description provided for @internalReason.
  ///
  /// In en, this message translates to:
  /// **'Internal reason'**
  String get internalReason;

  /// No description provided for @reasonTooLong.
  ///
  /// In en, this message translates to:
  /// **'The reason must not exceed 500 characters.'**
  String get reasonTooLong;

  /// No description provided for @badgeGrantedSuccess.
  ///
  /// In en, this message translates to:
  /// **'The Founding Teacher badge was granted successfully.'**
  String get badgeGrantedSuccess;

  /// No description provided for @badgeRevokedSuccess.
  ///
  /// In en, this message translates to:
  /// **'The Founding Teacher badge was revoked successfully.'**
  String get badgeRevokedSuccess;

  /// No description provided for @badgePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to manage teacher badges.'**
  String get badgePermissionDenied;

  /// No description provided for @badgeInvalidTeacher.
  ///
  /// In en, this message translates to:
  /// **'This badge can only be assigned to an active teacher account.'**
  String get badgeInvalidTeacher;

  /// No description provided for @badgeActionFailed.
  ///
  /// In en, this message translates to:
  /// **'The badge could not be updated. Please try again.'**
  String get badgeActionFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
