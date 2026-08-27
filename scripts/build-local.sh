#!/usr/bin/env bash
#
# Build the macOS release bundle exactly as CI does, without publishing.
#
# The release workflow does three things beyond `flutter build`: it installs
# the pinned kwaainet + p2pd into Contents/Resources, re-signs the bundle,
# and packages it with ditto. A plain `flutter build macos` produces none of
# that, which is how v0.3.0 shipped a bundle that fork-bombed on open.
#
# Usage:
#   scripts/build-local.sh           # build + bundle the daemon + sign
#   scripts/build-local.sh --run     # ...then launch it with a bomb watchdog
#   scripts/build-local.sh --zip     # ...also produce kwaainet-gui-macos.zip
set -euo pipefail
cd "$(dirname "$0")/.."

RUN=0; ZIP=0
for a in "$@"; do case "$a" in
  --run) RUN=1 ;; --zip) ZIP=1 ;;
  *) echo "Unknown argument: $a" >&2; exit 2 ;;
esac; done

APP="build/macos/Build/Products/Release/KwaaiNet.app"
VER="$(tr -d '[:space:]' < .kwaainet-version)"
ASSET="kwaainet-aarch64-apple-darwin.tar.xz"
CACHE="${TMPDIR:-/tmp}/kwaainet-daemon-$VER"

echo "==> flutter build macos --release"
flutter build macos --release

# Cache the daemon per pinned version — it's ~75 MB and rarely changes.
if [ ! -x "$CACHE/kwaainet" ]; then
  echo "==> fetching kwaainet $VER"
  rm -rf "$CACHE"; mkdir -p "$CACHE"
  gh release download "$VER" --repo Kwaai-AI-Lab/KwaaiNet \
    --pattern "$ASSET" --pattern "$ASSET.sha256" --dir "$CACHE" --clobber
  ( cd "$CACHE" && shasum -a 256 -c "$ASSET.sha256" && tar -xf "$ASSET" \
      && mv "${ASSET%.tar.xz}"/* . )
else
  echo "==> using cached kwaainet $VER"
fi

echo "==> bundling daemon into Contents/Resources"
install -m 0755 "$CACHE/kwaainet" "$APP/Contents/Resources/kwaainet"
install -m 0755 "$CACHE/p2pd"     "$APP/Contents/Resources/p2pd"
codesign --force --deep --sign - "$APP"

# The v0.3.0 regression: on case-insensitive APFS a daemon named `kwaainet`
# beside an executable named `KwaaiNet` IS that executable, so the GUI
# launched itself as its own node. Fail the build rather than ship it.
exe="$(plutil -extract CFBundleExecutable raw "$APP/Contents/Info.plist")"
if [ -e "$APP/Contents/MacOS/kwaainet" ]; then
  echo "FAIL: Contents/MacOS/kwaainet resolves (exe is '$exe') — launch-bomb shape." >&2
  exit 1
fi
echo "==> ok: exe='$exe', no MacOS/kwaainet collision"

if [ "$ZIP" = 1 ]; then
  ditto -c -k --keepParent "$APP" kwaainet-gui-macos.zip
  echo "==> wrote kwaainet-gui-macos.zip"
fi

[ "$RUN" = 1 ] || exit 0

echo "==> launching with a fork-bomb watchdog (25s)"
# Run the executable directly rather than `open -n`: LaunchServices discards
# stderr, and the daemon-controller log there is the whole diagnostic.
LOG="${TMPDIR:-/tmp}/kwaainet-gui-local.log"
# pgrep exits 1 with no match; swallow it or `set -e` kills the loop.
count() { pgrep -f "$1" 2>/dev/null | wc -l | tr -d ' ' || true; }
"$APP/Contents/MacOS/$exe" >"$LOG" 2>&1 &
peak_g=0; peak_d=0
for _ in $(seq 1 25); do
  g=$(count "KwaaiNet.app/Contents/MacOS/$exe"); d=$(count 'Contents/Resources/kwaainet')
  if [ "$g" -gt "$peak_g" ]; then peak_g=$g; fi
  if [ "$d" -gt "$peak_d" ]; then peak_d=$d; fi
  if [ "$g" -gt 2 ] || [ "$d" -gt 4 ]; then
    echo "FAIL: launch bomb — gui=$g daemon=$d"; pkill -f "$APP" || true; exit 1
  fi
  sleep 1
done
echo "==> ok: peak gui=$peak_g daemon=$peak_d (a bomb shows gui>2 or daemon>4)"
echo "--- daemon resolution (full log: $LOG) ---"
grep -E 'daemon-controller|not found|No such|Exception' "$LOG" | head -8 || \
  echo "(no daemon-controller lines — did the node already run?)"
osascript -e 'quit app "KwaaiNet"' 2>/dev/null || true
sleep 3; pkill -f "$APP" 2>/dev/null || true; pkill -f "Resources/p2pd" 2>/dev/null || true
