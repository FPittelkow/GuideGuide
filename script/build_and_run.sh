#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/GuideGuide.xcodeproj"
SCHEME="GuideGuide"
CONFIGURATION="Debug"
DERIVED_DATA="$ROOT_DIR/.derivedData"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/GuideGuide.app"

killall GuideGuide >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  build

if [[ "${1:-}" == "--verify" ]]; then
  /usr/bin/open -n "$APP_PATH"
  sleep 2
  pgrep -x GuideGuide >/dev/null
  echo "GuideGuide launched."
  exit 0
fi

/usr/bin/open -n "$APP_PATH"
