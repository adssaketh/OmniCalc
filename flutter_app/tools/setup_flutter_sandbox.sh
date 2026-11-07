#!/usr/bin/env bash
# Installs the current stable Flutter SDK in a fresh chat sandbox so `flutter analyze` and `flutter test` can run
# before anything is pushed. Nothing is kept between chats, so run this once at the start of each phase:
#
#   bash flutter_app/tools/setup_flutter_sandbox.sh
#   export PATH=/opt/fl/flutter/bin:$PATH CI=true FLUTTER_SUPPRESS_ANALYTICS=true
#   cd flutter_app && flutter analyze --no-fatal-infos && flutter test
#
# Needs: outbound HTTPS to storage.googleapis.com and pub.dev (both were reachable in the chat sandbox), python3, tar, xz.
# Safe to run again: an SDK that is already unpacked is reused.
set -euo pipefail

DEST="${FLUTTER_DEST:-/opt/fl}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$(cd "$HERE/.." && pwd)"
BASE="https://storage.googleapis.com/flutter_infra_release/releases"

if [ ! -x "$DEST/flutter/bin/flutter" ]; then
  mkdir -p "$DEST"
  echo "==> finding the current stable release"
  curl -fsS -m 60 "$BASE/releases_linux.json" -o "$DEST/releases.json"
  ARCHIVE="$(python3 - "$DEST/releases.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
h = d["current_release"]["stable"]
print(next(r["archive"] for r in d["releases"] if r["hash"] == h))
PY
)"
  echo "==> downloading $ARCHIVE (about 1.5 GB)"
  curl -fS -m 900 -o "$DEST/flutter.tar.xz" "$BASE/$ARCHIVE"
  echo "==> unpacking"
  tar -xf "$DEST/flutter.tar.xz" -C "$DEST"
  rm -f "$DEST/flutter.tar.xz" "$DEST/releases.json"
fi

export PATH="$DEST/flutter/bin:$PATH" CI=true FLUTTER_SUPPRESS_ANALYTICS=true
# the SDK is a plain unpacked archive owned by another user as far as git is concerned
git config --global --add safe.directory '*' || true
flutter --version
(cd "$APP" && flutter pub get)
echo "==> ready. Add to PATH: export PATH=$DEST/flutter/bin:\$PATH CI=true"
