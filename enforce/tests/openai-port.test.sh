#!/usr/bin/env bash
# openai-port.test.sh: the Codex port builds cleanly into a directory beside
# ~/.claude, and the Codex adapter turns Codex payloads into the decisions the
# Claude Code hooks make.
#
# Invariants (the build targets a temporary directory, never ~/.codex):
#   1. --write produces the tree with a manifest and --check passes; a
#      foreign AGENTS.md in the target makes --write refuse; --project is
#      rejected (Codex has no project-level build here).
#   2. AGENTS.md stays under the 24 KiB share of Codex's 32 KiB budget and
#      carries the session-types table; hooks.json is Claude Code's schema
#      with every command routed through the adapter beside it and no `if`
#      fields; every agent role is a TOML file with developer_instructions;
#      nothing generated contains an em dash (R-207).
#   3. The adapter denies a secret on argv, mirrors the settings.json deny
#      rules, turns an ask into a deny by default and into context under
#      CLAUDE_CODEX_ASK_POLICY=allow, replays an apply_patch so the em-dash
#      gate denies an Add File and the header reminder fires after it, passes
#      a Stop block through, passes SessionStart context through, stays
#      silent on a clean call, and fails open on garbage input.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/codex"
export CLAUDE_FIRE_LOG=/dev/null
export CLAUDE_HOME="$ROOT"
export CLAUDE_CODEX_STATE_DIR="$TMP/state"

fail() { echo "FAIL: $1"; exit 1; }
EM_DASH=$(printf '\xe2\x80\x94')

# 1. The build.
node "$ROOT/openai/build.mjs" --write --out "$OUT" >/dev/null 2>"$TMP/err" || fail "build failed: $(head -3 "$TMP/err")"
[ -f "$OUT/.claude-port.json" ] || fail "no manifest written"
node "$ROOT/openai/build.mjs" --check --out "$OUT" >/dev/null 2>&1 || fail "--check fails right after --write"
mkdir -p "$TMP/taken" && printf '# mine\n' >"$TMP/taken/AGENTS.md"
node "$ROOT/openai/build.mjs" --write --out "$TMP/taken" >/dev/null 2>&1 && fail "--write must refuse a target holding an AGENTS.md it did not write"
[ "$(cat "$TMP/taken/AGENTS.md")" = "# mine" ] || fail "a refused write must leave the foreign AGENTS.md untouched"
node "$ROOT/openai/build.mjs" --write --project "$TMP" >/dev/null 2>&1 && fail "--project must be rejected for the Codex port"

# 2. Shape of the port.
ADAPTER="$OUT/hooks/codex-hook-adapter.sh"
[ -x "$ADAPTER" ] || fail "adapter not written executable into the target"
AGENTS_BYTES=$(wc -c <"$OUT/AGENTS.md" | tr -d ' ')
[ "$AGENTS_BYTES" -le 24576 ] || fail "AGENTS.md is $AGENTS_BYTES bytes, over the 24 KiB share of Codex's project_doc_max_bytes"
grep -q '^## Session types' "$OUT/AGENTS.md" || fail "AGENTS.md lacks the session-types section"
grep -q 'hook:task-commit-reminder in Claude Code; manual in Codex' "$OUT/AGENTS.md" || fail "un-ported hook tags are not annotated"
grep -q '\[hook:no-em-dash\]$' "$OUT/AGENTS.md" || fail "ported hook tags must stay untouched"
jq -e '.hooks.PreToolUse and .hooks.PostToolUse and .hooks.SessionStart and .hooks.Stop and .hooks.SessionEnd' "$OUT/hooks.json" >/dev/null || fail "hooks.json lacks a Codex event"
jq -e '[.hooks[][] | .hooks[] | select(.type != "command" or (.command | startswith("~/.codex/hooks/codex-hook-adapter.sh ") | not))] | length == 0' "$OUT/hooks.json" >/dev/null || fail "every hooks.json command must route through the adapter beside it"
jq -e '[.. | objects | select(has("if"))] | length == 0' "$OUT/hooks.json" >/dev/null || fail "hooks.json must not carry if-gated groups (Codex has no if)"
jq -e '[.hooks.SessionEnd[].hooks[].timeout] | all(. <= 3)' "$OUT/hooks.json" >/dev/null || fail "SessionEnd handlers must respect Codex's 3s cap"
for name in $(jq -r '.hooks[][] | .hooks[].command' "$OUT/hooks.json" | sed 's#^~/.codex/hooks/codex-hook-adapter.sh ##' | tr ' ' '\n' | sort -u); do
  [ -x "$ROOT/hooks/$name.sh" ] || fail "hooks.json names hooks/$name.sh, which is missing or not executable"
done
[ "$(ls "$OUT"/agents/*.toml | wc -l | tr -d ' ')" = "$(ls "$ROOT"/agents/*.md | wc -l | tr -d ' ')" ] || fail "one TOML role per agent expected"
for role in "$OUT"/agents/*.toml; do
  grep -q '^developer_instructions = ' "$role" || fail "$(basename "$role") lacks developer_instructions"
done
[ -f "$OUT/skills/session-start/SKILL.md" ] || fail "session-start skill missing"
grep -q '```!' "$OUT/skills/protocol/SKILL.md" && fail "protocol skill must not carry a shell include"
grep -rq "$EM_DASH" "$OUT" && fail "an em dash reached the generated port (R-207)"
[ -f "$OUT/PORT-STATUS.md" ] || fail "PORT-STATUS.md missing"

# 3. Adapter decisions.
run() { printf '%s' "$1" | "$ADAPTER" "${@:2}" 2>/dev/null; }
decision() { jq -r '.hookSpecificOutput.permissionDecision // ""'; }
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason // ""'; }

[ -z "$(run '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"},"cwd":"/tmp"}' secret-scan no-em-dash)" ] || fail "a clean call must produce no output (Codex rejects permissionDecision:allow)"
[ "$(run '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"},"cwd":"/tmp"}' secret-scan | decision)" = "deny" ] || fail "secret on argv not denied"
[ "$(run '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"gh auth token"},"cwd":"/tmp"}' | decision)" = "deny" ] || fail "settings.json Bash deny rule not mirrored"
ASK=$(run '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push --force origin main"},"cwd":"/tmp"}')
[ "$(printf '%s' "$ASK" | decision)" = "deny" ] || fail "an ask must become a deny under the default policy"
printf '%s' "$ASK" | reason | grep -q 'cannot pause' || fail "the ask-to-deny reason must explain that Codex cannot pause for confirmation"
ALLOWED=$(printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push --force origin main"},"cwd":"/tmp"}' | CLAUDE_CODEX_ASK_POLICY=allow "$ADAPTER" 2>/dev/null)
[ -z "$(printf '%s' "$ALLOWED" | decision)" ] || fail "under the allow policy an ask must not deny"
printf '%s' "$ALLOWED" | jq -r '.hookSpecificOutput.additionalContext' | grep -q 'CONFIRM WITH THE USER' || fail "under the allow policy the ask must become context"
[ "$(run '{"hook_event_name":"PreToolUse","tool_name":"mcp__notion__notion-create-pages","tool_input":{},"cwd":"/tmp"}' mcp-action-guard | decision)" = "deny" ] || fail "a mutating MCP call must be denied by default (R-105)"

mkdir -p "$TMP/proj/src/services"
PATCH=$(printf '*** Begin Patch\n*** Add File: src/services/a.ts\n+const a = 1; // %s\n+export function getThing() { return a; }\n*** End Patch\n' "$EM_DASH")
PRE=$(jq -n --arg p "$PATCH" --arg cwd "$TMP/proj" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{command:$p},cwd:$cwd}')
[ "$(run "$PRE" secret-scan no-em-dash | decision)" = "deny" ] || fail "an apply_patch adding an em dash must be denied by the replayed edit gate"
run "$PRE" secret-scan no-em-dash | reason | grep -q 'Write call' || fail "the replayed Add File must reach the gate as a Write"
CLEAN=$(jq -n --arg p "$(printf '*** Begin Patch\n*** Update File: src/services/a.ts\n@@\n-const a = 1;\n+const a = 2;\n*** End Patch\n')" --arg cwd "$TMP/proj" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{command:$p},cwd:$cwd}')
[ -z "$(run "$CLEAN" secret-scan no-em-dash structure-gate content-gate)" ] || fail "a clean apply_patch must produce no output"
POST=$(jq -n --arg p "$PATCH" --arg cwd "$TMP/proj" '{hook_event_name:"PostToolUse",tool_name:"apply_patch",tool_input:{command:$p},tool_response:"ok",cwd:$cwd}')
run "$POST" new-file-header-reminder | jq -r '.hookSpecificOutput.additionalContext' | grep -q 'no file-level header' || fail "the header reminder must fire on a replayed Add File"

mkdir -p "$TMP/hooks"
printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf %%s '"'"'{"decision":"block","reason":"R-509 verification gate: pnpm test failed"}'"'"'\n' >"$TMP/hooks/verification-gate.sh"
chmod +x "$TMP/hooks/verification-gate.sh"
STOP=$(printf '%s' '{"hook_event_name":"Stop","stop_hook_active":false,"cwd":"/tmp"}' | CLAUDE_HOOKS_DIR="$TMP/hooks" "$ADAPTER" verification-gate 2>/dev/null)
[ "$(printf '%s' "$STOP" | jq -r '.decision')" = "block" ] || fail "a blocking Stop hook must pass through as decision:block"
printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf %%s '"'"'{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"hello from session-start"}}'"'"'\n' >"$TMP/hooks/session-start.sh"
chmod +x "$TMP/hooks/session-start.sh"
START=$(printf '%s' '{"hook_event_name":"SessionStart","source":"startup","cwd":"/tmp"}' | CLAUDE_HOOKS_DIR="$TMP/hooks" "$ADAPTER" session-start 2>/dev/null)
[ "$(printf '%s' "$START" | jq -r '.hookSpecificOutput.additionalContext')" = "hello from session-start" ] || fail "SessionStart context must pass through"
[ -z "$(printf 'not json' | "$ADAPTER" secret-scan 2>/dev/null)" ] || fail "garbage stdin must fail open"

echo "openai-port.test.sh PASS"
