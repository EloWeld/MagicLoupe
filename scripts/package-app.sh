#!/bin/bash
# Assemble MagicLoupe.app from the SwiftPM binary and codesign it.
# Does not compile — run `swift build` first (see Makefile / scripts/release.sh).
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFOPLIST="$ROOT/Resources/Info.plist"
ENTITLEMENTS="$ROOT/Resources/MagicLoupe.entitlements"
IDENTIFIER="com.mtglitch.MagicLoupe"

SWIFT_ARGS=(-c "$CONFIG" --product MagicLoupe)
if [[ -n "${SWIFT_ARCHES:-}" ]]; then
  # shellcheck disable=SC2086
  for arch in ${SWIFT_ARCHES}; do
    SWIFT_ARGS+=(--arch "$arch")
  done
fi

BIN_DIR="$(swift build "${SWIFT_ARGS[@]}" --show-bin-path)"
BINARY="$BIN_DIR/MagicLoupe"
if [[ ! -x "$BINARY" ]]; then
  echo "error: missing binary at $BINARY — build first" >&2
  exit 1
fi

APP="${PACKAGE_APP_DEST:-$ROOT/.build/App/MagicLoupe.app}"
INSTALL_LOCAL="${PACKAGE_INSTALL_LOCAL:-1}"
STABLE="$HOME/Applications/MagicLoupe.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/MagicLoupe"
cp "$INFOPLIST" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
if [[ -d "$ROOT/Resources/Fonts" ]]; then
  cp "$ROOT/Resources/Fonts/"*.ttf "$APP/Contents/Resources/" 2>/dev/null || true
  cp "$ROOT/Resources/Fonts/"OFL*.txt "$APP/Contents/Resources/" 2>/dev/null || true
fi

resolve_identity() {
  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$CODESIGN_IDENTITY"
    return
  fi
  if [[ "$CONFIG" == "release" ]]; then
    local ids
    ids="$(security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' \
      | uniq)"
    local n
    n="$(printf '%s\n' "$ids" | grep -c . || true)"
    if [[ "$n" -eq 1 ]]; then
      printf '%s\n' "$ids"
      return
    fi
  fi
  printf '%s\n' "-"
}

IDENTITY="$(resolve_identity)"
if [[ "$IDENTITY" == "-" ]]; then
  echo "signing ad-hoc (set CODESIGN_IDENTITY for a real certificate)" >&2
fi

sign() {
  local target="$1"
  if [[ "$IDENTITY" == "-" ]]; then
    codesign --force --sign - \
      --identifier "$IDENTIFIER" \
      --entitlements "$ENTITLEMENTS" \
      "$target"
    return
  fi
  local extra=()
  if [[ "$CONFIG" == "release" ]]; then
    extra+=(--timestamp --options runtime)
  else
    extra+=(--timestamp=none)
  fi
  codesign --force --sign "$IDENTITY" \
    --identifier "$IDENTIFIER" \
    --entitlements "$ENTITLEMENTS" \
    "${extra[@]}" \
    "$target"
}

sign "$APP/Contents/MacOS/MagicLoupe"
sign "$APP"

if [[ "$INSTALL_LOCAL" == "1" ]]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$STABLE"
  ditto "$APP" "$STABLE"
  sign "$STABLE/Contents/MacOS/MagicLoupe"
  sign "$STABLE"
  xattr -cr "$STABLE" || true
  echo "Installed $STABLE"
fi

xattr -cr "$APP" || true
echo "Built $APP"
echo "Signed with: $IDENTITY"
