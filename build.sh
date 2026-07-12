#!/bin/bash
# Bouwt Fluister, signt met het stabiele "Fluister Dev"-certificaat (zodat de
# TCC/toegankelijkheid-toekenning over rebuilds heen blijft), installeert naar
# /Applications en start de app.
#
# Vereist: het "Fluister Dev" code-signing certificaat in de login-keychain.
set -e
cd "$(dirname "$0")"

IDENTITY="Fluister Dev"
DD="${FLUISTER_DD:-$HOME/Library/Developer/Xcode/DerivedData/Fluister-cli}"
ENTITLEMENTS="Fluister/Fluister.entitlements"

echo "▶ Project genereren…"
xcodegen generate >/dev/null

echo "▶ Bouwen (ongesigneerd, zonder aparte debug-dylib)…"
xcodebuild -project Fluister.xcodeproj -scheme Fluister -configuration Debug \
  -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=NO build >/dev/null

APP="$DD/Build/Products/Debug/Fluister.app"

echo "▶ Signen met '$IDENTITY'…"
codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"

echo "▶ Installeren naar /Applications…"
pkill -f "Fluister.app/Contents/MacOS/Fluister" 2>/dev/null || true
sleep 1
rm -rf /Applications/Fluister.app
cp -R "$APP" /Applications/
codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" /Applications/Fluister.app

echo "▶ Starten…"
open /Applications/Fluister.app
echo "✓ Klaar. Handtekening:"
codesign -dvvv /Applications/Fluister.app 2>&1 | grep -E "Authority|Identifier" | head -2
