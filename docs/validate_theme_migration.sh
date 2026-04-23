#!/bin/bash

echo "Validating Theme Migration..."
echo

echo "Checking deprecated AppTheme references..."
DEPRECATED_COUNT=$(grep -r "AppTheme\." lib/ --include="*.dart" | wc -l)
echo "Found: $DEPRECATED_COUNT references"
if [ "$DEPRECATED_COUNT" -gt 0 ]; then
  grep -r "AppTheme\." lib/ --include="*.dart" -l
fi

echo
echo "Checking hardcoded Colors..."
COLORS_COUNT=$(grep -r "Colors\." lib/ --include="*.dart" | grep -v "AppThemeConstants" | grep -v "// ignore" | wc -l)
echo "Found: $COLORS_COUNT references"

echo
echo "Checking hardcoded spacing..."
SPACING_COUNT=$(grep -rE "SizedBox\(height: [0-9]|SizedBox\(width: [0-9]" lib/ --include="*.dart" | wc -l)
echo "Found: $SPACING_COUNT hardcoded SizedBox references"

echo
echo "Checking hardcoded border radius..."
RADIUS_COUNT=$(grep -r "BorderRadius\.circular([0-9]" lib/ --include="*.dart" | wc -l)
echo "Found: $RADIUS_COUNT hardcoded radius references"

echo
echo "Running flutter analyze (infos are non-fatal)..."
flutter analyze --no-fatal-infos || true

echo
echo "Summary"
echo "Deprecated AppTheme refs: $DEPRECATED_COUNT"
echo "Hardcoded Colors: $COLORS_COUNT"
echo "Hardcoded SizedBox: $SPACING_COUNT"
echo "Hardcoded BorderRadius: $RADIUS_COUNT"
