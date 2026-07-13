#!/bin/bash
# Bouwt een Release-build van Fluister, signt met Developer ID + hardened runtime,
# notariseert app én DMG bij Apple en stapelt beide tickets. Resultaat: een DMG
# die op een schone Mac zónder Gatekeeper-waarschuwing opent (ook offline).
#
# EENMALIGE SETUP (zie README/CONTRIBUTING):
#   1. Een "Developer ID Application"-certificaat in de login-keychain
#      (developer.apple.com → Certificates → +).
#   2. Een notarytool keychain-profiel (default "fluister-notary"):
#        xcrun notarytool store-credentials fluister-notary \
#          --apple-id "<jouw-apple-id>" --team-id "<TEAM_ID>" \
#          --password "<app-specifiek-wachtwoord>"
#      (Het app-specifieke wachtwoord maak je op appleid.apple.com. Het belandt in
#       de Keychain, NOOIT in deze repo.)
#
# Gebruik:  ./scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."   # repo-root (dit script staat in scripts/)

NOTARY_PROFILE="${FLUISTER_NOTARY_PROFILE:-fluister-notary}"
DD="${FLUISTER_DD:-$HOME/Library/Developer/Xcode/DerivedData/Fluister-release}"
ENTITLEMENTS="Fluister/Fluister.entitlements"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Fluister/Info.plist)"
DIST="dist"
DMG="$DIST/Fluister-$VERSION.dmg"

# --- 0. Signing-identiteit auto-detecteren -----------------------------------
IDENTITY="$(security find-identity -v -p codesigning \
  | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(.*)"/\1/')"
if [ -z "$IDENTITY" ]; then
  echo "✗ Geen 'Developer ID Application'-certificaat gevonden in de keychain." >&2
  echo "  Maak er een aan op developer.apple.com → Certificates en installeer 'm." >&2
  exit 1
fi
echo "▶ Signing-identiteit: $IDENTITY"

# --- 1. Schone Release-build -------------------------------------------------
echo "▶ Project genereren + Release bouwen…"
xcodegen generate >/dev/null
xcodebuild -project Fluister.xcodeproj -scheme Fluister -configuration Release \
  -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=NO build >/dev/null
APP="$DD/Build/Products/Release/Fluister.app"

# --- 2. Signen met Developer ID + hardened runtime ---------------------------
echo "▶ Signen (Developer ID + hardened runtime)…"
codesign --deep --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -rf "$DIST"; mkdir -p "$DIST"

# --- 3. App notariseren + stapelen (offline-proof eerste start) --------------
echo "▶ App notariseren (kan enkele minuten duren)…"
APPZIP="$DIST/Fluister-app.zip"
ditto -c -k --keepParent "$APP" "$APPZIP"
xcrun notarytool submit "$APPZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
rm -f "$APPZIP"

# --- 4. Gestileerde installer-DMG uit de gestaplede app ----------------------
# App links, Programma's-snelkoppeling rechts, achtergrond met sleep-instructie.
echo "▶ DMG bouwen (gestileerd, drag-to-Applications)…"
BG="$(mktemp -u).png"
swift "$(dirname "$0")/make-dmg-bg.swift" "$BG" >/dev/null
"$(dirname "$0")/make-dmg.sh" "$APP" "$DMG" "Fluister" "$BG"
rm -f "$BG"
codesign --force --sign "$IDENTITY" --timestamp "$DMG"

# --- 5. DMG notariseren + stapelen -------------------------------------------
echo "▶ DMG notariseren…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# --- 6. Checksum -------------------------------------------------------------
shasum -a 256 "$DMG" | tee "$DMG.sha256"

echo "✓ Klaar: $DMG"
echo "  Controleer op een schone Mac dat de DMG en app zonder waarschuwing openen."
