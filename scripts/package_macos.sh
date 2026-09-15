#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_dir="$project_dir/dist/PhotoEditor.app"
bin_dir=$(swift build --package-path "$project_dir" -c release --show-bin-path)
staging_dir=$(mktemp -d)
staged_app="$staging_dir/PhotoEditor.app"
trap 'rm -rf "$staging_dir"' EXIT

swift build --package-path "$project_dir" -c release --product PhaseOnePhotoEditor

mkdir -p "$staged_app/Contents/MacOS" "$project_dir/dist"
cp "$bin_dir/PhaseOnePhotoEditor" "$staged_app/Contents/MacOS/PhaseOnePhotoEditor"
cp "$project_dir/Resources/Info.plist" "$staged_app/Contents/Info.plist"
codesign --force --sign - "$staged_app"
codesign --verify --deep --strict "$staged_app"
if [[ -e "$app_dir" ]]; then
  mv "$app_dir" "$staging_dir/previous.app"
fi
mv "$staged_app" "$app_dir"
printf 'Packaged %s\n' "$app_dir"
