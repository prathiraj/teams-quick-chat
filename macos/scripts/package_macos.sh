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

run_xcrun_tool() {
    local tool="$1"
    shift
    if [[ -n "${DEVELOPER_DIR:-}" && -x "$DEVELOPER_DIR/usr/bin/$tool" ]]; then
        "$DEVELOPER_DIR/usr/bin/$tool" "$@"
    else
        /usr/bin/xcrun "$tool" "$@"
    fi
}

APP_NAME="Teams Quick Chat"
EXECUTABLE_NAME="TeamsQuickChat"
BUNDLE_ID="com.prathiraj.teamsquickchat"
DIST_DIR="$MACOS_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/TeamsQuickChat-$VERSION-macos.zip"
DMG_PATH="$DIST_DIR/TeamsQuickChat-$VERSION-macos.dmg"

# Resolve code-signing identity:
# - Set CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" explicitly, OR
# - Set CODESIGN_IDENTITY="auto" to pick the first Developer ID Application identity in Keychain, OR
# - Leave unset for ad-hoc signing ("-")
SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ "$SIGN_IDENTITY" == "auto" ]]; then
    SIGN_IDENTITY="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
        | head -n 1 || true)"
fi

USE_DEVELOPER_ID=0
if [[ -n "$SIGN_IDENTITY" && "$SIGN_IDENTITY" != "-" ]]; then
    USE_DEVELOPER_ID=1
else
    SIGN_IDENTITY="-"
fi

# Resolve optional Apple notarization credentials:
# Mode 1: NOTARYTOOL_PROFILE (saved keychain profile from `xcrun notarytool store-credentials`)
# Mode 2: APPLE_API_KEY_ID + APPLE_API_ISSUER_ID + (APPLE_API_KEY_PATH or APPLE_API_KEY_P8_BASE64)
# Mode 3: APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID
NOTARY_ARGS=()
USE_NOTARIZATION=0
TEMP_API_KEY_FILE=""
cleanup_packaging() {
    if [[ -n "${DMG_STAGE:-}" && -d "${DMG_STAGE:-}" ]]; then
        rm -rf "$DMG_STAGE"
    fi
    if [[ -n "$TEMP_API_KEY_FILE" && -f "$TEMP_API_KEY_FILE" ]]; then
        rm -f "$TEMP_API_KEY_FILE"
    fi
}
trap cleanup_packaging EXIT

if [[ "$USE_DEVELOPER_ID" -eq 1 ]]; then
    if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
        NOTARY_ARGS=(--keychain-profile "$NOTARYTOOL_PROFILE")
        USE_NOTARIZATION=1
    elif [[ -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" ]]; then
        if [[ -n "${APPLE_API_KEY_PATH:-}" && -f "${APPLE_API_KEY_PATH:-}" ]]; then
            NOTARY_ARGS=(--key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID")
            USE_NOTARIZATION=1
        elif [[ -n "${APPLE_API_KEY_P8_BASE64:-}" ]]; then
            TEMP_API_KEY_FILE="$(mktemp)"
            chmod 600 "$TEMP_API_KEY_FILE"
            printf '%s' "$APPLE_API_KEY_P8_BASE64" | base64 --decode > "$TEMP_API_KEY_FILE"
            NOTARY_ARGS=(--key "$TEMP_API_KEY_FILE" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID")
            USE_NOTARIZATION=1
        fi
    elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
        NOTARY_ARGS=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
        USE_NOTARIZATION=1
    fi
fi

notarize_artifact() {
    local file_path="$1"
    local label="$2"
    echo "==> Submitting $label to Apple Notary Service ..."
    local output_json
    output_json="$(mktemp)"
    if ! run_xcrun_tool notarytool submit "$file_path" "${NOTARY_ARGS[@]}" --wait --output-format json > "$output_json"; then
        cat "$output_json" >&2 || true
        local sub_id
        sub_id="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("id",""))' "$output_json" 2>/dev/null || true)"
        if [[ -n "$sub_id" ]]; then
            echo "==> Fetching Apple notarization log ($sub_id) ..." >&2
            run_xcrun_tool notarytool log "$sub_id" "${NOTARY_ARGS[@]}" >&2 || true
        fi
        rm -f "$output_json"
        return 1
    fi

    local status sub_id
    status="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("status",""))' "$output_json" 2>/dev/null || true)"
    sub_id="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("id",""))' "$output_json" 2>/dev/null || true)"
    rm -f "$output_json"

    if [[ "$status" != "Accepted" ]]; then
        echo "Error: Notarization for $label finished with status '$status' (id: $sub_id)." >&2
        if [[ -n "$sub_id" ]]; then
            run_xcrun_tool notarytool log "$sub_id" "${NOTARY_ARGS[@]}" >&2 || true
        fi
        return 1
    fi
    echo "==> Notarization accepted for $label (id: $sub_id)."
}

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

if [[ "$USE_DEVELOPER_ID" -eq 1 ]]; then
    echo "==> Signing $APP_NAME.app with Developer ID ($SIGN_IDENTITY) + Hardened Runtime ..."
    /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
    /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
    echo "==> Signing $APP_NAME.app (ad-hoc) ..."
    /usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "==> Creating $ZIP_PATH ..."
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

if [[ "$USE_NOTARIZATION" -eq 1 ]]; then
    notarize_artifact "$ZIP_PATH" "$APP_NAME.app"
    echo "==> Stapling notarization ticket to $APP_NAME.app ..."
    run_xcrun_tool stapler staple "$APP_BUNDLE"
    run_xcrun_tool stapler validate "$APP_BUNDLE"
    # Rebuild ZIP so it contains the stapled .app bundle
    rm -f "$ZIP_PATH"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
fi

echo "==> Creating $DMG_PATH ..."
DMG_STAGE="$(mktemp -d)"
/usr/bin/ditto "$APP_BUNDLE" "$DMG_STAGE/$APP_NAME.app"
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

if [[ "$USE_DEVELOPER_ID" -eq 1 ]]; then
    echo "==> Signing $DMG_PATH with Developer ID ..."
    /usr/bin/codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
    /usr/bin/codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ "$USE_NOTARIZATION" -eq 1 ]]; then
    notarize_artifact "$DMG_PATH" "$(basename "$DMG_PATH")"
    echo "==> Stapling notarization ticket to $DMG_PATH ..."
    run_xcrun_tool stapler staple "$DMG_PATH"
    run_xcrun_tool stapler validate "$DMG_PATH"
fi

echo "==> Packaged successfully:"
ls -lh "$ZIP_PATH" "$DMG_PATH"
