# Session Handoff: 2026-09-05 Cursor and Codex ports

## 1. Last commit

- `0fc3aed` feat(rules): R-351 Dockerize every deployable artifact (#15), on `main`. This session's work is on branch `claude/port-rules-to-cursor-9covs0` (two commits: `7d68a7b` the Cursor port, then the Codex port and the Cursor extension), not yet merged.

## 2. Production state

- `main` is green in CI through #15. Nothing on `main` is live in Ian's `~/.claude` until pulled; the post-pull steps from the 2026-09-05 audit handoff still apply (`npm ci --prefix enforce`, delete `~/.claude/.post-compact-pending`, `claude --version` 2.1.251 or later, activate the naming judge key).
- Both suites on this branch: 45 enforcement fixtures (43 plus `cursor-port.test.sh` and `openai-port.test.sh`), 12 hook fixtures, all green. `enforce/hook-hashes.txt` regenerated; it now covers `enforce/*.sh` and both adapters with their `hooks.json`.

## 3. What shipped

- **Three folders, one per agent.** The repository root stays the Claude Code configuration (it is `~/.claude`; moving it would break every hook path, `settings.json`, the tests, and CI). `cursor/` and `openai/` are generated from it by `cursor/build.mjs` and `openai/build.mjs`, which share `enforce/portBuild.mjs` (loaders, substitution primitive with must-exist needles, skill overrides, session command bodies, the --check/--write driver).
- **`cursor/`** (62 generated files): 25 `.mdc` rules, 10 subagents, 12 commands, all 13 skills, `PORT-STATUS.md`. `hooks.json` wires 9 Cursor events through `hooks/claude-hook-adapter.sh`: 38 of 42 hooks, the `Bash(...)` deny/ask rules, the `Read(...)` deny rules. Edit gates defer to `stop` (`followup_message`) where Cursor has no pre-edit event, and also run on `preToolUse` (payload shape unverified; adapter acts only on edit-shaped payloads).
- **`openai/`** (39 generated files) for Codex: `AGENTS.md` (CLAUDE.md plus the session-types table, 16.7 KB of the 24 KB share the build enforces against Codex's 32 KiB `project_doc_max_bytes`), `hooks.json` generated from `settings.json` (Codex uses Claude Code's hook schema verbatim: same events, matchers, stdin, and stdout), 25 skills (the 13, plus `session-start`, `session-handoff`, and one dispatcher per agent, since Codex's slash menu is its skill list), 10 custom agent roles as TOML (`name`, `description`, `developer_instructions`), `PORT-STATUS.md`. `hooks/codex-hook-adapter.sh` replays each `apply_patch` (Codex sends the whole patch as `tool_input.command`) as per-file Write/Edit payloads so the edit gates block before the edit lands, translates `ask` (which Codex rejects) per `CLAUDE_CODEX_ASK_POLICY` (deny by default, allow-with-context optional), and mirrors the `Bash(...)` permission rules. 39 of 42 hooks port; `post-compact-rules` ports through `SessionStart` with the `compact` matcher.
- **Shared shell helper** `enforce/settingsPermissionRules.sh` evaluates the settings.json permission rules for both adapters.
- **Docs.** README layout and a "Using the same rules from Cursor and OpenAI Codex" section; SETUP "Cursor and OpenAI Codex"; `cursor/README.md` and `openai/README.md` with layer maps, fidelity tables, and caveats.

## 4. Pending

**Ian's next steps, in order:**

1. Merge the branch, pull, then `bash ~/.claude/cursor/install.sh` and `bash ~/.claude/openai/install.sh`. The Codex installer refuses to replace an existing `~/.codex/AGENTS.md`; move it aside first if you have one.
2. Cursor: restart, check Settings > Rules and Settings > Hooks (9 events). If Rules is empty, `install.sh --project <repo>`. Run `/session-start` in the first session; try `git commit -m "x"` with an em dash and confirm the deny.
3. Codex: start a session, `/hooks` to trust the entries (per content hash; re-trust after every hook change), `/skills` to see 25 skills. Try the same em-dash commit. Try an edit that adds an em dash and confirm the `apply_patch` denial.
4. Decide the ask policy for Codex: the default denies anything Claude Code would ask about (force-push, `sudo`, MCP writes, destructive SQL); `CLAUDE_CODEX_ASK_POLICY=allow` in Codex's environment turns those into context notes instead.
5. If either tool misfires after an update: `CLAUDE_CURSOR_HOOK_DEBUG=1` / `CLAUDE_CODEX_HOOK_DEBUG=1` and read `~/.claude/.cursor-hook-state/debug.log` / `~/.claude/.codex-hook-state/debug.log`.
6. The earlier handoff's steps (judge key activation, `/status` checks, first-backend-repo ratchet baseline) are unchanged.

**Facts to verify on first use, because the build session could not reach cursor.com or developers.openai.com** (the cloud sandbox's egress policy allowed GitHub and npm but not those domains; Codex facts were read from the `openai/codex` source, Cursor facts from mirrors and the typed `cursor-hooks` helper): Cursor's `preToolUse` payload field names and whether `~/.cursor/rules` is read; Codex's MCP `tool_name` format for the `mcp__.*` matcher, and whether its compaction emits `SessionStart` with source `compact`.

**Still open from earlier:** stale merged remote branches; the five deny-tier git guards spawning on every Bash call; the `.env` deny list enumerating variants.

## 5. Next-session tasks, with files to read

- **After any rule, hook, skill, or agent edit,** run both builds with `--write` and commit the ports; both port tests fail otherwise. A hook added to `settings.json` needs either a `cursor/hooks.json` entry or a `NOT_PORTED` reason in `cursor/build.mjs`; the Codex port derives its `hooks.json` from `settings.json` automatically and only needs a `NOT_PORTED` reason for an event Codex lacks.
- **Editing an adapter, `enforce/*.sh`, or either `hooks.json`:** regenerate `enforce/hook-hashes.txt` (`hooks/hook-integrity-check.sh --update`); under Codex, re-trust in `/hooks`.
- **If Cursor rejects a rule description,** `cleanDescription` in `cursor/build.mjs` strips colons and quotes; widen it there. **If `AGENTS.md` outgrows 24 KB,** trim CLAUDE.md or raise `project_doc_max_bytes` in `~/.codex/config.toml` and the budget constant together.
