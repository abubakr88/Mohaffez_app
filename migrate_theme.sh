#!/bin/bash

# Theme Migration Script
# Run from project root: bash migrate_theme.sh

set -e

echo "Starting Theme Migration..."

echo "Creating backup commit if possible..."
git add .
git commit -m "Pre-theme-migration backup" || true

replace_in_files() {
  find lib -name "*.dart" -exec sed -i '' "s/$1/$2/g" {} +
}

echo "Replacing deprecated AppTheme references..."
replace_in_files "AppTheme\\.primaryAmber" "AppThemeConstants.primaryAmber"
replace_in_files "AppTheme\\.lightAmber" "AppThemeConstants.primaryAmberLight"
replace_in_files "AppTheme\\.accentGreen" "AppThemeConstants.accentGreen"

echo "Replacing common color patterns..."
replace_in_files "Colors\\.white" "AppThemeConstants.surfaceWhite"
replace_in_files "Colors\\.grey\\.shade50" "AppThemeConstants.backgroundLight"

echo "Replacing common spacing patterns..."
replace_in_files "SizedBox(height: 16)" "Spacing.vMd"
replace_in_files "SizedBox(height: 24)" "Spacing.vLg"
replace_in_files "SizedBox(height: 32)" "Spacing.vXl"
replace_in_files "SizedBox(height: 8)" "Spacing.vSm"
replace_in_files "SizedBox(width: 16)" "Spacing.hMd"
replace_in_files "SizedBox(width: 24)" "Spacing.hLg"
replace_in_files "SizedBox(width: 8)" "Spacing.hSm"

echo "Replacing common border radius patterns..."
replace_in_files "BorderRadius\\.circular(12)" "AppThemeConstants.borderRadiusMd"
replace_in_files "BorderRadius\\.circular(16)" "AppThemeConstants.borderRadiusLg"
replace_in_files "BorderRadius\\.circular(8)" "AppThemeConstants.borderRadiusSm"

echo "Automated replacements complete"
echo "Manual review still required for text themes and complex layout values"
