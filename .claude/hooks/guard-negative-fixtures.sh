#!/usr/bin/env bash
# PreToolUse(Write|Edit|MultiEdit) — speed bump on tests/negative/*.luau.
#
# These fixtures MUST fail luau-analyze (DoD gate 3 proves invalid states are unrepresentable by
# construction — see run-tests.sh and CLAUDE.md "Negative fixtures"). "Fixing" their type errors
# silently guts the guarantee. So we surface an explicit confirmation prompt before any edit lands
# there — a deliberate, legitimate fixture change just confirms once; an accidental "fix" gets caught.
set -uo pipefail

payload=$(cat)
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

case "$file" in
  */tests/negative/*.luau|tests/negative/*.luau)
    jq -n --arg f "$file" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: ("\($f) is a NEGATIVE FIXTURE — it is designed to FAIL luau-analyze (Wild World DoD gate 3: invalid states are unrepresentable by construction). Do NOT \"fix\" its type errors. Confirm only if you are deliberately updating the fixture to a genuinely changed schema.")
      }
    }'
    exit 0 ;;
esac
exit 0
