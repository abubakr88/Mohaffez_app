# Theme Consolidation Migration Checklist

## Phase 1: Setup ?
- [x] Create `lib/shared/theme/app_theme_constants.dart`
- [x] Create `lib/shared/theme/app_theme_data.dart`
- [x] Create `lib/shared/theme/theme_extensions.dart`
- [x] Update `lib/main.dart` to use `AppThemeData.lightTheme`
- [x] Deprecate old `lib/shared/constants/app_theme.dart`

## Phase 2: Screen Migration (Priority Order)

### Core Screens
- [ ] `splash_screen.dart` (in `app_router.dart`)
- [ ] `login_screen.dart`
- [ ] `student_home.dart`
- [ ] `mohaffez_home.dart`

### Student Screens
- [ ] `nearby_mohaffez_screen.dart`
- [ ] `mohaffez_profile_screen.dart`
- [ ] `student_payment_screen.dart`
- [ ] `session_details_screen.dart`
- [ ] `student_requests_screen.dart`

### Mohaffez Screens
- [ ] `pending_requests_screen.dart`
- [ ] `upcoming_sessions_screen.dart`
- [ ] `completed_sessions_screen.dart`
- [ ] `session_completion_screen.dart`
- [ ] `mohaffez_pricing_screen.dart`

### Shared Screens
- [ ] `profile_screen.dart`
- [ ] `notifications_screen.dart`
- [ ] `settings_screen.dart`

### Widget Components
- [ ] Shared widgets in `lib/shared/widgets/`
- [ ] Custom form fields
- [ ] Card components

## Phase 3: Cleanup
- [ ] Remove all `Colors.` direct references (except framework semantics)
- [ ] Remove hardcoded spacing values
- [ ] Remove hardcoded border radius values
- [ ] Remove old `app_theme.dart` after migration is complete
- [ ] Run `flutter analyze` and resolve warnings/errors related to theming
- [ ] Test theme on multiple screen sizes and densities

## Verification
- [ ] All screens render correctly
- [ ] No hardcoded color values remain in migrated files
- [ ] Consistent spacing throughout app
- [ ] Theme customization possible from constants file only