#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
    cat <<'USAGE'
Usage:
  scripts/prepare_homebrew_release.sh <version> [github_owner] [github_repo]

Example:
  scripts/prepare_homebrew_release.sh 1.0.0
  scripts/prepare_homebrew_release.sh 1.0.0 pdong15dth claudiable_status
USAGE
    exit 1
fi

VERSION="$1"
GITHUB_OWNER="${2:-}"
GITHUB_REPO="${3:-}"

APP_BUNDLE_PATH="${APP_BUNDLE_PATH:-claudiable_status/Products/claudiable_status.app}"
DIST_DIR="${DIST_DIR:-dist}"
ZIP_NAME="${ZIP_NAME:-claudiable_status.zip}"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
CASK_OUTPUT_PATH="${DIST_DIR}/claudiable-status.rb"

if [[ -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" ]]; then
    REMOTE_URL="$(git config --get remote.origin.url || true)"

    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
        DETECTED_OWNER="${BASH_REMATCH[1]}"
        DETECTED_REPO="${BASH_REMATCH[2]}"
        GITHUB_OWNER="${GITHUB_OWNER:-$DETECTED_OWNER}"
        GITHUB_REPO="${GITHUB_REPO:-$DETECTED_REPO}"
    fi
fi

if [[ -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" ]]; then
    cat <<'EOF'
Error: Could not detect GitHub owner/repo.
Pass them explicitly:
  scripts/prepare_homebrew_release.sh <version> <github_owner> <github_repo>
EOF
    exit 1
fi

if [[ ! -d "$APP_BUNDLE_PATH" ]]; then
    cat <<EOF
Error: App bundle not found at:
  ${APP_BUNDLE_PATH}

Build the app in Release first, then re-run this script.
EOF
    exit 1
fi

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH"

# Package app bundle with parent directory preserved for Homebrew cask `app` stanza.
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE_PATH" "$ZIP_PATH"

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
RELEASE_TAG="v${VERSION}"
DOWNLOAD_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${ZIP_NAME}"

cat > "$CASK_OUTPUT_PATH" <<EOF
cask "claudiable-status" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "${DOWNLOAD_URL}"
  name "claudiable_status"
  desc "Menu bar dashboard for claudible status"
  homepage "https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}"

  app "claudiable_status.app"
end
EOF

cat <<EOF
Done.

Created:
  - ${ZIP_PATH}
  - ${CASK_OUTPUT_PATH}

SHA256:
  ${SHA256}

Next:
  1) Upload ${ZIP_PATH} to GitHub Release tag ${RELEASE_TAG}
  2) Copy ${CASK_OUTPUT_PATH} into your tap repo at:
       Casks/claudiable-status.rb
  3) Commit + push tap repo
  4) Verify install:
       brew tap ${GITHUB_OWNER}/tap
       brew install --cask claudiable-status
EOF
