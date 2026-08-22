#!/bin/bash
# Cut a versioned zip (and optionally a GitHub Release).
#
#   ./scripts/release.sh                 # build dist/ from Info.plist version
#   ./scripts/release.sh 0.2.0           # bump marketing version, then build
#   ./scripts/release.sh 0.2.0 --github  # also commit, tag, push, gh release
#   ./scripts/release.sh --github        # publish the version already in the plist
#
# Env:
#   CODESIGN_IDENTITY   Developer ID Application: Name (TEAMID)
#   NOTARY_PROFILE      notarytool keychain profile (optional)
#   SWIFT_ARCHES        default: "arm64 x86_64" (universal). Set to "arm64" to skip Intel.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PLIST="$ROOT/Resources/Info.plist"
INFOLINK=(-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$PLIST")
PUBLISH=0
DRY=0
VERSION=""
NOTES_FILE=""

usage() {
  cat <<'EOF'
Cut a versioned zip, optionally publish a GitHub Release.

  ./scripts/release.sh                 build dist/ from Info.plist version
  ./scripts/release.sh 0.2.0           bump marketing version, then build
  ./scripts/release.sh 0.2.0 --github  commit, tag v0.2.0, push, gh release
  ./scripts/release.sh --github        publish the version already in the plist
  ./scripts/release.sh --dry-run

  --notes FILE         release notes (default: matching section in CHANGELOG.md)

  CODESIGN_IDENTITY    Developer ID Application: Name (TEAMID)
  NOTARY_PROFILE       notarytool keychain profile
  SWIFT_ARCHES         default: arm64 x86_64. Set arm64 to skip Intel.
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --github) PUBLISH=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --notes)
      NOTES_FILE="${2:?--notes needs a file}"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "unknown flag: $1" >&2
      usage 1
      ;;
    *)
      if [[ -n "$VERSION" ]]; then
        echo "unexpected argument: $1" >&2
        usage 1
      fi
      VERSION="$1"
      shift
      ;;
  esac
done

plist_get() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST"
}

plist_set() {
  /usr/libexec/PlistBuddy -c "Set :$1 $2" "$PLIST"
}

CURRENT="$(plist_get CFBundleShortVersionString)"
BUILD="$(plist_get CFBundleVersion)"

if [[ -n "$VERSION" ]]; then
  if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "error: version must look like 1.2.3 (got '$VERSION')" >&2
    exit 1
  fi
else
  VERSION="$CURRENT"
fi

if ! [[ "$BUILD" =~ ^[0-9]+$ ]]; then
  BUILD=0
fi
if [[ "$VERSION" != "$CURRENT" ]]; then
  BUILD=$((BUILD + 1))
elif [[ "$PUBLISH" -eq 1 ]]; then
  BUILD=$((BUILD + 1))
fi

extract_notes() {
  local file="$ROOT/CHANGELOG.md"
  if [[ -n "$NOTES_FILE" ]]; then
    cat "$NOTES_FILE"
    return
  fi
  if [[ ! -f "$file" ]]; then
    echo "Magic Loupe ${VERSION}"
    return
  fi
  python3 - "$file" "$VERSION" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
version = sys.argv[2]
needle = f"## {version}"
start = text.find(needle)
if start < 0:
    print(f"Magic Loupe {version}")
    raise SystemExit
start = text.find("\n", start)
if start < 0:
    print(f"Magic Loupe {version}")
    raise SystemExit
start += 1
end = text.find("\n## ", start)
body = text[start:end if end >= 0 else None].strip()
print(body or f"Magic Loupe {version}")
PY
}

echo "Version  ${VERSION}  (was ${CURRENT})"
echo "Build    ${BUILD}"

if [[ "$DRY" -eq 1 ]]; then
  echo "dry-run: would write Info.plist, build, zip to dist/MagicLoupe-${VERSION}-macos.zip"
  [[ "$PUBLISH" -eq 1 ]] && echo "dry-run: would tag v${VERSION} and create a GitHub Release"
  exit 0
fi

plist_set CFBundleShortVersionString "$VERSION"
plist_set CFBundleVersion "$BUILD"

SWIFT_ARCHES="${SWIFT_ARCHES:-arm64 x86_64}"
export SWIFT_ARCHES

echo "Building release (${SWIFT_ARCHES})…"
BUILD_ARGS=(-c release --product MagicLoupe)
# shellcheck disable=SC2086
for arch in ${SWIFT_ARCHES}; do
  BUILD_ARGS+=(--arch "$arch")
done

if ! swift build "${BUILD_ARGS[@]}" "${INFOLINK[@]}"; then
  if [[ "$SWIFT_ARCHES" != "arm64" ]]; then
    echo "universal build failed, retrying arm64-only" >&2
    SWIFT_ARCHES="arm64"
    export SWIFT_ARCHES
    BUILD_ARGS=(-c release --product MagicLoupe --arch arm64)
    swift build "${BUILD_ARGS[@]}" "${INFOLINK[@]}"
  else
    exit 1
  fi
fi

DIST="$ROOT/dist"
APP="$DIST/MagicLoupe.app"
ZIP="$DIST/MagicLoupe-${VERSION}-macos.zip"
rm -rf "$APP" "$ZIP"
mkdir -p "$DIST"

PACKAGE_APP_DEST="$APP" PACKAGE_INSTALL_LOCAL=0 \
  bash "$ROOT/scripts/package-app.sh" release

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "Notarizing with profile '$NOTARY_PROFILE'…"
  NOTARY_ZIP="$DIST/MagicLoupe-${VERSION}-submit.zip"
  ditto -c -k --keepParent --norsrc --noextattr --noacl "$APP" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$NOTARY_ZIP"
else
  echo "skipping notarization (set NOTARY_PROFILE to enable)"
fi

ditto -c -k --keepParent --norsrc --noextattr --noacl "$APP" "$ZIP"
echo "Zip  $ZIP"
shasum -a 256 "$ZIP" | awk '{print "SHA256  " $1}'

if [[ "$PUBLISH" -eq 0 ]]; then
  echo
  echo "Next: commit the plist bump, then"
  echo "  ./scripts/release.sh ${VERSION} --github"
  exit 0
fi

if ! command -v gh >/dev/null; then
  echo "error: gh is not installed" >&2
  exit 1
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not a git repository" >&2
  exit 1
fi
if ! git rev-parse HEAD >/dev/null 2>&1; then
  echo "error: make an initial commit before publishing a release" >&2
  exit 1
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "error: no origin remote. Create the GitHub repo, then:" >&2
  echo "  git remote add origin git@github.com:<you>/magic-loupe.git" >&2
  exit 1
fi

dirty="$(git status --porcelain | awk '$2 != "Resources/Info.plist" { print }')"
if [[ -n "$dirty" ]]; then
  echo "error: working tree has changes besides Info.plist; commit or stash them first" >&2
  git status --short
  exit 1
fi

if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
  echo "error: tag v${VERSION} already exists" >&2
  exit 1
fi

git add Resources/Info.plist
if git diff --cached --quiet; then
  echo "Info.plist already committed at ${VERSION}"
else
  git commit -m "$(cat <<EOF
Release ${VERSION}.

EOF
)"
fi

git tag -a "v${VERSION}" -m "Magic Loupe ${VERSION}"
git push origin HEAD
git push origin "v${VERSION}"

NOTES="$(extract_notes)"
gh release create "v${VERSION}" "$ZIP" \
  --title "Magic Loupe ${VERSION}" \
  --notes "$NOTES"

echo
echo "Published v${VERSION}"
gh release view "v${VERSION}" --web && true
