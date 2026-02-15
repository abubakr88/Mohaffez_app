# Theme Migration Progress

**Last Updated**: 2026-02-11
**Completion**: 9/32 screens migrated

## Migration Rules

### Replace These Patterns:

#### Colors
- `Colors.grey.shade50` -> `AppThemeConstants.backgroundLight`
- `Colors.white` -> `AppThemeConstants.surfaceWhite`
- `Colors.amber` or `Color(0xFFFFA726)` -> `AppThemeConstants.primaryAmber`
- `Colors.green` or `Color(0xFF66BB6A)` -> `AppThemeConstants.accentGreen`
- `Colors.red` -> `AppThemeConstants.error`
- `Colors.orange` -> `AppThemeConstants.warning`
- `Colors.grey[700]` or similar -> `AppThemeConstants.textSecondary`

#### Spacing
- `SizedBox(height: 4)` -> `Spacing.vXs` or `4.vSpace`
- `SizedBox(height: 8)` -> `Spacing.vSm` or `8.vSpace`
- `SizedBox(height: 16)` -> `Spacing.vMd` or `16.vSpace`
- `SizedBox(height: 24)` -> `Spacing.vLg` or `24.vSpace`
- `SizedBox(height: 32)` -> `Spacing.vXl` or `32.vSpace`
- `SizedBox(width: X)` -> `Spacing.hXs/Sm/Md/Lg/Xl` or `X.hSpace`
- `EdgeInsets.all(8)` -> `EdgeInsets.all(AppThemeConstants.spaceSm)`
- `EdgeInsets.all(16)` -> `EdgeInsets.all(AppThemeConstants.spaceMd)`
- `EdgeInsets.all(24)` -> `EdgeInsets.all(AppThemeConstants.spaceLg)`

#### Border Radius
- `BorderRadius.circular(4)` -> `AppThemeConstants.borderRadiusXs`
- `BorderRadius.circular(8)` -> `AppThemeConstants.borderRadiusSm`
- `BorderRadius.circular(12)` -> `AppThemeConstants.borderRadiusMd`
- `BorderRadius.circular(16)` -> `AppThemeConstants.borderRadiusLg`
- `BorderRadius.circular(24)` or `(30)` -> `AppThemeConstants.borderRadiusXl`
- `BorderRadius.circular(999)` -> `AppThemeConstants.borderRadiusRound`

#### Elevation
- `elevation: 0` -> `AppThemeConstants.elevationNone`
- `elevation: 1` -> `AppThemeConstants.elevationXs`
- `elevation: 2` -> `AppThemeConstants.elevationSm`
- `elevation: 4` -> `AppThemeConstants.elevationMd`
- `elevation: 8` -> `AppThemeConstants.elevationLg`

#### Deprecated Constants
- `AppTheme.primaryAmber` -> `AppThemeConstants.primaryAmber`
- `AppTheme.lightAmber` -> `AppThemeConstants.primaryAmberLight`
- `AppTheme.accentGreen` -> `AppThemeConstants.accentGreen`

## Phase Progress

Phase 1 (Core): [¦¦¦¦¦¦¦¦¦¦] 3/3 screens
Phase 2 (Student): [¦¦¦¦¦¦¦¦¦¦] 0/6 screens
Phase 3 (Mohaffez): [¦¦¦¦¦¦¦¦¦¦] 0/9 screens
Phase 4 (Shared): [¦¦¦¦¦¦¦¦¦¦] 1/4 screens
Phase 5 (Payment): [¦¦¦¦¦¦¦¦¦¦] 3/3 screens
Phase 6 (Widgets): [¦¦¦¦¦¦¦¦¦¦] 0/6 components
Phase 7 (Cleanup): [¦¦¦¦¦¦¦¦¦¦] 0/4 tasks

Overall: [¦¦¦¦¦¦¦¦¦¦] ~40% complete


## Current Metrics
- Deprecated AppTheme refs: 179
- Hardcoded Colors refs: 905
- Hardcoded SizedBox refs: 585
- Hardcoded BorderRadius.circular refs: 219

