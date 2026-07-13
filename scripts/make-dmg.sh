#!/bin/bash
# Bouwt een gestileerde installer-DMG: app links, Programma's-snelkoppeling rechts,
# met achtergrond-instructie ("sleep naar Programma's"). Gebruikt Finder-AppleScript
# voor de layout — dat kan éénmalig een "wil Finder besturen"-prompt geven.
#
# Gebruik: make-dmg.sh <app-pad> <output.dmg> <volnaam> <achtergrond.png>
set -euo pipefail
APP="$1"; OUTDMG="$2"; VOLNAME="${3:-Fluister}"; BG="$4"

STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
mkdir "$STAGING/.background"
cp "$BG" "$STAGING/.background/bg.png"
ln -s /Applications "$STAGING/Applications"

RW="$(mktemp -u).dmg"
hdiutil create -srcfolder "$STAGING" -volname "$VOLNAME" -fs HFS+ \
  -format UDRW -ov "$RW" >/dev/null

MOUNT="/Volumes/$VOLNAME"
hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
DEV="$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | egrep '^/dev/' | head -1 | awk '{print $1}')"

# 1) wachten tot de mount er is op filesystem-niveau
for _ in $(seq 1 20); do [ -d "$MOUNT" ] && break; sleep 0.5; done
# 2) wachten tot Finder de disk daadwerkelijk kent (voorkomt de -1728 race)
for _ in $(seq 1 20); do
  if osascript -e "tell application \"Finder\" to exists disk \"$VOLNAME\"" 2>/dev/null | grep -q true; then break; fi
  sleep 0.5
done

# Layout via Finder, met retries. Niet-fataal: lukt het na 3 pogingen niet
# (bv. automation-prompt geweigerd), dan krijg je een werkende maar ongestileerde
# DMG i.p.v. een afgebroken build.
styled=0
for attempt in 1 2 3; do
  if osascript <<EOF 2>/dev/null
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 520}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 100
    set text size of opts to 12
    set background picture of opts to file ".background:bg.png"
    set position of item "Fluister.app" of container window to {165, 205}
    set position of item "Applications" of container window to {475, 205}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
  then styled=1; break; else sleep 1.5; fi
done
[ "$styled" = 1 ] || echo "⚠︎ Finder-styling faalde na 3 pogingen — DMG werkt, maar zonder achtergrond."

sync
chmod -Rf go-w "$MOUNT" >/dev/null 2>&1 || true
hdiutil detach "$DEV" >/dev/null 2>&1 || hdiutil detach "$DEV" -force >/dev/null 2>&1 || true

rm -f "$OUTDMG"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUTDMG" >/dev/null
rm -f "$RW"; rm -rf "$STAGING"
echo "✓ Gestileerde DMG: $OUTDMG"
