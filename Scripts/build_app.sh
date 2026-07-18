#!/bin/zsh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
(
    cd "$ROOT"
    swift build -c "$CONFIGURATION" --product Timezoner
)
BIN_PATH="$(cd "$ROOT" && swift build -c "$CONFIGURATION" --show-bin-path)"
STAGING_ROOT="$(mktemp -d /private/tmp/timezoner-build.XXXXXX)"
APP_PATH="$STAGING_ROOT/Timezoner.app"
CONTENTS_PATH="$APP_PATH/Contents"
ARCHIVE_PATH="$ROOT/dist/Timezoner-$(date +%Y%m%d-%H%M%S).zip"

mkdir -p "$ROOT/dist"
mkdir -p "$CONTENTS_PATH/MacOS"
mkdir -p "$CONTENTS_PATH/Resources/en.lproj"

ditto "$BIN_PATH/Timezoner" "$CONTENTS_PATH/MacOS/Timezoner"
ditto "$ROOT/Config/Info.plist" "$CONTENTS_PATH/Info.plist"
ditto "$ROOT/Resources/en.lproj/Localizable.strings" "$CONTENTS_PATH/Resources/en.lproj/Localizable.strings"
ditto "$ROOT/Resources/THIRD_PARTY_NOTICES.txt" "$CONTENTS_PATH/Resources/THIRD_PARTY_NOTICES.txt"

if [[ -f "$ROOT/Assets/Timezoner.icns" ]]; then
    ditto "$ROOT/Assets/Timezoner.icns" "$CONTENTS_PATH/Resources/Timezoner.icns"
fi

plutil -lint "$CONTENTS_PATH/Info.plist"
xattr -cr "$APP_PATH"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

ditto -c -k --norsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"

VERIFY_ROOT="$(mktemp -d /private/tmp/timezoner-verify.XXXXXX)"
ditto -x -k --norsrc "$ARCHIVE_PATH" "$VERIFY_ROOT"
codesign --verify --deep --strict "$VERIFY_ROOT/Timezoner.app"

echo "$ARCHIVE_PATH"
