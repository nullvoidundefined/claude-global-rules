#!/usr/bin/env bash
# cursor-port.test.sh: the Cursor port builds cleanly into a directory beside
# ~/.claude, and the hook adapter turns Cursor payloads into the same decisions
# the Claude Code hooks make.
#
# Invariants (the build targets a temporary directory, never ~/.cursor):
#   1. --write produces the tree, records a manifest, and --check passes;
#      an edited file fails --check; a foreign file in the target makes
#      --write refuse; --project writes repo-relative adapter commands.
#   2. hooks.json names existing hooks and the adapter it ships beside;
#      every .mdc carries the three frontmatter keys; exactly three rules
#      are always-on; every skill is present; nothing contains an em dash
#      (R-207); un-ported hook tags are annotated and ported ones untouched.
#   3. The adapter, fed Cursor-shaped payloads, allows a benign command,
#      denies a secret and an em dash, mirrors the settings.json deny and ask
#      rules (including inside a compound command), asks before a mutating
#      MCP call, denies a credential-file read while allowing .env.example,
#      denies an edit-shaped preToolUse payload and ignores a shell one,
#      defers an afterFileEdit finding to the stop hook exactly once,
#      suppresses an identical followup on the very next stop, and fails
#      open on garbage input and unknown events.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/cursor"
export CLAUDE_FIRE_LOG=/dev/null
export CLAUDE_HOME="$ROOT"
export CLAUDE_CURSOR_STATE_DIR="$TMP/state"

fail() { echo "FAIL: $1"; exit 1; }
EM_DASH=$(printf '\xe2\x80\x94')

# 1. The build.
node "$ROOT/cursor/build.mjs" --write --out "$OUT" >/dev/null 2>"$TMP/err" || fail "build failed: $(head -3 "$TMP/err")"
[ -f "$OUT/.claude-port.json" ] || fail "no manifest written"
node "$ROOT/cursor/build.mjs" --check --out "$OUT" >/dev/null 2>&1 || fail "--check fails right after --write"
printf 'x\n' >>"$OUT/rules/python.mdc"
node "$ROOT/cursor/build.mjs" --check --out "$OUT" >/dev/null 2>&1 && fail "--check must fail after a file drifts"
node "$ROOT/cursor/build.mjs" --write --out "$OUT" >/dev/null 2>&1 || fail "rewrite after drift failed"
mkdir -p "$TMP/taken" && printf '{}\n' >"$TMP/taken/hooks.json"
node "$ROOT/cursor/build.mjs" --write --out "$TMP/taken" >/dev/null 2>&1 && fail "--write must refuse a target holding a file it did not write"
[ "$(cat "$TMP/taken/hooks.json")" = "{}" ] || fail "a refused write must leave the foreign file untouched"
mkdir -p "$TMP/repo"
node "$ROOT/cursor/build.mjs" --write --project "$TMP/repo" >/dev/null 2>&1 || fail "--project build failed"
grep -q '"command": ".cursor/hooks/claude-hook-adapter.sh ' "$TMP/repo/.cursor/hooks.json" || fail "--project must use repo-relative adapter commands"

# 2. Shape of the port.
ADAPTER="$OUT/hooks/claude-hook-adapter.sh"
[ -x "$ADAPTER" ] || fail "adapter not written executable into the target"
jq -e '.version == 1 and (.hooks | length >= 9)' "$OUT/hooks.json" >/dev/null || fail "hooks.json must be version 1 with the nine events"
jq -e '[.hooks[][] | .command | startswith("~/.cursor/hooks/claude-hook-adapter.sh ")] | all' "$OUT/hooks.json" >/dev/null || fail "user-level hooks.json must call the adapter beside it"
for name in $(jq -r '.hooks[][] | .command' "$OUT/hooks.json" | awk '{for (i = 3; i <= NF; i++) print $i}' | sort -u); do
  [ -x "$ROOT/hooks/$name.sh" ] || fail "hooks.json names hooks/$name.sh, which is missing or not executable"
done
[ "$(ls -d "$OUT"/skills/*/ | wc -l | tr -d ' ')" = "$(ls -d "$ROOT"/skills/*/ | wc -l | tr -d ' ')" ] || fail "every skill must be rendered"
grep -q '```!' "$OUT/skills/protocol/SKILL.md" && fail "the protocol skill must not carry a shell include"
for rule in "$OUT"/rules/*.mdc; do
  [ "$(head -1 "$rule")" = "---" ] || fail "$(basename "$rule") has no frontmatter"
  grep -q '^description: .' "$rule" || fail "$(basename "$rule") has no description"
  grep -q '^globs:' "$rule" || fail "$(basename "$rule") has no globs line"
  grep -qE '^alwaysApply: (true|false)$' "$rule" || fail "$(basename "$rule") has no alwaysApply"
done
ALWAYS_ON=$(grep -l '^alwaysApply: true$' "$OUT"/rules/*.mdc | wc -l | tr -d ' ')
[ "$ALWAYS_ON" = "3" ] || fail "expected 3 always-on rules (global rules, session types, memory index), found $ALWAYS_ON"
grep -q '^globs: \*\*/\*\.py$' "$OUT/rules/python.mdc" || fail "python.mdc globs were not derived from the paths: frontmatter"
grep -rq "$EM_DASH" "$OUT" && fail "an em dash reached the generated port (R-207)"
grep -q 'hook:task-commit-reminder in Claude Code; manual in Cursor' "$OUT/rules/000-global-rules.mdc" || fail "un-ported hook tags are not annotated"
grep -q '\[hook:no-em-dash\]$' "$OUT/rules/000-global-rules.mdc" || fail "ported hook tags must stay untouched"
[ -f "$OUT/PORT-STATUS.md" ] || fail "PORT-STATUS.md missing"

# 3. Adapter decisions.
run() { printf '%s' "$1" | "$ADAPTER" "${@:2}" 2>/dev/null; }
permission() { jq -r '.permission // ""'; }

[ "$(run '{"command":"ls -la","cwd":"/tmp","conversation_id":"t"}' beforeShellExecution secret-scan no-em-dash | permission)" = "allow" ] || fail "benign command not allowed"
[ "$(run '{"command":"echo sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","cwd":"/tmp","conversation_id":"t"}' beforeShellExecution secret-scan | permission)" = "deny" ] || fail "secret on argv not denied"
OUTPUT=$(run "{\"command\":\"git commit -m \\\"fix $EM_DASH typo\\\"\",\"cwd\":\"/tmp\",\"conversation_id\":\"t\"}" beforeShellExecution no-em-dash)
[ "$(printf '%s' "$OUTPUT" | permission)" = "deny" ] || fail "em dash in a command not denied"
printf '%s' "$OUTPUT" | jq -e '.user_message and .agent_message' >/dev/null || fail "deny must carry user_message and agent_message"
[ "$(run '{"command":"gh auth token","cwd":"/tmp","conversation_id":"t"}' beforeShellExecution | permission)" = "deny" ] || fail "settings.json Bash deny rule not mirrored"
[ "$(run '{"command":"cd /x && git push --force origin main","cwd":"/tmp","conversation_id":"t"}' beforeShellExecution | permission)" = "ask" ] || fail "settings.json Bash ask rule not mirrored inside a compound command"
[ "$(run '{"command":"git push origin feature","cwd":"/tmp","conversation_id":"t"}' beforeShellExecution | permission)" = "allow" ] || fail "an ordinary push must not match the force-push ask rule"
[ "$(run '{"tool_name":"notion-create-pages","tool_input":{},"workspace_roots":["/tmp"],"conversation_id":"t"}' beforeMCPExecution mcp-action-guard | permission)" = "ask" ] || fail "mutating MCP call not asked (R-105)"
[ "$(run '{"tool_name":"list_issues","tool_input":{},"workspace_roots":["/tmp"],"conversation_id":"t"}' beforeMCPExecution mcp-action-guard | permission)" = "allow" ] || fail "read-only MCP call must be allowed"
[ "$(run '{"file_path":"/repo/.env","conversation_id":"t"}' beforeReadFile | permission)" = "deny" ] || fail ".env read not denied (R-102)"
[ "$(run '{"file_path":"/repo/.env.production","conversation_id":"t"}' beforeReadFile | permission)" = "deny" ] || fail ".env.production read not denied (R-102)"
[ "$(run '{"file_path":"/repo/.env.example","conversation_id":"t"}' beforeReadFile | permission)" = "allow" ] || fail ".env.example must stay readable"
[ "$(run '{"file_path":"/repo/src/index.ts","conversation_id":"t"}' beforeReadFile | permission)" = "allow" ] || fail "source read must be allowed"

mkdir -p "$TMP/proj/src/services"
# Built with jq -n and assigned before testing: bash 3.2 (the system bash on
# some machines) mis-tokenizes a $(...) whose argument is a double-quoted
# string with backslash-escaped inner quotes when that $(...) sits directly
# inside a `[ ... ]` test.
PRE_TOOL_PAYLOAD=$(jq -nc --arg f "$TMP/proj/src/services/c.ts" --arg c "const c = 1; // $EM_DASH" --arg root "$TMP/proj" '{tool_name:"edit_file", tool_input:{target_file:$f, code_edit:$c}, workspace_roots:[$root], conversation_id:"pre"}')
PRE_TOOL_DECISION=$(run "$PRE_TOOL_PAYLOAD" preToolUse no-em-dash | permission)
[ "$PRE_TOOL_DECISION" = "deny" ] || fail "preToolUse must deny an em dash in an edit-shaped payload"
[ "$(run '{"tool_name":"run_terminal_cmd","tool_input":{"command":"ls"},"conversation_id":"pre"}' preToolUse no-em-dash | permission)" = "allow" ] || fail "preToolUse must leave shell payloads to beforeShellExecution"

# Edit gates without a pre-edit event: the finding is deferred to stop, once.
run "{\"file_path\":\"$TMP/proj/src/services/a.ts\",\"edits\":[{\"old_string\":\"\",\"new_string\":\"const a = 1; // $EM_DASH\\n\"}],\"workspace_roots\":[\"$TMP/proj\"],\"conversation_id\":\"edit\"}" afterFileEdit no-em-dash >/dev/null
[ -s "$CLAUDE_CURSOR_STATE_DIR/edit.findings" ] || fail "afterFileEdit did not record the em-dash finding"
STOP_PAYLOAD=$(jq -nc --arg root "$TMP/proj" '{status:"completed", workspace_roots:[$root], conversation_id:"edit"}')
FOLLOWUP=$(run "$STOP_PAYLOAD" stop | jq -r '.followup_message // ""')
printf '%s' "$FOLLOWUP" | grep -q 'no-em-dash hook BLOCKED' || fail "stop did not surface the deferred finding as followup_message"
SECOND_STOP=$(run "$STOP_PAYLOAD" stop)
[ "$SECOND_STOP" = "{}" ] || fail "a consumed finding must not be surfaced twice"
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

# Fail open.
[ "$(printf 'not json' | "$ADAPTER" beforeShellExecution secret-scan 2>/dev/null | permission)" = "allow" ] || fail "garbage stdin must fail open"
[ "$(run '{}' somethingElse)" = "{}" ] || fail "an unknown event must answer {}"

echo "cursor-port.test.sh PASS"
