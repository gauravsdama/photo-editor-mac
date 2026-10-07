#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}

swift build --package-path "$project_dir" -c release --product PhaseOnePhotoEditor

printf '%s\n' 'Cold launch process measurement:'
/usr/bin/time -l "$project_dir/.build/release/PhaseOnePhotoEditor" --benchmark-launch

printf '%s\n' 'Workflow measurements and peak test-process memory:'
PHOTO_EDITOR_RUN_BENCHMARKS=1 /usr/bin/time -l \
  swift test --package-path "$project_dir" --filter PerformanceBenchmarks.workflowMeasurements
