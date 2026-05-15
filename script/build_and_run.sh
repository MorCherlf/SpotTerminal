#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="SpotTerminal"
BUNDLE_ID="cc.griffino.spotterminal"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_SYSTEM_VERSION="14.0"
UNIVERSAL="${UNIVERSAL:-0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_ICON="$ROOT_DIR/Sources/SpotTerminal/Resources/AppIcon.icns"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ZIP_PATH="$DIST_DIR/$APP_NAME-$APP_VERSION.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-$APP_VERSION.dmg"
DMG_STAGING="$DIST_DIR/dmg-staging"
DMG_BACKGROUND="$DIST_DIR/dmg-background.png"

usage() {
  cat >&2 <<USAGE
usage: $0 [run|--debug|--logs|--telemetry|--verify|--package|--zip|--dmg]

Environment:
  SIGN_IDENTITY    codesign identity, defaults to ad-hoc signing (-)
  BUILD_NUMBER     CFBundleVersion, defaults to 1
  UNIVERSAL         set to 1 to build a universal arm64/x86_64 app
  SKIP_APP_LAUNCH_VERIFY
                    set to 1 to skip packaged app launch verification
USAGE
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$ROOT_DIR"

BUILD_ARGS=()
case "$MODE" in
  --package|package|--zip|zip|--dmg|dmg)
    BUILD_ARGS=(-c release)
    ;;
esac

if [[ "$UNIVERSAL" == "1" && " ${BUILD_ARGS[*]} " == *" -c release "* ]]; then
  mkdir -p "$DIST_DIR"
  swift build -c release --arch arm64
  ARM_PRODUCTS_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
  swift build -c release --arch x86_64
  X86_PRODUCTS_DIR="$(swift build -c release --arch x86_64 --show-bin-path)"
  BUILD_PRODUCTS_DIR="$ARM_PRODUCTS_DIR"
  BUILD_BINARY="$DIST_DIR/$APP_NAME-universal"
  /usr/bin/lipo -create \
    "$ARM_PRODUCTS_DIR/$APP_NAME" \
    "$X86_PRODUCTS_DIR/$APP_NAME" \
    -output "$BUILD_BINARY"
else
  swift build "${BUILD_ARGS[@]}"
  BUILD_PRODUCTS_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
  BUILD_BINARY="$BUILD_PRODUCTS_DIR/$APP_NAME"
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
find "$BUILD_PRODUCTS_DIR" -maxdepth 1 -name '*.bundle' -type d -exec cp -R {} "$APP_RESOURCES/" \;
if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_RESOURCES/SpotTerminal.icns"
fi
find "$ROOT_DIR/Sources/SpotTerminal/Resources" -maxdepth 1 -name '*.lproj' -type d -exec cp -R {} "$APP_RESOURCES/" \;

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Spot Terminal</string>
  <key>CFBundleDisplayName</key>
  <string>Spot Terminal</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
    <string>zh-Hant</string>
    <string>ja</string>
    <string>ru</string>
  </array>
  <key>CFBundleIconFile</key>
  <string>SpotTerminal</string>
  <key>CFBundleIconName</key>
  <string>SpotTerminal</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSUserNotificationAlertStyle</key>
  <string>alert</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null

verify_bundle_resources() {
  local missing=0
  local resource_bundle
  for resource_bundle in SpotTerminal_SpotTerminal.bundle SwiftTerm_SwiftTerm.bundle; do
    if [[ ! -d "$APP_RESOURCES/$resource_bundle" ]]; then
      echo "Missing SwiftPM resource bundle: $APP_RESOURCES/$resource_bundle" >&2
      missing=1
    fi
  done
  if [[ "$missing" != "0" ]]; then
    exit 1
  fi
}

verify_bundle_resources

verify_app_launch() {
  if [[ "${SKIP_APP_LAUNCH_VERIFY:-0}" == "1" ]]; then
    return
  fi

  echo "Verifying packaged app launches..."
  local timeout_seconds="${APP_LAUNCH_TIMEOUT:-30}"
  local settle_seconds="${APP_LAUNCH_SETTLE_SECONDS:-5}"
  local start_seconds
  local app_pid=""
  start_seconds="$(date +%s)"

  if ! /usr/bin/open -n "$APP_BUNDLE"; then
    echo "Packaged app launch verification failed: open returned an error" >&2
    exit 1
  fi

  while [[ -z "$app_pid" ]]; do
    if (( $(date +%s) - start_seconds > timeout_seconds )); then
      echo "Packaged app launch verification timed out waiting for process after ${timeout_seconds}s" >&2
      pkill -x "$APP_NAME" >/dev/null 2>&1 || true
      exit 1
    fi
    app_pid="$(pgrep -x "$APP_NAME" | head -n 1 || true)"
    sleep 1
  done

  sleep "$settle_seconds"
  if ! kill -0 "$app_pid" >/dev/null 2>&1; then
    echo "Packaged app launch verification failed: app exited during launch smoke test" >&2
    exit 1
  fi
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

package_zip() {
  verify_app_launch
  rm -f "$ZIP_PATH"
  (cd "$DIST_DIR" && /usr/bin/ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH")
  echo "$ZIP_PATH"
}

package_dmg() {
  verify_app_launch
  rm -f "$DMG_PATH"
  rm -rf "$DMG_STAGING"
  mkdir -p "$DMG_STAGING/.background"
  swift "$ROOT_DIR/script/generate_dmg_background.swift" "$DMG_BACKGROUND"
  cp -R "$APP_BUNDLE" "$DMG_STAGING/"
  ln -s /Applications "$DMG_STAGING/Applications"
  cp "$DMG_BACKGROUND" "$DMG_STAGING/.background/background.png"

  local rw_dmg="$DIST_DIR/$APP_NAME-$APP_VERSION.rw.dmg"
  rm -f "$rw_dmg"
  /usr/bin/hdiutil create \
    -volname "SpotTerminal" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -fs HFS+ \
    -format UDRW \
    "$rw_dmg" >/dev/null

  if mount_output="$(/usr/bin/hdiutil attach "$rw_dmg" -nobrowse -readwrite 2>/dev/null)"; then
    volume_path="$(printf '%s\n' "$mount_output" | awk '/\/Volumes\/SpotTerminal/ {print substr($0, index($0, "/Volumes/"))}' | tail -n 1)"
    if [[ -n "${volume_path:-}" ]]; then
      cp "$APP_ICON" "$volume_path/.VolumeIcon.icns"
      if [[ ! -f "$volume_path/.VolumeIcon.icns" ]]; then
        echo "DMG volume icon was not copied" >&2
        /usr/bin/hdiutil detach "$volume_path" >/dev/null || true
        exit 1
      fi
      /usr/bin/SetFile -a C "$volume_path" >/dev/null 2>&1 || true
      /usr/bin/chflags hidden "$volume_path/.background" >/dev/null 2>&1 || true
      /usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
  activate
  set volumeFolder to POSIX file "$volume_path" as alias
  set backgroundFile to POSIX file "$volume_path/.background/background.png" as alias
  tell folder volumeFolder
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 760, 548}
    set arrangement of icon view options of container window to not arranged
    set icon size of icon view options of container window to 104
    set text size of icon view options of container window to 12
    set label position of icon view options of container window to bottom
    set background picture of icon view options of container window to backgroundFile
    set position of item "SpotTerminal.app" of container window to {170, 218}
    set position of item "Applications" of container window to {490, 218}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
      if [[ ! -f "$volume_path/.DS_Store" ]]; then
        echo "DMG Finder layout was not written: missing .DS_Store" >&2
        /usr/bin/hdiutil detach "$volume_path" >/dev/null || true
        exit 1
      fi
      sync
      /usr/bin/hdiutil detach "$volume_path" >/dev/null || true
    fi
  fi

  /usr/bin/hdiutil convert "$rw_dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" >/dev/null
  set_dmg_file_icon
  rm -f "$rw_dmg"
  rm -rf "$DMG_STAGING"
  echo "$DMG_PATH"
}

set_dmg_file_icon() {
  local icon_copy="$DIST_DIR/dmg-file-icon.icns"
  local icon_resources="$DIST_DIR/dmg-file-icon.rsrc"
  cp "$APP_ICON" "$icon_copy"
  /usr/bin/sips -i "$icon_copy" >/dev/null
  /usr/bin/DeRez -only icns "$icon_copy" >"$icon_resources"
  /usr/bin/Rez -append "$icon_resources" -o "$DMG_PATH"
  /usr/bin/SetFile -a C "$DMG_PATH"
  rm -f "$icon_copy" "$icon_resources"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    verify_app_launch
    ;;
  --zip|zip)
    package_zip
    ;;
  --package|package)
    package_dmg
    ;;
  --dmg|dmg)
    package_dmg
    ;;
  *)
    usage
    exit 2
    ;;
esac
