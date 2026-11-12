#!/data/data/com.termux/files/usr/bin/bash
# Patch the installed Termux:X11 so it opens in a larger panel on Meta Quest.
#
# Horizon OS opens 2D apps at 1024x640dp unless the manifest has a <layout>
# element. This adds one to MainActivity and MainActivity$MainActivityTagged,
# rebuilds and re-signs the APK with a local key, and copies it to Downloads.
#
#   patch-termux-x11.sh [WIDTHdp HEIGHTdp]    (default 1440 1000)
#
# Run it again after every Termux:X11 update. Start X with termux-x11-patched,
# because the stock termux-x11 command rejects the re-signed app.
#
# Needs: apktool, zipalign, apksigner, keytool, aapt, python3
#   (pkg install apktool aapt apksigner openjdk-21 python)
# The first install of a patched build needs the official app uninstalled first
# (different signature). Later patched builds made with the same key install over it.
set -euo pipefail

W=${1:-1440}
H=${2:-1000}
KEY=${PATCH_KEYSTORE:-$HOME/.android-patch-key.jks}
if [ -z "${PATCH_OUT:-}" ]; then
  # Downloads if Termux has storage access (termux-setup-storage), else home.
  if [ -w /sdcard/Download ]; then PATCH_OUT=/sdcard/Download/termux-x11-quest-maxsize.apk
  else PATCH_OUT=$HOME/termux-x11-quest-maxsize.apk; fi
fi
OUT=$PATCH_OUT

APK=${PATCH_IN:-$(pm path com.termux.x11 | sed -n 's/^package://p' | head -1)}
[ -n "$APK" ] || { echo "Termux:X11 (com.termux.x11) is not installed." >&2; exit 1; }

WORK=$(mktemp -d "${TMPDIR:-/data/data/com.termux/files/usr/tmp}/x11patch.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
cp "$APK" "$WORK/orig.apk"

echo "Decoding $(aapt dump badging "$WORK/orig.apk" 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")..."
apktool d -f -s "$WORK/orig.apk" -o "$WORK/dec" >/dev/null

python3 -I - "$WORK/dec/AndroidManifest.xml" "$W" "$H" <<'EOF'
import re, sys
path, w, h = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()
# Undo an earlier patch so re-patching a patched install works.
s = re.sub(r'\s*<layout\b[^>]*/>', '', s)
s = re.sub(r'(<activity [^>]*[^/])>\s*</activity>', r'\1/>', s)
tag = f'<layout android:defaultWidth="{w}dp" android:defaultHeight="{h}dp"/>'
s, n1 = re.subn(r'(<activity [^>]*android:name="com\.termux\.x11\.MainActivity"[^>]*[^/]>)',
                r'\1\n            ' + tag, s, count=1)
s, n2 = re.subn(r'(<activity [^>]*MainActivity\$MainActivityTagged"[^>]*)/>',
                r'\1>\n            ' + tag + r'\n        </activity>', s, count=1)
if not (n1 and n2):
    sys.exit(f"Manifest layout changed upstream (main={n1}, tagged={n2}); patch needs updating.")
open(path, 'w').write(s)
EOF

echo "Rebuilding with ${W}x${H}dp default panel..."
apktool b "$WORK/dec" -o "$WORK/unsigned.apk" >/dev/null
zipalign -f -p 4 "$WORK/unsigned.apk" "$WORK/aligned.apk"

if [ ! -f "$KEY" ]; then
  echo "Creating signing key $KEY"
  keytool -genkeypair -keystore "$KEY" -alias patch -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass android -keypass android -dname "CN=Local Patch" >/dev/null 2>&1
fi
apksigner sign --ks "$KEY" --ks-pass pass:android --ks-key-alias patch --out "$WORK/signed.apk" "$WORK/aligned.apk"
apksigner verify "$WORK/signed.apk"
MANIFEST=$(aapt dump xmltree "$WORK/signed.apk" AndroidManifest.xml 2>/dev/null)
[ "$(grep -c 'E: layout' <<<"$MANIFEST")" = 2 ] \
  || { echo "Patched manifest has no <layout>; aborting." >&2; exit 1; }

cp "$WORK/signed.apk" "$OUT"
echo "Done: $OUT"
echo "Install it with: termux-open \"$OUT\""
echo "(Uninstall the official Termux:X11 first if it's still installed.)"
