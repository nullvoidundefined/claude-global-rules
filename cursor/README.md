# Cursor port

The same rules, gates, audit roles, and session procedures as the Claude Code configuration, in the shapes Cursor reads. Nothing here is a second copy to maintain: every file except this README, `build.mjs`, `install.sh`, `hooks.json`, and the adapter is generated from the canonical sources one directory up, and `enforce/tests/cursor-port.test.sh` fails the suite when the generated tree is stale.

## Install

```
bash ~/.claude/cursor/install.sh
```

That symlinks `~/.cursor/rules`, `~/.cursor/hooks.json`, `~/.cursor/agents`, `~/.cursor/commands`, and `~/.cursor/skills` into this directory, so a `git pull` of `~/.claude` updates Cursor too. It refuses to replace anything at those paths it did not create and prints the `mv` to run instead. Restart Cursor afterwards; check Settings > Rules for the `.mdc` rules and Settings > Hooks for the eight events.

Cursor also reads `~/.claude/skills/` as a global skills directory on its own, so the thirteen skills need no port; `~/.cursor/skills` carries only the two overrides whose bodies use Claude Code's shell-include syntax (`/protocol`, `/known-issues`).

If this Cursor build does not read a user-level rules directory, the fallback is per project:

```
bash ~/.claude/cursor/install.sh --project ~/code/some-repo
```

which copies the rules and `hooks.json` into `<repo>/.cursor/`. Copies are snapshots; re-run after a pull. Either way the repo has to live at `~/.claude`: the rule bodies point at `~/.claude/...` for their on-demand reads, and `hooks.json` runs the adapter from `~/.claude/cursor/hooks/`.

## After a rule change

```
node ~/.claude/cursor/build.mjs --write
```

`--check` reports drift and is what the fixture test runs. The build rewrites each Claude Code-specific sentence through an explicit substitution whose needle must still exist in the source, so an edit to CLAUDE.md that moves one of those sentences fails the build with the needle it could not find, rather than emitting stale prose.

## What each layer becomes

| Claude Code | Cursor | Notes |
|---|---|---|
| `CLAUDE.md` | `rules/000-global-rules.mdc`, always on | R-001 rewritten for Cursor's session start; task-tool references generalised; every `[hook:X]` tag with no Cursor event annotated `in Claude Code; manual in Cursor` |
| `rules/session-types.md` | `rules/001-session-types.mdc`, always on | Tier 2 paths point at the rulebook rules below |
| `global-memory/INDEX.md` | `rules/002-global-memory-index.mdc`, always on | Replaces the SessionStart injection, which Cursor does not reliably honor (see Caveats) |
| `CLAUDE-*.md` (path-scoped) | `rules/<stack>.mdc` with `globs` | The `paths:` frontmatter becomes the glob list, so the same files attach the same conventions |
| `rulebook/reference.md` | `rules/rulebook-reference-<block>.mdc`, agent requested | One rule per R-Nxx block so the agent fetches the block it needs, not 54KB |
| `rulebook/{agents,audits,cost}.md` | `rules/rulebook-<name>.mdc`, agent requested | The Tier 2 files |
| `skills/structure-conventions`, `CLOUD-DEPLOYMENT.md` | `rules/structure-conventions.mdc`, `rules/cloud-deployment.mdc` | Also reachable as a skill and a file |
| `agents/*.md` | `agents/*.md` | Cursor subagent frontmatter (`model: inherit`, `readonly` from the tool list); bodies unchanged, model routing stays in the prose |
| slash commands | `commands/*.md` | `session-start`, `session-handoff`, and one dispatcher per agent |
| `settings.json` hooks | `hooks.json` + `hooks/claude-hook-adapter.sh` | 38 of 42 hooks; see `PORT-STATUS.md` for the per-hook table and the four that have no Cursor event |
| `settings.json` permissions | the adapter | `Bash(...)` deny and ask rules mirrored on `beforeShellExecution`; `Read(...)` deny rules mirrored on `beforeReadFile` |

## How the hooks run

Cursor and Claude Code both run hook scripts with JSON on stdin and JSON on stdout, but the event names, payload fields, and response fields differ. `hooks/claude-hook-adapter.sh` is the one Cursor-specific script: `hooks.json` calls it with the Cursor event name and the list of Claude Code hooks to run, it builds the payload those hooks expect, runs them in order, and translates the strongest decision back. The hook scripts in `~/.claude/hooks/` are untouched, so a fix there reaches both tools, and `hooks/hook-integrity-check.sh` covers the adapter and `hooks.json` the same way it covers the hooks.

| Cursor event | Claude Code hooks it runs | Fidelity |
|---|---|---|
| `beforeShellExecution` | the 18 PreToolUse Bash gates, plus the `Bash(...)` permission rules | Full: `deny` and `ask` block before the command runs, with the hook's reason as `user_message` and `agent_message` |
| `beforeMCPExecution` | `mcp-action-guard`, `destructive-db-guard` | Full. Cursor reports a bare tool name, so the adapter prefixes `mcp__cursor__` to match the guards' naming |
| `beforeReadFile` | the `Read(...)` deny rules | Full: `.env*`, `~/.aws`, `~/.ssh`, `~/.gnupg`, gh hosts.yml, `~/.netrc` stay off-path (R-102) |
| `afterFileEdit` | the 5 PreToolUse and 6 PostToolUse Write/Edit hooks | Partial: Cursor has no pre-edit event, so a gate that would have denied the edit cannot. Its finding is written to a per-conversation file and the `stop` hook returns it as `followup_message`, which Cursor submits as the next turn, so the agent is told to repair the edit before the turn stands. The advisory reminders travel the same way |
| `afterShellExecution` | `redact-output` | Detection only, as in Claude Code, and Cursor currently ignores this event's output; the warning is deferred to `stop` as above |
| `sessionStart` | `session-start` and the five integrity and guard checks | Emits `additional_context`; see Caveats |
| `stop` | `verification-gate`, `ntfy-notify`, plus the deferred findings | A red suite becomes a `followup_message`. An identical followup on the very next stop is suppressed once, so a suite the agent cannot fix does not loop the conversation |
| `sessionEnd` | `session-end` | Full |

Debug a payload mismatch after a Cursor update with `CLAUDE_CURSOR_HOOK_DEBUG=1` in Cursor's environment: every raw payload and every hook's output lands in `~/.claude/.cursor-hook-state/debug.log`.

## Caveats

- **Global rules directory.** Cursor documents User Rules as a plain-text setting; reading `.mdc` files from `~/.cursor/rules` is widely reported to work but is not in the primary docs. If Settings > Rules shows nothing after install, use `--project`.
- **sessionStart context.** Bug reports against recent Cursor builds say `additional_context` from `sessionStart` does not always reach the agent. The three always-on rules carry the same content, and the `/session-start` command runs the R-001 procedure by hand.
- **Edits land before the gates see them.** R-207 (em dash), R-103 (credential paths), R-302, R-401, R-405 (content gate), and the structure rules are enforced after the fact through the stop hook rather than blocked at the tool call. The commit-time gates (`beforeShellExecution`) still block a commit that carries a violation.
- **No compaction hook.** `post-compact-rules` has no equivalent; Cursor manages its own summarisation.
- **Task tools.** R-502 and R-504 refer to Cursor's task list; `task-commit-reminder` (which fires on Claude Code's `TaskUpdate`) has no event to bind to.
- **hooks.json extras.** The `timeout` field on each entry is honored by builds that know it and ignored otherwise; the stop entry allows the full `CLAUDE_VERIFY_TIMEOUT` window.
- **Subagent models.** Agents ship with `model: inherit`; each role's prose still says when Sonnet is enough and when Opus is warranted.
