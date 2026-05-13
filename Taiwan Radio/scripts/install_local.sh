#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/Taiwan Radio.xcodeproj"
SCHEME="Taiwan Radio"
APP_NAME="Taiwan Radio.app"
INSTALL_PATH="/Applications/$APP_NAME"
DERIVED_DATA_PATH="$(mktemp -d "${TMPDIR:-/tmp}/taiwan-radio-build.XXXXXX")"
BUILD_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME"

cleanup() {
  rm -rf "$DERIVED_DATA_PATH"
}

trap cleanup EXIT

echo "Using derived data at:"
echo "  $DERIVED_DATA_PATH"

echo "Building $SCHEME (Release)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -d "$BUILD_APP_PATH" ]]; then
  echo "Build succeeded but app was not found at:"
  echo "  $BUILD_APP_PATH"
  exit 1
fi

echo "Stopping running app if needed..."
pkill -x "Taiwan Radio" || true

echo "Installing to /Applications..."
if [[ -d "$INSTALL_PATH" ]]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -u "$INSTALL_PATH" 2>/dev/null || true
  rm -rf "$INSTALL_PATH"
fi

ditto "$BUILD_APP_PATH" "$INSTALL_PATH"
touch "$INSTALL_PATH"

echo "Refreshing LaunchServices and Launchpad icon cache..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$INSTALL_PATH" 2>/dev/null || true
killall Dock 2>/dev/null || true

echo "Installed:"
echo "  $INSTALL_PATH"
