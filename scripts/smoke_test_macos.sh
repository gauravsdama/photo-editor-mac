#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}

"$script_dir/package_macos.sh"
"$project_dir/dist/PhotoEditor.app/Contents/MacOS/PhaseOnePhotoEditor" --ui-smoke-test
