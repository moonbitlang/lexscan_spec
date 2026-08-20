#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
matrix=$(mktemp "${TMPDIR:-/tmp}/moonbit-regex-matrix.XXXXXX")
implemented=$(mktemp "${TMPDIR:-/tmp}/moonbit-regex-implemented.XXXXXX")
trap 'rm -f "$matrix" "$implemented"' EXIT

rg -o '^\| (RX|RM|LM|LS)-[0-9]+[A-Z]? ' "$ROOT/spec/06-conformance-matrix.md" |
  sed -E 's/^\| ([A-Z]+-[0-9]+[A-Z]?) /\1/' |
  sort -u > "$matrix"

rg -o '(RX|RM|LM|LS)-[0-9]+[A-Z]?' \
  "$ROOT/regex_syntax" \
  "$ROOT/regex_match" \
  "$ROOT/lexmatch" \
  "$ROOT/lexscan" \
  "$ROOT/diagnostics" \
  "$ROOT/format" \
  "$ROOT/scripts" \
  --glob '*.mbt' --glob '*.mbt.txt' --glob '*.tsv' --glob '*.sh' |
  sed 's/.*://' |
  sort -u > "$implemented"

missing=$(comm -23 "$matrix" "$implemented")
extra=$(comm -13 "$matrix" "$implemented")

if [[ -n "$missing" ]]; then
  echo "Coverage IDs without tests:"
  echo "$missing"
  exit 1
fi

if [[ -n "$extra" ]]; then
  echo "Test IDs absent from the coverage matrix:"
  echo "$extra"
  exit 1
fi

echo "All $(wc -l < "$matrix" | tr -d ' ') coverage IDs are represented."
