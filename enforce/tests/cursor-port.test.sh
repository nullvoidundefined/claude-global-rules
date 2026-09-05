#!/usr/bin/env bash
# cursor-port.test.sh: the Cursor port stays generated from its sources, and
# the hook adapter turns Cursor payloads into the same decisions the Claude
# Code hooks make.
#
# Invariants:
#   1. cursor/build.mjs --check passes on the committed tree, so a rule edit
#      that forgets to regenerate the port fails the suite.
#   2. hooks.json is well-formed and every hook it names exists; every .mdc
#      carries the three frontmatter keys; exactly three rules are always-on;
#      nothing generated contains an em dash (R-207).
#   3. The adapter, fed Cursor-shaped payloads, allows a benign command,
#      denies a secret and an em dash, mirrors the settings.json deny and ask
#      rules (including inside a compound command), asks before a mutating
#      MCP call, denies a credential-file read while allowing .env.example,
#      defers an edit-gate finding to the stop hook exactly once, suppresses
#      an identical followup on the very next stop, and fails open on garbage
#      input and unknown events.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADAPTER="$ROOT/cursor/hooks/claude-hook-adapter.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export CLAUDE_FIRE_LOG=/dev/null
export CLAUDE_CURSOR_STATE_DIR="$TMP/state"
export CLAUDE_SETTINGS_FILE="$ROOT/settings.json"
export CLAUDE_HOOKS_DIR="$ROOT/hooks"

fail() { echo "FAIL: $1"; exit 1; }
EM_DASH=$(printf '\xe2\x80\x94')

# 1. Generated tree is fresh.
node "$ROOT/cursor/build.mjs" --check >/dev/null 2>"$TMP/check.err" \
  || fail "cursor/ is out of date with its sources: $(cat "$TMP/check.err" | head -3)"

# 2. Shape of the port.
jq -e '.version == 1 and (.hooks | length >= 9)' "$ROOT/cursor/hooks.json" >/dev/null || fail "hooks.json must be version 1 with the nine events"
[ "$(ls -d "$ROOT"/cursor/skills/*/ | wc -l | tr -d ' ')" = "$(ls -d "$ROOT"/skills/*/ | wc -l | tr -d ' ')" ] || fail "every skill must be rendered into cursor/skills"
grep -q '```!' "$ROOT/cursor/skills/protocol/SKILL.md" && fail "the protocol skill must not carry a shell include"
[ -x "$ADAPTER" ] || fail "adapter is not executable"
[ -x "$ROOT/cursor/install.sh" ] || fail "install.sh is not executable"
for rule in "$ROOT"/cursor/rules/*.mdc; do
  [ "$(head -1 "$rule")" = "---" ] || fail "$(basename "$rule") has no frontmatter"
  grep -q '^description: .' "$rule" || fail "$(basename "$rule") has no description"
  grep -q '^globs:' "$rule" || fail "$(basename "$rule") has no globs line"
  grep -qE '^alwaysApply: (true|false)$' "$rule" || fail "$(basename "$rule") has no alwaysApply"
done
ALWAYS_ON=$(grep -l '^alwaysApply: true$' "$ROOT"/cursor/rules/*.mdc | wc -l | tr -d ' ')
[ "$ALWAYS_ON" = "3" ] || fail "expected 3 always-on rules (global rules, session types, memory index), found $ALWAYS_ON"
grep -q '^globs: \*\*/\*\.py$' "$ROOT/cursor/rules/python.mdc" || fail "python.mdc globs were not derived from the paths: frontmatter"
grep -rq "$EM_DASH" "$ROOT/cursor" && fail "an em dash reached the generated port (R-207)"
grep -q 'hook:task-commit-reminder in Claude Code; manual in Cursor' "$ROOT/cursor/rules/000-global-rules.mdc" || fail "un-ported hook tags are not annotated"
grep -q '\[hook:no-em-dash\]$' "$ROOT/cursor/rules/000-global-rules.mdc" || fail "ported hook tags must stay untouched"

# 3. Adapter decisions.
run() { printf '%s' "$1" | "$ADAPTER" "${@:2}" 2>/dev/null; }
permission() { jq -r '.permission // ""'; }

[ "$(run '{"command":"ls -la","cwd":"/tmp","conversation_id":"t"}' beforeShellExecution secret-scan no-em-dash | permission)" = "allow" ] || fail "benign command not allowed"
[ "$(run '{"command":"echo sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","cwd":"/tmp","conversation_id":"t"}' beforeShellExecution secret-scan | permission)" = "deny" ] || fail "secret on argv not denied"
OUT=$(run "{\"command\":\"git commit -m \\\"fix $EM_DASH typo\\\"\",\"cwd\":\"/tmp\",\"conversation_id\":\"t\"}" beforeShellExecution no-em-dash)
[ "$(printf '%s' "$OUT" | permission)" = "deny" ] || fail "em dash in a command not denied"
printf '%s' "$OUT" | jq -e '.user_message and .agent_message' >/dev/null || fail "deny must carry user_message and agent_message"
[ "$(run '{"command":"gh auth token","cwd":"/tmp","conversation_id":"t"}' beforeShellExecution | permission)" = "deny" ] || fail "settings.json Bash deny rule not mirrored"
[ "$(run '{"command":"cd /x && git push --force origin main","cwd":"/tmp","conversation_id":"t"}' beforeShellExecution | permission)" = "ask" ] || fail "settings.json Bash ask rule not mirrored inside a compound command"
[ "$(run '{"command":"git push origin feature","cwd":"/tmp","conversation_id":"t"}' beforeShellExecution | permission)" = "allow" ] || fail "an ordinary push must not match the force-push ask rule"
[ "$(run '{"tool_name":"notion-create-pages","tool_input":{},"workspace_roots":["/tmp"],"conversation_id":"t"}' beforeMCPExecution mcp-action-guard | permission)" = "ask" ] || fail "mutating MCP call not asked (R-105)"
[ "$(run '{"tool_name":"list_issues","tool_input":{},"workspace_roots":["/tmp"],"conversation_id":"t"}' beforeMCPExecution mcp-action-guard | permission)" = "allow" ] || fail "read-only MCP call must be allowed"
[ "$(run '{"file_path":"/repo/.env","conversation_id":"t"}' beforeReadFile | permission)" = "deny" ] || fail ".env read not denied (R-102)"
[ "$(run '{"file_path":"/repo/.env.production","conversation_id":"t"}' beforeReadFile | permission)" = "deny" ] || fail ".env.production read not denied (R-102)"
[ "$(run '{"file_path":"/repo/.env.example","conversation_id":"t"}' beforeReadFile | permission)" = "allow" ] || fail ".env.example must stay readable"
[ "$(run '{"file_path":"/repo/src/index.ts","conversation_id":"t"}' beforeReadFile | permission)" = "allow" ] || fail "source read must be allowed"

# Edit gates cannot block under Cursor: the finding is deferred to stop, once.
mkdir -p "$TMP/proj/src/services"
run "{\"file_path\":\"$TMP/proj/src/services/a.ts\",\"edits\":[{\"old_string\":\"\",\"new_string\":\"const a = 1; // $EM_DASH\\n\"}],\"workspace_roots\":[\"$TMP/proj\"],\"conversation_id\":\"edit\"}" afterFileEdit no-em-dash >/dev/null
[ -s "$CLAUDE_CURSOR_STATE_DIR/edit.findings" ] || fail "afterFileEdit did not record the em-dash finding"
FOLLOWUP=$(run "{\"status\":\"completed\",\"workspace_roots\":[\"$TMP/proj\"],\"conversation_id\":\"edit\"}" stop | jq -r '.followup_message // ""')
printf '%s' "$FOLLOWUP" | grep -q 'no-em-dash hook BLOCKED' || fail "stop did not surface the deferred finding as followup_message"
[ "$(run "{\"status\":\"completed\",\"workspace_roots\":[\"$TMP/proj\"],\"conversation_id\":\"edit\"}" stop)" = "{}" ] || fail "a consumed finding must not be surfaced twice"
[ "$(run '{"status":"aborted","workspace_roots":["/tmp"],"conversation_id":"edit"}' stop)" = "{}" ] || fail "an aborted turn must not run the stop gates"

# A stop gate that keeps failing is surfaced once, suppressed on the identical
# re-stop, and surfaced again after that (a stub replaces verification-gate).
mkdir -p "$TMP/hooks"
cat >"$TMP/hooks/verification-gate.sh" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '{"decision":"block","reason":"R-509 verification gate: pnpm test failed"}\n'
EOF
chmod +x "$TMP/hooks/verification-gate.sh"
FIRST=$(CLAUDE_HOOKS_DIR="$TMP/hooks" run '{"status":"completed","workspace_roots":["/tmp"],"conversation_id":"red"}' stop verification-gate | jq -r '.followup_message // ""')
printf '%s' "$FIRST" | grep -q 'pnpm test failed' || fail "a blocking stop hook must become a followup_message"
[ "$(CLAUDE_HOOKS_DIR="$TMP/hooks" run '{"status":"completed","workspace_roots":["/tmp"],"conversation_id":"red"}' stop verification-gate)" = "{}" ] || fail "an identical followup must be suppressed on the next stop (loop guard)"
THIRD=$(CLAUDE_HOOKS_DIR="$TMP/hooks" run '{"status":"completed","workspace_roots":["/tmp"],"conversation_id":"red"}' stop verification-gate | jq -r '.followup_message // ""')
printf '%s' "$THIRD" | grep -q 'pnpm test failed' || fail "the loop guard must reset after one suppression"

# preToolUse (newer builds): an edit-shaped payload reaches the gates, a shell
# or read payload does not.
[ "$(run "{\"tool_name\":\"edit_file\",\"tool_input\":{\"target_file\":\"$TMP/proj/src/services/c.ts\",\"code_edit\":\"const c = 1; // $EM_DASH\"},\"workspace_roots\":[\"$TMP/proj\"],\"conversation_id\":\"pre\"}" preToolUse no-em-dash | permission)" = "deny" ] || fail "preToolUse must deny an em dash in an edit-shaped payload"
[ "$(run '{"tool_name":"run_terminal_cmd","tool_input":{"command":"ls"},"conversation_id":"pre"}' preToolUse no-em-dash | permission)" = "allow" ] || fail "preToolUse must leave shell payloads to beforeShellExecution"

# Fail open.
[ "$(printf 'not json' | "$ADAPTER" beforeShellExecution secret-scan 2>/dev/null | permission)" = "allow" ] || fail "garbage stdin must fail open"
[ "$(run '{}' somethingElse)" = "{}" ] || fail "an unknown event must answer {}"

echo "cursor-port.test.sh PASS"
