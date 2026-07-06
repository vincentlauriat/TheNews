#!/usr/bin/env bash
# Build → sign (Developer ID + Hardened Runtime) → DMG → notarize → staple.
# Generic macOS release pipeline (no Sparkle auto-update).
#
# Usage:   ./Scripts/release.sh <version>
# Example: ./Scripts/release.sh 1.0.0
#
# Reuses Vincent's shared Apple credentials (same account for all Mac apps):
#   - Developer ID Application: Vincent LAURIAT (KFLACS69T9)
#   - notary keychain profile "AppliMacVincentGithub" (apple-id vincent@lauriat.fr)
# If you ever need to recreate the profile:
#   xcrun notarytool store-credentials "AppliMacVincentGithub" \
#     --apple-id "vincent@lauriat.fr" --team-id "KFLACS69T9"
#
# Overridable via env: APP_NAME, SCHEME, PROJECT, SIGNING_IDENTITY, NOTARY_PROFILE
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "usage: $0 <version>   (e.g. $0 1.0.0)" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ── Project identity (bootstrap.sh rewrites these when you clone the template) ──
APP_NAME="${APP_NAME:-TheNews}"      # PRODUCT_NAME / .app bundle name
SCHEME="${SCHEME:-TheNews}"           # macOS scheme (see project.yml)
PROJECT="${PROJECT:-TheNews.xcodeproj}"

DMG_SLUG="$(echo "$APP_NAME" | tr -d ' ')"
DMG_VOLNAME="$APP_NAME $VERSION"
DMG="$ROOT/$DMG_SLUG-$VERSION.dmg"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Vincent LAURIAT (KFLACS69T9)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AppliMacVincentGithub}"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

echo "▶︎ Releasing $APP_NAME $VERSION (build $BUILD_NUMBER)"

# 1. Regenerate the Xcode project from project.yml
echo "▶︎ xcodegen generate"
xcodegen generate >/dev/null

# 2. Build Release. CODE_SIGNING_ALLOWED=NO avoids the macOS Sequoia
#    com.apple.provenance xattr that breaks CLI codesign; we sign manually below.
echo "▶︎ xcodebuild Release"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath build \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null
APP="$ROOT/build/Build/Products/Release/$APP_NAME.app"
[ -d "$APP" ] || { echo "✗ App not found: $APP" >&2; exit 1; }

# 3. Stage to a clean dir, stripping extended attributes
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT
STAGING="$STAGING_DIR/$APP_NAME.app"
ditto --norsrc --noextattr --noacl "$APP" "$STAGING"

# 4. Codesign the app with Hardened Runtime + secure timestamp (retry: Apple TS is flaky)
codesign_ts() {
  local target="$1" i
  for i in 1 2 3 4 5; do
    if codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$target"; then
      return 0
    fi
    echo "  …codesign retry $i/5 (timestamp server) in 5s" >&2
    sleep 5
  done
  echo "✗ codesign failed for $target" >&2
  return 1
}
echo "▶︎ codesign (Developer ID, Hardened Runtime)"
# Sign nested code first (e.g. the WidgetKit extension) — codesign refuses to
# seal a wrapping bundle whose embedded components aren't already signed.
if [ -d "$STAGING/Contents/PlugIns" ]; then
  while IFS= read -r -d '' appex; do
    echo "  … signing $(basename "$appex")"
    codesign_ts "$appex"
  done < <(find "$STAGING/Contents/PlugIns" -maxdepth 1 -name "*.appex" -print0)
fi
codesign_ts "$STAGING"
codesign --verify --strict --deep --verbose=1 "$STAGING"

# 5. Build the DMG with a custom Finder layout
echo "▶︎ build DMG"
DMG_LAYOUT="$STAGING_DIR/dmg-layout"
mkdir -p "$DMG_LAYOUT/.background"
ditto --norsrc --noextattr --noacl "$STAGING" "$DMG_LAYOUT/$APP_NAME.app"
ln -s /Applications "$DMG_LAYOUT/Applications"
"$ROOT/Scripts/make-dmg-background.swift" "$DMG_LAYOUT/.background/background.png" >/dev/null

RW_DMG="$STAGING_DIR/temp.dmg"
hdiutil create -volname "$DMG_VOLNAME" -srcfolder "$DMG_LAYOUT" \
  -fs HFS+ -format UDRW -ov "$RW_DMG" >/dev/null

MOUNT="$(hdiutil attach -nobrowse -noverify -noautoopen "$RW_DMG" | awk -F '\t' 'END {print $NF}')"
osascript <<APPLESCRIPT >/dev/null || true
tell application "Finder"
    tell disk "$DMG_VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 100, 740, 480}
        set view_options to the icon view options of container window
        set arrangement of view_options to not arranged
        set icon size of view_options to 128
        set background picture of view_options to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {140, 200}
        set position of item "Applications" of container window to {400, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
sync
hdiutil detach "$MOUNT" -quiet
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG" >/dev/null

# 6. Notarize + staple
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  cat >&2 <<EOF
✗ Notary profile "$NOTARY_PROFILE" not found.
  Create it once (interactive):
    xcrun notarytool store-credentials "$NOTARY_PROFILE" \\
      --apple-id "vincent@lauriat.fr" --team-id "KFLACS69T9"
  The DMG was built and signed at: $DMG (NOT yet notarized).
EOF
  exit 1
fi
echo "▶︎ notarize (this takes a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
echo "▶︎ staple"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

SIZE="$(du -h "$DMG" | cut -f1 | tr -d ' ')"
echo
echo "✅ Built, signed, notarized & stapled: $(basename "$DMG") ($SIZE)"
echo
echo "Publish on GitHub:"
echo "  gh release create v$VERSION \"$DMG\" --title \"v$VERSION\" --generate-notes"
