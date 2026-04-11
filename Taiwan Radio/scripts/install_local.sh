#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/Taiwan Radio.xcodeproj"
SCHEME="Taiwan Radio"
DERIVED_DATA_PATH="$PROJECT_ROOT/.derived-data"
APP_NAME="Taiwan Radio.app"
BUILD_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME"
INSTALL_PATH="/Applications/$APP_NAME"

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
ditto "$BUILD_APP_PATH" "$INSTALL_PATH"

echo "Installed:"
echo "  $INSTALL_PATH"
