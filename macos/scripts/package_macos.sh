#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MACOS_DIR/.." && pwd)"

# Determine version from argument or TeamsQuickChat.csproj
if [[ $# -ge 1 && -n "${1:-}" ]]; then
    VERSION="$1"
else
    VERSION="$(sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' "$REPO_ROOT/TeamsQuickChat.csproj" | head -n 1 | tr -d '[:space:]')"
fi

if [[ -z "$VERSION" ]]; then
    echo "Error: Could not determine app version." >&2
    exit 1
fi

# Auto-detect developer directory if xcode-select is not configured
if ! xcode-select -p >/dev/null 2>&1; then
    if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    elif [[ -d "/Library/Developer/CommandLineTools" ]]; then
        export DEVELOPER_DIR="/Library/Developer/CommandLineTools"
    fi
fi

if [[ -n "${DEVELOPER_DIR:-}" && -x "$DEVELOPER_DIR/usr/bin/swift" ]]; then
    SWIFT_BIN="$DEVELOPER_DIR/usr/bin/swift"
else
    SWIFT_BIN="swift"
fi

APP_NAME="Teams Quick Chat"
EXECUTABLE_NAME="TeamsQuickChat"
BUNDLE_ID="com.prathiraj.teamsquickchat"
DIST_DIR="$MACOS_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/TeamsQuickChat-$VERSION-macos.zip"
DMG_PATH="$DIST_DIR/TeamsQuickChat-$VERSION-macos.dmg"

echo "==> Building $APP_NAME v$VERSION (universal arm64 + x86_64) ..."
cd "$MACOS_DIR"

"$SWIFT_BIN" build -c release --arch arm64 --arch x86_64
BIN_DIR="$("$SWIFT_BIN" build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BUILT_BINARY="$BIN_DIR/$EXECUTABLE_NAME"

if [[ ! -f "$BUILT_BINARY" ]]; then
    # Fallback search inside .build for universal or release binary
    BUILT_BINARY="$(find "$MACOS_DIR/.build" -type f -path "*/Release/$EXECUTABLE_NAME" -o -type f -path "*/release/$EXECUTABLE_NAME" | head -n 1)"
fi

if [[ -z "$BUILT_BINARY" || ! -f "$BUILT_BINARY" ]]; then
    echo "Error: Compiled binary not found." >&2
    exit 1
fi

echo "==> Assembling $APP_NAME.app bundle ..."
rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BUILT_BINARY" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
chmod 755 "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

echo "==> Generating Retina AppIcon.icns ..."
"$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" --generate-app-icon "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.social-networking</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © prathiraj. MIT License.</string>
</dict>
</plist>
EOF

printf "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "==> Signing $APP_NAME.app (ad-hoc) ..."
/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> Creating $ZIP_PATH ..."
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "==> Creating $DMG_PATH ..."
DMG_STAGE="$(mktemp -d)"
trap 'rm -rf "$DMG_STAGE"' EXIT
cp -R "$APP_BUNDLE" "$DMG_STAGE/$APP_NAME.app"
ln -s /Applications "$DMG_STAGE/Applications"

for attempt in 1 2 3; do
    if /usr/bin/hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$DMG_STAGE" \
        -fs HFS+ \
        -ov \
        -format UDZO \
        "$DMG_PATH" >/dev/null; then
        break
    fi
    if [[ "$attempt" -eq 3 ]]; then
        echo "Error: Failed to create DMG after 3 attempts." >&2
        exit 1
    fi
    sleep 2
done

echo "==> Packaged successfully:"
ls -lh "$ZIP_PATH" "$DMG_PATH"
