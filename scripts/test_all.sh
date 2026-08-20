#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

MOONC_OVERRIDE_ARGS=()
if [[ -n "${SPEC_MOONC_OVERRIDE:-}" ]]; then
  MOONC_OVERRIDE_ARGS=(env "MOONC_OVERRIDE=$SPEC_MOONC_OVERRIDE")
fi

moon fmt --check
moon check --deny-warn
moon test --target all
moon test --target all --release
bash scripts/check_format_fixture.sh
bash scripts/check_coverage_ids.sh
"${MOONC_OVERRIDE_ARGS[@]}" bash diagnostics/run.sh
