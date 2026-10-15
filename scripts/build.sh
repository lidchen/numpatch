#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
swift build --disable-sandbox -c release
APP="$PWD/dist/NumPatch.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/NumPatch "$APP/Contents/MacOS/NumPatch"
# SwiftPM resources must sit beside the executable for Bundle.module lookup.
resource_bundle="$PWD/.build/release/NumPatch_NumPatch.bundle"
if [[ ! -d "$resource_bundle" ]]; then
    print -u2 "Missing localization resources: $resource_bundle"
    exit 1
fi
rm -rf "$APP/Contents/Resources/NumPatch_NumPatch.bundle"
cp -R "$resource_bundle" "$APP/Contents/Resources/"
cp THIRD_PARTY_LICENSES.txt "$APP/Contents/Resources/ThirdPartyLicenses.txt"
swift scripts/make-icon.swift "$PWD/.build/AppIcon.iconset"
iconutil -c icns "$PWD/.build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NumPatch</string>
<key>CFBundleIdentifier</key><string>local.touchpad-keyboard.monitor</string>
<key>CFBundleName</key><string>NumPatch</string>
<key>CFBundleDisplayName</key><string>NumPatch</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.0</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Use a stable development identity so rebuilding does not change the TCC
# designated requirement to a new cdhash on every build. Do not create keys.
signing_identity="${NUMPATCH_SIGN_IDENTITY:-${TOUCHPAD_SIGN_IDENTITY:-}}"
if [[ -z "$signing_identity" ]]; then
    signing_identity=$(/usr/bin/security find-identity -v -p codesigning | /usr/bin/awk '/"Apple Development:/ { print $2; exit }')
fi
if [[ -z "$signing_identity" ]]; then
    print -u2 'No Apple Development identity found. Set NUMPATCH_SIGN_IDENTITY to a stable signing identity.'
    exit 1
fi
codesign --force --sign "$signing_identity" --timestamp=none "$APP"
codesign --verify --strict "$APP"
printf 'Built: %s\n' "$APP"
