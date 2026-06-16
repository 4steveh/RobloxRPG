#!/usr/bin/env bash
# Wild World — Step 1 verification. Proves the Definition of Done end to end:
#   1. --!strict type-checks clean (every src/ + tests/ module)
#   2. all unit tests pass
#   3. the negative fixtures FAIL analysis (unrepresentable-by-construction guarantees hold)
#   4. the project is Rojo-syncable (rojo build succeeds)
# Requires: luau, luau-analyze, rojo on PATH.
set -uo pipefail
cd "$(dirname "$0")"

fail=0
hr() { printf '%s\n' "────────────────────────────────────────────────────────"; }

hr; echo "1) STRICT TYPE-CHECK (luau-analyze, languageMode=strict)"; hr
while IFS= read -r f; do
  if out=$(luau-analyze "$f" 2>&1); then
    echo "  ✓ $f"
  else
    echo "  ✗ $f"; echo "$out" | sed 's/^/      /'; fail=1
  fi
done < <(find src tests -name '*.luau' -not -path '*/negative/*' | sort)

hr; echo "2) UNIT TESTS (luau tests/run.luau)"; hr
if luau tests/run.luau; then echo "  ✓ all specs passed"; else echo "  ✗ test failures"; fail=1; fi

hr; echo "3) NEGATIVE FIXTURES (each MUST fail luau-analyze)"; hr
for f in tests/negative/*.luau; do
  if luau-analyze "$f" >/dev/null 2>&1; then
    echo "  ✗ $f analyzed CLEAN but should have failed (unrepresentability not enforced!)"; fail=1
  else
    echo "  ✓ $f correctly rejected by the type-checker"
  fi
done

hr; echo "4) ROJO BUILD (project is sync-able)"; hr
if out=$(rojo build default.project.json --output /tmp/wildworld.rbxlx 2>&1); then
  echo "  ✓ rojo build → /tmp/wildworld.rbxlx ($(wc -c </tmp/wildworld.rbxlx) bytes)"
else
  echo "  ✗ rojo build failed"; echo "$out" | sed 's/^/      /'; fail=1
fi

hr
if [ "$fail" -eq 0 ]; then echo "ALL GREEN ✓"; else echo "FAILURES ✗"; fi
exit $fail
