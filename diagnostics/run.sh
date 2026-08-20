#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
FIXTURES="$ROOT/diagnostics/fixtures"
MANIFEST="$ROOT/diagnostics/fixtures.tsv"
FAILED=0
PASSED=0

make_project() {
  local dir=$1
  local imports=$2
  mkdir -p "$dir/case"
  printf 'name = "moonbitlang/spec-fixture"\n' > "$dir/moon.mod"
  if [[ "$imports" == "lexbuf" ]]; then
    printf 'import {\n  "moonbitlang/core/lexbuf",\n}\n' > "$dir/case/moon.pkg"
  else
    printf '' > "$dir/case/moon.pkg"
  fi
}

make_indirect_lexbuf_project() {
  local dir=$1
  mkdir -p "$dir/provider" "$dir/client"
  printf 'name = "moonbitlang/spec-fixture"\n' > "$dir/moon.mod"
  printf 'import {\n  "moonbitlang/core/lexbuf",\n}\n' > "$dir/provider/moon.pkg"
  printf 'pub fn make() -> @lexbuf.Lexbuf {\n  @lexbuf.Lexbuf::from_string("a")\n}\n' > "$dir/provider/provider.mbt"
  printf 'import {\n  "moonbitlang/spec-fixture/provider",\n}\n' > "$dir/client/moon.pkg"
  cp "$FIXTURES/ls_indirect_lexbuf.mbt.txt" "$dir/client/case.mbt"
}

contains_code() {
  local output=$1
  local code=$2
  grep -Fq "[$code]" "$output"
}

while IFS=$'\t' read -r name mode expected forbidden imports; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/moonbit-regex-spec.XXXXXX")
  output="$tmp/output.txt"

  if [[ "$imports" == "special" ]]; then
    make_indirect_lexbuf_project "$tmp"
    check_path="$tmp/client"
  else
    make_project "$tmp" "$imports"
    cp "$FIXTURES/$name.mbt.txt" "$tmp/case/case.mbt"
    check_path="$tmp/case"
  fi

  relative_path=${check_path#"$tmp"/}
  set +e
  if [[ "$mode" == "runtime" ]]; then
    (
      cd "$tmp"
      moon test "$relative_path" --target js
    ) >"$output" 2>&1
  else
    (
      cd "$tmp"
      moon check "$relative_path" --no-render --diagnostic-limit 200
    ) >"$output" 2>&1
  fi
  status=$?
  set -e

  case_ok=1
  if [[ "$mode" == "error" && $status -eq 0 ]]; then
    echo "FAIL $name: expected compilation failure"
    case_ok=0
  elif [[ "$mode" != "error" && $status -ne 0 ]]; then
    echo "FAIL $name: expected successful checking"
    case_ok=0
  fi

  if [[ "$expected" != "-" ]]; then
    IFS=',' read -ra codes <<< "$expected"
    for code in "${codes[@]}"; do
      if ! contains_code "$output" "$code"; then
        echo "FAIL $name: missing expected diagnostic $code"
        case_ok=0
      fi
    done
  fi

  if [[ "$forbidden" != "-" ]]; then
    IFS=',' read -ra codes <<< "$forbidden"
    for code in "${codes[@]}"; do
      if contains_code "$output" "$code"; then
        echo "FAIL $name: found forbidden diagnostic $code"
        case_ok=0
      fi
    done
  fi

  if [[ $case_ok -eq 1 ]]; then
    echo "PASS $name"
    PASSED=$((PASSED + 1))
  else
    sed -n '1,160p' "$output"
    FAILED=$((FAILED + 1))
  fi
  rm -rf "$tmp"
done < "$MANIFEST"

echo "Diagnostic fixtures: $PASSED passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
