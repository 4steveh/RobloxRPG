#!/usr/bin/env bash
# PostToolUse(Write|Edit|MultiEdit) — strict type-check the file that was just edited.
#
# Honors Wild World's headless/Studio split (see CLAUDE.md "The headless / Studio split"):
#   • only *.luau files inside this repo are checked
#   • *.server.luau / *.client.luau / client/** are Studio-only (reference Roblox globals) — skipped
#   • tests/negative/** are DESIGNED to fail analysis (DoD gate 3) — skipped
# On a real type error it exits 2, so luau-analyze's output is fed straight back to Claude to fix.
set -uo pipefail

# Repo root = two levels up from this script (.claude/hooks/ -> repo root). Self-locating so it works
# regardless of which directory Claude Code was launched from. We cd there so luau-analyze resolves the
# .luaurc require-by-string aliases (@src/..., @tests/...).
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd) || exit 0

payload=$(cat)
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

# Only Luau source inside this repo.
case "$file" in
  "$repo_root"/*.luau) ;;
  *) exit 0 ;;
esac
# Skip Studio-only scripts and the intentionally-failing negative fixtures.
case "$file" in
  *.server.luau|*.client.luau|*/client/*|*/tests/negative/*) exit 0 ;;
esac
[ -f "$file" ] || exit 0
command -v luau-analyze >/dev/null 2>&1 || exit 0

cd "$repo_root" || exit 0
if ! out=$(luau-analyze "$file" 2>&1); then
  {
    echo "luau-analyze (--!strict) reported issues in ${file#"$repo_root"/} — fix before continuing:"
    echo "$out"
  } >&2
  exit 2
fi
exit 0
