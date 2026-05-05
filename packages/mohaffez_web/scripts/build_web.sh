#!/bin/bash
# Build script for Flutter web deployment
# Usage: ./scripts/build_web.sh [SENTRY_DSN]

set -e

echo "🚀 Building Mohaffez Web for production..."

# Get SENTRY_DSN from argument or environment
SENTRY_DSN="${1:-$SENTRY_DSN}"

if [ -z "$SENTRY_DSN" ]; then
    echo "⚠️  Warning: SENTRY_DSN not set. Error tracking will be disabled."
fi

# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Build for production with CanvasKit renderer
# CanvasKit provides better performance and fidelity on desktop browsers
flutter build web \
    --release \
    --web-renderer canvaskit \
    --pwa-strategy offline-first \
    --dart-define=SENTRY_DSN="$SENTRY_DSN"

# Output build info
echo ""
echo "✅ Build complete!"
echo "📁 Output: packages/mohaffez_web/build/web"
echo ""
echo "📊 Build size report:"
find build/web -name "*.js" -o -name "*.wasm" | xargs du -h | sort -h
