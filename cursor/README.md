# Cursor port

The same rules, gates, audit roles, skills, and session procedures as the Claude Code configuration, in the shapes Cursor reads, built into `~/.cursor`, the directory Cursor reads beside `~/.claude`. This folder holds only the generators: the build script, the hook wiring it copies, and the adapter script. Nothing generated is tracked here; `enforce/tests/cursor-port.test.sh` builds the port into a temporary directory and checks its shape and every adapter decision.

## Build

```
node ~/.claude/cursor/build.mjs --write
```

That writes `~/.cursor/rules`, `~/.cursor/hooks.json`, `~/.cursor/hooks/claude-hook-adapter.sh`, `~/.cursor/agents`, `~/.cursor/commands`, `~/.cursor/skills`, and `~/.cursor/PORT-STATUS.md`, and records what it wrote in `~/.cursor/.claude-port.json`. It refuses to overwrite a file it did not write (move the file aside or pass `--force`), removes only its own stale files on the next run, and leaves everything else in `~/.cursor` alone. Re-run after every pull of `~/.claude`; `--check` says whether `~/.cursor` is behind the sources. Restart Cursor afterwards; check Settings > Rules for the `.mdc` rules and Settings > Hooks for the nine events.

If this Cursor build does not read a user-level rules directory, build into a project instead:

```
node ~/.claude/cursor/build.mjs --write --project ~/code/some-repo
```

which writes the same tree into `<repo>/.cursor/` with the adapter command made repo-relative. Either way the repository has to live at `~/.claude`: the rule bodies point at `~/.claude/...` for their on-demand reads, and the adapter runs the hooks from `~/.claude/hooks/`.

## Repository

`~/.cursor` is a clone of [`cursor-global-rules`](https://github.com/nullvoidundefined/cursor-global-rules), the way `~/.claude` is a clone of `claude-global-rules`. The build writes into the clone; a rebuild is committed and pushed there (the generated `README.md` in the target carries the two commands). The generated `.gitignore` is an allowlist of the built files, so the state the tool keeps in the same directory never reaches the repository. SETUP.md in `~/.claude` has the one-time clone steps for a directory that already exists.

## After a rule change

Run the build again. Each Claude Code-specific sentence is rewritten through an explicit substitution whose needle must still exist in the source, so an edit to CLAUDE.md that moves one of those sentences fails the build with the needle it could not find, rather than emitting stale prose. Adding a hook to `settings.json` needs either a `cursor/hooks.json` entry or a `NOT_PORTED` reason in `build.mjs`, or the build fails.

## What each layer becomes

| Claude Code | Cursor (under `~/.cursor`) | Notes |
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
| `skills/*` | `skills/<name>/SKILL.md` | Same SKILL.md standard, all thirteen; the two whose bodies use Claude Code's shell-include syntax (`/protocol`, `/known-issues`) get bodies Cursor can use |
| `settings.json` hooks | `hooks.json` + `hooks/claude-hook-adapter.sh` | 38 of 42 hooks; `PORT-STATUS.md` in the target lists every hook and the four that have no Cursor event |
| `settings.json` permissions | the adapter | `Bash(...)` deny and ask rules mirrored on `beforeShellExecution`; `Read(...)` deny rules mirrored on `beforeReadFile` |

## How the hooks run

Cursor and Claude Code both run hook scripts with JSON on stdin and JSON on stdout, but the event names, payload fields, and response fields differ. `hooks/claude-hook-adapter.sh` is the one Cursor-specific script: `hooks.json` calls it with the Cursor event name and the list of Claude Code hooks to run, it builds the payload those hooks expect, runs them from `~/.claude/hooks/` in order, and translates the strongest decision back. The hook scripts stay untouched, so a fix there reaches both tools. `hooks/hook-integrity-check.sh` covers the adapter source and `hooks.json` here the same way it covers the hooks; the copies in `~/.cursor` are compared to these sources by `--check`.

| Cursor event | Claude Code hooks it runs | Fidelity |
|---|---|---|
| `beforeShellExecution` | the 18 PreToolUse Bash gates, plus the `Bash(...)` permission rules | Full: `deny` and `ask` block before the command runs, with the hook's reason as `user_message` and `agent_message` |
| `beforeMCPExecution` | `mcp-action-guard`, `destructive-db-guard` | Full. Cursor reports a bare tool name, so the adapter prefixes `mcp__cursor__` to match the guards' naming |
| `beforeReadFile` | the `Read(...)` deny rules | Full: `.env*`, `~/.aws`, `~/.ssh`, `~/.gnupg`, gh hosts.yml, `~/.netrc` stay off-path (R-102) |
| `preToolUse` | the 5 PreToolUse Write/Edit gates | Best effort: this event arrived after Cursor 1.7 and its payload is not pinned down in any source available when this was written, so the adapter acts only on a payload that carries a file path and new content, and answers allow otherwise. Where it works, the edit gates deny before the edit lands and nothing is deferred |
| `afterFileEdit` | the 5 PreToolUse and 6 PostToolUse Write/Edit hooks | Partial: with no pre-edit event, a gate that would have denied the edit cannot. Its finding is written to a per-conversation file and the `stop` hook returns it as `followup_message`, which Cursor submits as the next turn, so the agent is told to repair the edit before the turn stands. The advisory reminders travel the same way |
| `afterShellExecution` | `redact-output` | Detection only, as in Claude Code, and Cursor currently ignores this event's output; the warning is deferred to `stop` as above |
| `sessionStart` | `session-start` and the five integrity and guard checks | Emits `additional_context`; see Caveats |
| `stop` | `verification-gate`, `ntfy-notify`, plus the deferred findings | A red suite becomes a `followup_message`. An identical followup on the very next stop is suppressed once, so a suite the agent cannot fix does not loop the conversation |
| `sessionEnd` | `session-end` | Full |

Debug a payload mismatch after a Cursor update with `CLAUDE_CURSOR_HOOK_DEBUG=1` in Cursor's environment: every raw payload and every hook's output lands in `~/.claude/.cursor-hook-state/debug.log`.

## Caveats

- **Global rules directory.** Cursor documents User Rules as a plain-text setting; reading `.mdc` files from `~/.cursor/rules` is widely reported to work but is not in the primary docs. If Settings > Rules shows nothing after the build, use `--project`.
- **sessionStart context.** Bug reports against recent Cursor builds say `additional_context` from `sessionStart` does not always reach the agent. The three always-on rules carry the same content, and the `/session-start` command runs the R-001 procedure by hand.
- **Edits may land before the gates see them.** On builds where `preToolUse` does not fire for edits, R-207 (em dash), R-103 (credential paths), R-302, R-401, R-405 (content gate), and the structure rules are enforced after the fact through the stop hook rather than blocked at the tool call. The commit-time gates (`beforeShellExecution`) still block a commit that carries a violation.
- **No compaction hook.** `post-compact-rules` has no equivalent; Cursor manages its own summarisation.
- **Task tools.** R-502 and R-504 refer to Cursor's task list; `task-commit-reminder` (which fires on Claude Code's `TaskUpdate`) has no event to bind to.
- **hooks.json extras.** The `timeout` field on each entry is honored by builds that know it and ignored otherwise; the stop entry allows the full `CLAUDE_VERIFY_TIMEOUT` window.
- **Subagent models.** Agents ship with `model: inherit`; each role's prose still says when Sonnet is enough and when Opus is warranted.
