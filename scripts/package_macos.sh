#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_dir="$project_dir/dist/PhotoEditor.app"
signing_identity=${PHOTO_EDITOR_SIGNING_IDENTITY:--}
bin_dir=$(swift build --package-path "$project_dir" -c release --show-bin-path)
mkdir -p "$project_dir/dist"
staging_dir=$(mktemp -d "$project_dir/dist/.photo-editor-package.XXXXXX")
staged_app="$staging_dir/PhotoEditor.app"
previous_app="$staging_dir/previous.app"

cleanup() {
  local exit_code=$?
  trap - EXIT
  if (( exit_code != 0 )) && [[ -e "$previous_app" ]]; then
    if [[ -e "$app_dir" ]]; then
      mv "$app_dir" "$staging_dir/failed.app" || true
    fi
    mv "$previous_app" "$app_dir" || printf 'Could not restore previous app at %s\n' "$app_dir" >&2
  fi
  rm -rf "$staging_dir"
  exit $exit_code
}
trap cleanup EXIT

swift build --package-path "$project_dir" -c release --product PhaseOnePhotoEditor

mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"
cp "$bin_dir/PhaseOnePhotoEditor" "$staged_app/Contents/MacOS/PhaseOnePhotoEditor"
strip -S "$staged_app/Contents/MacOS/PhaseOnePhotoEditor"
cp "$project_dir/Resources/Info.plist" "$staged_app/Contents/Info.plist"
cp "$project_dir/LICENSE" "$staged_app/Contents/Resources/LICENSE"
cp "$project_dir/NOTICE.md" "$staged_app/Contents/Resources/NOTICE.md"
if [[ "$signing_identity" == "-" ]]; then
  codesign --force --options runtime --timestamp=none --sign - "$staged_app"
else
  codesign --force --options runtime --timestamp \
    --entitlements "$project_dir/Resources/PhotoEditor.entitlements" \
    --sign "$signing_identity" "$staged_app"
fi
"$script_dir/validate_macos_app.sh" "$staged_app"
if [[ -e "$app_dir" ]]; then
  mv "$app_dir" "$previous_app"
fi
mv "$staged_app" "$app_dir"
"$script_dir/validate_macos_app.sh" "$app_dir"
printf 'Packaged %s\n' "$app_dir"
