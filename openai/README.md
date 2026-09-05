# OpenAI Codex port

The same rules, gates, skills, audit roles, and session procedures as the Claude Code configuration, in the shapes OpenAI Codex reads, built into `~/.codex`, the directory Codex reads beside `~/.claude`. Codex is the CLI, the IDE extension, and the cloud agent that ChatGPT delegates to; all three load `~/.codex/AGENTS.md`, `~/.codex/skills/`, `~/.codex/agents/`, and `~/.codex/hooks.json`. ChatGPT's chat interface itself reads no files.

This folder holds only the generators: the build script and the adapter script. Nothing generated is tracked here; `enforce/tests/openai-port.test.sh` builds the port into a temporary directory and checks its shape and every adapter decision.

## Build

```
node ~/.claude/openai/build.mjs --write
```

That writes `~/.codex/AGENTS.md`, `~/.codex/hooks.json`, `~/.codex/hooks/codex-hook-adapter.sh`, `~/.codex/skills`, `~/.codex/agents`, and `~/.codex/PORT-STATUS.md`, and records what it wrote in `~/.codex/.claude-port.json`. It refuses to overwrite a file it did not write (an existing `~/.codex/AGENTS.md` is the usual case: move it aside, or pass `--force`), removes only its own stale files on the next run, and leaves everything else in `~/.codex` alone, including `config.toml`. Re-run after every pull of `~/.claude`; `--check` says whether `~/.codex` is behind the sources. Then, in a Codex session, `/hooks` lists the hook entries for you to trust (Codex trusts hooks by content hash, so every change to a hook script or to `hooks.json` needs a fresh trust) and `/skills` shows the skills. The repository has to live at `~/.claude`: `AGENTS.md` points at `~/.claude/...` for every on-demand read and the adapter runs the hooks from `~/.claude/hooks/`.

## Repository

`~/.codex` is a clone of [`openai-global-rules`](https://github.com/nullvoidundefined/openai-global-rules), the way `~/.claude` is a clone of `claude-global-rules`. The build writes into the clone; a rebuild is committed and pushed there (the generated `README.md` in the target carries the two commands). The generated `.gitignore` is an allowlist of the built files, so the state the tool keeps in the same directory never reaches the repository. SETUP.md in `~/.claude` has the one-time clone steps for a directory that already exists.

## After a rule change

Run the build again. Each Claude Code-specific sentence is rewritten through a substitution whose needle must still exist in the source, so a source edit that moves it fails the build rather than emitting stale prose. `AGENTS.md` is size-checked: Codex loads every AGENTS.md in one 32 KiB budget (`project_doc_max_bytes`), so the global file stays under 24 KiB to leave room for project files. `hooks.json` is derived from `settings.json`, so a new hook there needs only a `NOT_PORTED` reason in `build.mjs` when it belongs to an event Codex lacks.

## What each layer becomes

| Claude Code | Codex (under `~/.codex`) | Notes |
|---|---|---|
| `CLAUDE.md` | `AGENTS.md` | Always loaded. R-001 rewritten for Codex's session start; task-tool references generalised; every `[hook:X]` tag with no Codex event annotated `in Claude Code; manual in Codex` |
| `rules/session-types.md` | the `## Session types` section of `AGENTS.md` | Codex has no path-scoped loading, so the stack table is how the agent finds the convention file for the surface it is editing |
| `global-memory/INDEX.md` | injected by the `SessionStart` hook | Same mechanism as Claude Code; `AGENTS.md` says to Read it when the block is absent |
| `CLAUDE-*.md` (path-scoped) | read on demand from `~/.claude/` | No auto-attach; the stack table names the file |
| `rulebook/*.md`, `CLOUD-DEPLOYMENT.md` | read on demand from `~/.claude/` | Same as Claude Code |
| `skills/*` | `skills/<name>/SKILL.md` | Same SKILL.md standard; the two shell-include skills get bodies Codex can use |
| slash commands | skills | Codex's slash menu is its skill list, so `session-start`, `session-handoff`, and one dispatcher per agent ship as skills |
| `agents/*.md` | `agents/<name>.toml` | Codex custom agent roles: `name`, `description`, and the role body as `developer_instructions`; the model spawns them by name |
| `settings.json` hooks | `hooks.json` + `hooks/codex-hook-adapter.sh` | Generated from `settings.json`: same schema, same events, same matchers. `PORT-STATUS.md` in the target lists every hook and the three that have no Codex event |
| `settings.json` permissions | the adapter | `Bash(...)` deny and ask rules mirrored on `PreToolUse`; `Read(...)` rules have no read event to bind to |

## How the hooks run

Codex implemented its hooks on Claude Code's protocol: `hooks.json` has the same shape, `PreToolUse` sees `tool_name`, `tool_input`, and `cwd`, a hook denies with `hookSpecificOutput.permissionDecision`, and `Stop` blocks with `decision: block`. So `~/.codex/hooks.json` is `settings.json`'s hook block with three edits, and `hooks/codex-hook-adapter.sh` is the only Codex-specific script; it runs the hooks from `~/.claude/hooks/`, which stay untouched.

| Difference | What the adapter does |
|---|---|
| File edits arrive as one `apply_patch` call whose `tool_input.command` is the whole patch | Parses the patch and replays each file as the `Write` (Add File) or `Edit` (Update File) payload the edit gates and reminders read, so R-207, R-103, R-302, R-401, R-405, the structure rules, and the reminders all fire per file, before the edit lands |
| Codex rejects a hook answer of `ask` | `CLAUDE_CODEX_ASK_POLICY=deny` (default): the call is denied with the hook's reason and a note that the user runs it after confirming. `allow`: the call proceeds and the reason is injected as context telling the model to confirm first. Affects `destructive-db-guard`, `destructive-command-guard`, `git-workflow-guard`, `mcp-action-guard`, `llm-rule-judge`, and the `Bash(...)` ask rules |
| Codex does not read `settings.json` | The `Bash(...)` deny and ask rules are evaluated on `PreToolUse` Bash |
| `if`-gated groups and the `TaskUpdate`, `Notification`, `ConfigChange`, `PreModelSwitch` events | Dropped: Codex has no `if`, and those events do not exist there. `SessionStart` with the `compact` matcher does exist, so the post-compaction rule re-injection ports |
| `SessionEnd` handlers are capped at three seconds | The generated entry uses that cap; `session-end.sh` normally finishes well inside it |

Debug a mismatch with `CLAUDE_CODEX_HOOK_DEBUG=1` in Codex's environment: every payload and every hook's output lands in `~/.claude/.codex-hook-state/debug.log`.

## Caveats

- **Asks become denials by default.** The confirmation prompts Claude Code shows cannot be reproduced from a Codex hook. Read the deny message, confirm with the user, and let them run the command, or set the policy to `allow` and rely on the injected context. R-101 and R-105 are the rules behind the default.
- **Trust is per hash.** Every change to a hook script, the adapter, or `hooks.json` shows up in `/hooks` as untrusted and is skipped until you trust it again. That is Codex's protection against a tampered hook, the same threat `hook-integrity-check.sh` covers.
- **MCP matcher.** `settings.json` matches MCP tools on `mcp__.*`; Codex reports MCP tools under its own naming, which this port could not verify from a live session. If `/hooks` shows the MCP group never firing, the debug log will show the actual `tool_name` to match on.
- **No compaction re-injection guarantee.** `post-compact-rules` ports through `SessionStart` with the `compact` source; whether Codex emits that source on its own compaction is documented in its hooks reference, not verified here.
- **Codex facts came from source, not a live install.** Event names, payload fields, the `apply_patch` shape, the `ask` rejection, the 32 KiB budget, and the skills and agents directories were read from the `openai/codex` repository because the docs sites were unreachable from the session that built this port. The first Codex session should confirm each with the debug log.
