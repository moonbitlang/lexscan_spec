#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/moonbit-regex-format.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/case"
printf 'name = "moonbitlang/format-fixture"\n' > "$tmp/moon.mod"
printf 'import {\n  "moonbitlang/core/lexbuf",\n}\n' > "$tmp/case/moon.pkg"
cp "$ROOT/format/regex_match_format.mbt" "$tmp/case/input.mbt"
(
  cd "$tmp"
  moon fmt case/input.mbt
)
diff -u "$ROOT/format/regex_match_format.expected.mbt" "$tmp/case/input.mbt"
