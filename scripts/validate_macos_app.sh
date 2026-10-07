#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_dir=${1:-"$project_dir/dist/PhotoEditor.app"}
contents_dir="$app_dir/Contents"
executable="$contents_dir/MacOS/PhaseOnePhotoEditor"
resources_dir="$contents_dir/Resources"
plist="$contents_dir/Info.plist"

fail() {
  printf 'Bundle validation failed: %s\n' "$1" >&2
  exit 1
}

[[ -d "$app_dir" ]] || fail "missing app bundle at $app_dir"
[[ -x "$executable" ]] || fail "missing executable"
[[ -f "$plist" ]] || fail "missing Info.plist"
[[ -f "$resources_dir/LICENSE" ]] || fail "missing LICENSE"
[[ -f "$resources_dir/NOTICE.md" ]] || fail "missing NOTICE.md"

cmp -s "$project_dir/LICENSE" "$resources_dir/LICENSE" || fail "bundled LICENSE differs from source"
cmp -s "$project_dir/NOTICE.md" "$resources_dir/NOTICE.md" || fail "bundled NOTICE.md differs from source"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$plist" 2>/dev/null
}

[[ $(plist_value CFBundleExecutable) == "PhaseOnePhotoEditor" ]] || fail "unexpected executable name"
[[ $(plist_value CFBundleIdentifier) == "dev.gauravdama.photo-editor" ]] || fail "unexpected bundle identifier"
[[ $(plist_value CFBundleShortVersionString) == "0.1.0" ]] || fail "unexpected short version"
[[ $(plist_value CFBundleVersion) == "1" ]] || fail "unexpected bundle version"
[[ $(plist_value LSMinimumSystemVersion) == "14.0" ]] || fail "unexpected minimum macOS version"
[[ $(plist_value NSHumanReadableCopyright) == "Copyright © 2026 Gaurav Dama." ]] || fail "missing copyright metadata"

codesign --verify --deep --strict "$app_dir" || fail "invalid code signature"

if find "$app_dir" -type l -print -quit | grep -q .; then
  fail "symbolic links are not allowed in the local bundle"
fi

if find "$app_dir" -type f \( \
  -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' -o \
  -iname '*.tif' -o -iname '*.tiff' -o -iname '*.dng' -o -iname '*.raw' -o \
  -iname '*.nef' -o -iname '*.cr2' -o -iname '*.cr3' -o -iname '*.arw' -o \
  -iname '*.raf' -o -iname '*.orf' -o -iname '*.rw2' -o -iname '*.photoedit' -o \
  -iname '*.xmp' -o -iname '*.swift' -o \
  -iname '*.pem' -o -iname '*.key' -o -iname '.env*' \
\) -print -quit | grep -q .; then
  fail "bundle contains source, personal media, or credential-like files"
fi

if find "$app_dir" -mindepth 1 \( -name '.runtime' -o -name '.git' -o -name 'OmniGen' -o -name 'RapidRAW' -o -name 'tui.image-editor' \) -print -quit | grep -q .; then
  fail "bundle contains a runtime or source checkout"
fi

if LC_ALL=C grep -aqE '/Users/|/home/|\.runtime/' "$executable"; then
  fail "executable contains a developer-specific or runtime path"
fi

if grep -ERq 'BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY' "$resources_dir"; then
  fail "resources contain private-key material"
fi

printf 'Validated %s (%s)\n' "$app_dir" "$(lipo -archs "$executable")"
