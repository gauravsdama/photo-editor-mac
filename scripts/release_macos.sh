#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
identity=${PHOTO_EDITOR_SIGNING_IDENTITY:-}
notary_profile=${PHOTO_EDITOR_NOTARY_PROFILE:-}

fail() {
  printf 'Release failed: %s\n' "$1" >&2
  exit 1
}

[[ -n "$identity" ]] || fail "set PHOTO_EDITOR_SIGNING_IDENTITY to a Developer ID Application identity"
[[ -n "$notary_profile" ]] || fail "set PHOTO_EDITOR_NOTARY_PROFILE to a notarytool keychain profile"
security find-identity -v -p codesigning | grep -Fq "$identity" || fail "signing identity is not available in the keychain"

PHOTO_EDITOR_SIGNING_IDENTITY="$identity" "$script_dir/package_macos.sh"
app_dir="$project_dir/dist/PhotoEditor.app"
PHOTO_EDITOR_EXPECT_DEVELOPER_ID=1 "$script_dir/validate_macos_app.sh" "$app_dir"

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_dir/Contents/Info.plist")
architecture=$(lipo -archs "$app_dir/Contents/MacOS/PhaseOnePhotoEditor" | tr ' ' '-')
archive="$project_dir/dist/PhotoEditor-${version}-macOS-${architecture}.zip"
checksum="$archive.sha256"

rm -f "$archive" "$checksum"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
xcrun notarytool submit "$archive" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$app_dir"
xcrun stapler validate "$app_dir"
spctl --assess --type execute --verbose=4 "$app_dir"

# The final archive must contain the stapled application, not the pre-stapling bundle.
rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
(cd "$project_dir/dist" && shasum -a 256 "${archive:t}" > "${checksum:t}")
"$script_dir/verify_release_archive.sh" "$archive"

printf 'Release artifact: %s\n' "$archive"
printf 'Checksum: %s\n' "$checksum"
