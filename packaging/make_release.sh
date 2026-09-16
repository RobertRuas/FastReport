#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-${GITHUB_REF_NAME:-}}"
if [[ -z "$TAG" ]]; then
  echo "usage: packaging/make_release.sh v0.1.0" >&2
  exit 1
fi

VERSION="${TAG#v}"
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  OWNER="${GITHUB_REPOSITORY%%/*}"
  REPO_NAME="${GITHUB_REPOSITORY##*/}"
else
  OWNER="${GITHUB_REPOSITORY_OWNER:-RobertRuas}"
  REPO_NAME="FastReport"
fi
DOWNLOAD_PREFIX="https://github.com/${OWNER}/${REPO_NAME}/releases/download/${TAG}/"
ARCHIVES="$ROOT/packaging/archives"
TOOLS="$ROOT/packaging/tools"
SPARKLE_VERSION="2.7.1"

cd "$ROOT"
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate

xcodebuild \
  -project FastReport.xcodeproj \
  -scheme FastReport \
  -configuration Release \
  -derivedDataPath "$ROOT/build/release" \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-YES}" \
  build

APP="$ROOT/build/release/Build/Products/Release/FastReport.app"
if [[ ! -d "$APP" ]]; then
  echo "missing app at $APP" >&2
  exit 1
fi

rm -rf "$ARCHIVES"
mkdir -p "$ARCHIVES"
ditto -c -k --keepParent "$APP" "$ARCHIVES/FastReport-${VERSION}.zip"

if [[ ! -x "$TOOLS/bin/generate_appcast" ]]; then
  mkdir -p "$TOOLS"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" | tar -xJ -C "$TOOLS"
fi

NOTES="$ARCHIVES/FastReport-${VERSION}.html"
{
  echo "<h2>FastReport ${VERSION}</h2>"
  echo "<p>Atualização ${TAG} publicada em $(date -u +"%Y-%m-%d %H:%M UTC").</p>"
} > "$NOTES"

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "$SPARKLE_PRIVATE_KEY" | "$TOOLS/bin/generate_appcast" \
    --ed-key-file - \
    --download-url-prefix "$DOWNLOAD_PREFIX" \
    --embed-release-notes \
    --link "https://github.com/${OWNER}/${REPO_NAME}/releases/${TAG}" \
    -o "$ARCHIVES/appcast.xml" \
    "$ARCHIVES"
elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  echo "SPARKLE_PRIVATE_KEY secret is required in GitHub Actions." >&2
  exit 1
else
  "$TOOLS/bin/generate_appcast" \
    --account FastReport \
    --download-url-prefix "$DOWNLOAD_PREFIX" \
    --embed-release-notes \
    --link "https://github.com/${OWNER}/${REPO_NAME}/releases/${TAG}" \
    -o "$ARCHIVES/appcast.xml" \
    "$ARCHIVES"
fi

cp "$ARCHIVES/appcast.xml" "$ROOT/packaging/appcast.xml"
echo "created $ARCHIVES/FastReport-${VERSION}.zip and appcast.xml"
