#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
archive=${1:-}

[[ -n "$archive" && -f "$archive" ]] || {
  printf 'Usage: %s RELEASE_ZIP\n' "$0" >&2
  exit 2
}

archive=${archive:A}
checksum="$archive.sha256"
verification_dir=$(mktemp -d /tmp/photo-editor-release.XXXXXX)
trap 'rm -rf "$verification_dir"' EXIT

if [[ -f "$checksum" ]]; then
  (cd "${archive:h}" && shasum -a 256 -c "${checksum:t}")
fi

ditto -x -k "$archive" "$verification_dir"
app_dir="$verification_dir/PhotoEditor.app"
PHOTO_EDITOR_EXPECT_DEVELOPER_ID=1 "$script_dir/validate_macos_app.sh" "$app_dir"
xcrun stapler validate "$app_dir"
spctl --assess --type execute --verbose=4 "$app_dir"
"$app_dir/Contents/MacOS/PhaseOnePhotoEditor" --ui-smoke-test

printf 'Verified release archive on %s %s (%s)\n' \
  "$(sw_vers -productVersion)" "$(uname -m)" "$(basename "$archive")"
