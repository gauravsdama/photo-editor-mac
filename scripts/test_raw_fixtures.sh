#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}

if (( $# == 0 )); then
  printf 'Usage: %s RAW_FILE [RAW_FILE ...]\n' "$0" >&2
  exit 2
fi

for fixture in "$@"; do
  [[ -f "$fixture" ]] || { printf 'Missing fixture: %s\n' "$fixture" >&2; exit 1; }
  fixture_path=${fixture:A}
  if [[ "$fixture_path" == "$project_dir"/* ]]; then
    printf 'RAW fixtures must remain outside the repository: %s\n' "$fixture_path" >&2
    exit 1
  fi
  printf 'Testing %s\n' "${fixture_path:t}"
  PHOTO_EDITOR_RAW_FIXTURE="$fixture_path" swift test --package-path "$project_dir" \
    --filter RAWWorkflowTests.realRAWFixture
done
