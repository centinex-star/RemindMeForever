#!/usr/bin/env bash
# Build a distributable zip of the addon.
#
# The zip contains a top-level RemindMeForever/ folder, which is the shape WoW
# addon managers and manual installs both expect.
set -euo pipefail

cd "$(dirname "$0")"

VERSION=$(grep -m1 '^## Version:' RemindMeForever.toc | sed 's/^## Version:[[:space:]]*//')
INTERFACE=$(grep -m1 '^## Interface:' RemindMeForever.toc | sed 's/^## Interface:[[:space:]]*//')
OUT="dist/RemindMeForever-${VERSION}.zip"

echo "Building RemindMeForever v${VERSION} (interface ${INTERFACE})"

# Fail the build rather than ship something broken.
if ! command -v lua5.1 >/dev/null 2>&1; then
  echo "error: lua5.1 not found; install it to run the test suite" >&2
  exit 1
fi

lua5.1 tests/run.lua
lua5.1 tests/ui_smoke.lua

for f in *.lua; do
  luac5.1 -p "$f" || { echo "error: $f does not compile" >&2; exit 1; }
done

rm -rf dist/RemindMeForever
mkdir -p dist/RemindMeForever

cp ./*.lua ./*.toc README.md LICENSE dist/RemindMeForever/

rm -f "$OUT"
if command -v zip >/dev/null 2>&1; then
  ( cd dist && zip -qr "$(basename "$OUT")" RemindMeForever )
else
  # Portable fallback; produces an identical layout.
  python3 - "$OUT" <<'PY'
import os, sys, zipfile
out = sys.argv[1]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk("dist/RemindMeForever"):
        for name in sorted(files):
            full = os.path.join(root, name)
            z.write(full, os.path.relpath(full, "dist"))
PY
fi

echo "Wrote ${OUT}"
unzip -l "$OUT" | tail -n 3
