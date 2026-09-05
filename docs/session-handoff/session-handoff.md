# Session Handoff: 2026-09-05 Cursor and Codex ports as sibling directories

## 1. Last commit

- `0fc3aed` feat(rules): R-351 Dockerize every deployable artifact (#15), on `main`. This session's work is on branch `claude/port-rules-to-cursor-9covs0` (four commits: the Cursor port, the Codex port, R-210, then the move to sibling directories), not yet merged.

## 2. Production state

- `main` is green in CI through #15. Nothing on `main` is live in Ian's `~/.claude` until pulled; the post-pull steps from the 2026-09-05 audit handoff still apply (`npm ci --prefix enforce`, delete `~/.claude/.post-compact-pending`, `claude --version` 2.1.251 or later, activate the naming judge key).
- Both suites on this branch: 45 enforcement fixtures (43 plus `cursor-port.test.sh` and `openai-port.test.sh`), 12 hook fixtures, all green. `enforce/hook-hashes.txt` regenerated; it covers `enforce/*.sh` and both adapter sources with `cursor/hooks.json`.

## 3. What shipped

- **Sibling repositories.** Each build now also writes a generated `README.md` (what the directory is, the two-line rebuild-and-push) and an allowlist `.gitignore` (only built files tracked) into its target, so `~/.cursor` and `~/.codex` can be clones of `cursor-global-rules` and `openai-global-rules`. The repositories themselves still need creating (see step 1).
- **Three sibling directories, one per agent.** `~/.claude` (this repository) is the single source. `node cursor/build.mjs --write` builds `~/.cursor`; `node openai/build.mjs --write` builds `~/.codex`. Nothing generated is tracked here: `cursor/` holds `build.mjs`, `hooks.json` (the wiring source, adapter path as a `{{adapter}}` placeholder), and `hooks/claude-hook-adapter.sh`; `openai/` holds `build.mjs` and `hooks/codex-hook-adapter.sh`. The shared driver in `enforce/portBuild.mjs` writes a `.claude-port.json` manifest into the target, refuses to overwrite files it did not write (`--force` overrides), removes only its own stale files, and `--check` reports drift. `--out <dir>` targets any directory (the tests use it); `--project <repo>` builds Cursor's tree into `<repo>/.cursor` with repo-relative adapter commands.
- **`~/.cursor`** (64 files): 25 `.mdc` rules, 10 subagents, 12 commands, 13 skills, `hooks.json` wiring 9 events through the adapter (38 of 42 hooks, the `Bash(...)` deny/ask rules, the `Read(...)` deny rules), `PORT-STATUS.md`. Edit gates defer to `stop` (`followup_message`) where Cursor has no pre-edit event and also run on `preToolUse` for edit-shaped payloads.
- **`~/.codex`** (40 files): `AGENTS.md` (CLAUDE.md plus session types, 16.7 KB of a 24 KB share of Codex's 32 KiB `project_doc_max_bytes`), `hooks.json` generated from `settings.json` (Codex uses Claude Code's hook schema verbatim), 25 skills (13 plus `session-start`, `session-handoff`, one dispatcher per agent), 10 TOML agent roles, `PORT-STATUS.md`. The adapter replays each `apply_patch` as per-file Write/Edit payloads so edit gates block before the edit lands, translates `ask` (which Codex rejects) per `CLAUDE_CODEX_ASK_POLICY` (deny default), and mirrors the `Bash(...)` rules. 39 of 42 hooks port.
- **Adapters** resolve the Claude Code home through `CLAUDE_HOME` (default `~/.claude`), so the copies in `~/.cursor/hooks/` and `~/.codex/hooks/` find `hooks/` and `enforce/settingsPermissionRules.sh`, and the tests can point them at a checkout elsewhere.
- **R-210** (explain every technical term on first use), with Spec, a correction memory, post-compaction re-injection, and both ports carrying it.
- **Docs.** README layout and "Using the same rules from Cursor and OpenAI Codex"; SETUP "Cursor and OpenAI Codex"; `cursor/README.md` and `openai/README.md` (build, layer maps, fidelity tables, caveats).

## 4. Pending

**Ian's next steps, in order:**

1. Merge the branch and pull. Create the two sibling repositories, `cursor-global-rules` and `openai-global-rules`, on GitHub (the session's GitHub App token cannot create repositories: 403 "Resource not accessible by integration"), then run the first-time block in SETUP.md "Cursor and OpenAI Codex": it builds `~/.cursor` and `~/.codex`, initialises each as a clone, and pushes the first build. The Codex build refuses to replace an existing `~/.codex/AGENTS.md`; move it aside first or pass `--force`. Each build writes an allowlist `.gitignore` and a generated `README.md` into its target, so `auth.json`, `config.toml`, sessions, and Cursor's own state never reach the repositories.
2. Cursor: restart, check Settings > Rules and Settings > Hooks (9 events). If Rules is empty, `--project <repo>`. Run `/session-start` in the first session; try `git commit -m "x"` with an em dash and confirm the deny.
3. Codex: start a session, `/hooks` to trust the entries (per content hash; re-trust after every rebuild that changes the adapter or hooks.json), `/skills` to see 25 skills. Try the same em-dash commit and an edit that adds an em dash.
4. Decide the Codex ask policy: the default denies anything Claude Code would ask about (force-push, `sudo`, MCP writes, destructive SQL); `CLAUDE_CODEX_ASK_POLICY=allow` in Codex's environment turns those into context notes.
5. If either tool misfires after an update: `CLAUDE_CURSOR_HOOK_DEBUG=1` / `CLAUDE_CODEX_HOOK_DEBUG=1`, then read `~/.claude/.cursor-hook-state/debug.log` / `~/.claude/.codex-hook-state/debug.log`.
6. To let a future build session read the primary docs, add `cursor.com` and `developers.openai.com` to the environment's network policy (claude.ai/code > Environments); it applies to new sessions.
7. The earlier handoff's steps (judge key activation, `/status` checks, first-backend-repo ratchet baseline) are unchanged.

**Facts to verify on first use, because the build session could not reach cursor.com or developers.openai.com** (the cloud sandbox's egress policy allowed GitHub and npm but not those domains; Codex facts were read from the `openai/codex` source, Cursor facts from mirrors and the typed `cursor-hooks` helper): Cursor's `preToolUse` payload field names and whether `~/.cursor/rules` is read; Codex's MCP `tool_name` format for the `mcp__.*` matcher, and whether its compaction emits `SessionStart` with source `compact`.

**Still open from earlier:** stale merged remote branches; the five deny-tier git guards spawning on every Bash call; the `.env` deny list enumerating variants.

## 5. Next-session tasks, with files to read

- **After any rule, hook, skill, or agent edit,** re-run both builds on the machine that uses them; the repo itself carries no generated output, so nothing to commit for the ports unless a generator changed. A hook added to `settings.json` needs a `cursor/hooks.json` entry or a `NOT_PORTED` reason in `cursor/build.mjs`; the Codex build needs a `NOT_PORTED` reason only for an event Codex lacks.
- **Editing an adapter, `enforce/*.sh`, or `cursor/hooks.json`:** regenerate `enforce/hook-hashes.txt` (`hooks/hook-integrity-check.sh --update`); rebuild both targets; re-trust in Codex's `/hooks`.
- **If Cursor rejects a rule description,** `cleanDescription` in `cursor/build.mjs` strips colons and quotes; widen it there. **If `AGENTS.md` outgrows 24 KB,** trim CLAUDE.md or raise `project_doc_max_bytes` in `~/.codex/config.toml` and the budget constant together.
