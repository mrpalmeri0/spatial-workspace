#!/bin/bash
# ============================================================================
# Catena di rilascio per l'app Mac: archivio firmato Developer ID,
# notarizzazione Apple, stapling e pacchetto .dmg pronto da distribuire.
#
# Prerequisiti (una tantum):
#   1) Certificato "Developer ID Application" creato e installato in portachiavi.
#      Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application
#      Poi incolla la riga esatta in Config/release.env -> DEVELOPER_ID_APPLICATION
#   2) Profilo notarytool salvato in portachiavi:
#      xcrun notarytool store-credentials "arworkspace-notary" \
#          --apple-id TUA_APPLE_ID --team-id LE75672ZR7 --password PASSWORD_APP_SPECIFICA
#      (la password specifica per app si genera su appleid.apple.com)
#
# Uso:
#   bash scripts/release-mac.sh
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

# --- Carica la configurazione centralizzata --------------------------------
if [[ ! -f Config/release.env ]]; then
    echo "ERRORE: manca Config/release.env" >&2; exit 1
fi
# shellcheck disable=SC1091
source Config/release.env

: "${DISPLAY_NAME_MAC:?manca DISPLAY_NAME_MAC in release.env}"
: "${MARKETING_VERSION:?manca MARKETING_VERSION in release.env}"

if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    cat >&2 <<'MSG'
ERRORE: DEVELOPER_ID_APPLICATION non impostato in Config/release.env.
Serve il certificato "Developer ID Application" (non "Apple Development").
  1. Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application
  2. security find-identity -v -p codesigning   # copia la riga tra virgolette
  3. incollala in Config/release.env -> DEVELOPER_ID_APPLICATION
MSG
    exit 1
fi

# Verifica che il certificato sia davvero presente nel portachiavi.
if ! security find-identity -v -p codesigning | grep -Fq "$DEVELOPER_ID_APPLICATION"; then
    echo "ERRORE: certificato non trovato in portachiavi: $DEVELOPER_ID_APPLICATION" >&2
    echo "Certificati disponibili:" >&2
    security find-identity -v -p codesigning >&2
    exit 1
fi

OUT="build/release"
ARCHIVE="$OUT/RayNeoWorkspace.xcarchive"
EXPORT="$OUT/export"
STAGE="$OUT/dmg-stage"
DMG="$OUT/${DISPLAY_NAME_MAC// /-}-${MARKETING_VERSION}.dmg"
rm -rf "$OUT"
mkdir -p "$OUT"

echo "==> 1/6 Rigenero il progetto Xcode dalla configurazione"
python3 scripts/generate-xcode-project.py >/dev/null

echo "==> 2/6 Archivio (Release, Developer ID, Hardened Runtime)"
xcodebuild -project RayNeoWorkspace.xcodeproj -scheme RayNeoWorkspace \
    -configuration Release -destination 'platform=macOS,arch=arm64' \
    -archivePath "$ARCHIVE" archive

echo "==> 3/6 Esporto l'app firmata Developer ID"
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>teamID</key><string>${TEAM_ID}</string>
<key>signingStyle</key><string>manual</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT" -exportOptionsPlist "$OUT/ExportOptions.plist"

APP="$(find "$EXPORT" -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$APP" ]]; then echo "ERRORE: app esportata non trovata in $EXPORT" >&2; exit 1; fi
echo "    App: $APP"

echo "==> 4/6 Notarizzazione Apple (attendo l'esito)"
NOTARY_ZIP="$OUT/notarize.zip"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "${NOTARY_PROFILE:-arworkspace-notary}" --wait

echo "==> 5/6 Staple del ticket di notarizzazione"
xcrun stapler staple "$APP"

echo "==> 6/6 Creo il .dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$DISPLAY_NAME_MAC" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG"

echo
echo "==> Verifiche finali"
spctl --assess --type execute --verbose=4 "$APP" || true
xcrun stapler validate "$APP" || true
echo
echo "FATTO. Pacchetto pronto: $DMG"
echo "Distribuiscilo via download diretto. Apertura su altri Mac senza allarmi Gatekeeper."
