#!/bin/bash
# Builds and installs the "Mongolian (Latin → Cyrillic)" input method.
# Requires Xcode Command Line Tools:  xcode-select --install
set -e
cd "$(dirname "$0")"

NAME="MongolianLatin"
BUNDLE_ID="com.example.inputmethod.MongolianLatin"
MODE_ID="$BUNDLE_ID.Mongolian"
APP="$NAME.app"
DEST="$HOME/Library/Input Methods"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/en.lproj"

echo "Compiling..."
swiftc -O main.swift -o "$APP/Contents/MacOS/$NAME" -framework Cocoa -framework InputMethodKit

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>Mongolian Latin to Cyrillic</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>InputMethodConnectionName</key><string>${NAME}_Connection</string>
  <key>InputMethodServerControllerClass</key><string>MongolianController</string>
  <key>tsInputMethodIconFileKey</key><string></string>
  <key>ComponentInputModeDict</key>
  <dict>
    <key>tsInputModeListKey</key>
    <dict>
      <key>$MODE_ID</key>
      <dict>
        <key>TISIntendedLanguage</key><string>mn</string>
        <key>tsInputModeScriptKey</key><string>smCyrillic</string>
        <key>tsInputModeIsVisibleKey</key><true/>
        <key>tsInputModeDefaultStateKey</key><true/>
        <key>tsInputModePrimaryInModeKey</key><true/>
      </dict>
    </dict>
    <key>tsVisibleInputModeOrderedArrayKey</key>
    <array><string>$MODE_ID</string></array>
  </dict>
</dict>
</plist>
EOF

cat > "$APP/Contents/Resources/en.lproj/InfoPlist.strings" <<EOF
"CFBundleName" = "Mongolian Latin to Cyrillic";
"$MODE_ID" = "Mongolian (Latin → Cyrillic)";
EOF

codesign --force --deep --sign - "$APP" 2>/dev/null || true

mkdir -p "$DEST"
pkill -x "$NAME" 2>/dev/null || true
rm -rf "$DEST/$APP"
cp -R "$APP" "$DEST/"

echo ""
echo "Installed to: $DEST/$APP"
echo ""
echo "Next steps:"
echo "  1. Log out and log back in (macOS only discovers new input methods then)."
echo "  2. System Settings > Keyboard > Text Input > Input Sources > Edit… > '+'"
echo "     Find 'Mongolian (Latin → Cyrillic)' (search 'Mongolian') and add it."
echo "  3. Switch to it from the menu bar or with Ctrl+Space / Globe key, then just type."
