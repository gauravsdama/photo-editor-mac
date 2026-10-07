#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
cd "$project_dir"

fail() {
  printf 'Repository validation failed: %s\n' "$1" >&2
  exit 1
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a Git worktree"

if git ls-files | grep -Eq '(^|/)(\.runtime|\.build|dist)(/|$)'; then
  fail "generated or runtime files are tracked"
fi

if git ls-files | grep -Eiq '\.(jpe?g|png|heic|tiff?|dng|raw|nef|nrw|cr2|cr3|arw|raf|orf|rw2|pef|srw|photoedit|xmp)$'; then
  fail "personal-media file types are tracked"
fi

if git ls-files | grep -Eiq '(^|/)(\.env([^/]*)?|[^/]+\.(pem|key|p12|pfx))$'; then
  fail "credential-like files are tracked"
fi

if git grep -nEI 'BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY|AKIA[0-9A-Z]{16}' -- . >/dev/null; then
  fail "tracked files contain private-key or access-key material"
fi

if git grep -nE '/Users/[^/]+/|/home/[^/]+/' -- \
  Sources Tests Resources docs README.md NOTICE.md Package.swift .github >/dev/null; then
  fail "tracked product files contain a developer-specific home path"
fi

if grep -Eq '\.package[[:space:]]*\(' Package.swift; then
  fail "unexpected third-party Swift package dependency"
fi

[[ ! -f Package.resolved ]] || fail "unexpected Package.resolved file"

printf 'Validated tracked repository privacy and dependency boundary\n'
