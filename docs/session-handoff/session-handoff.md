# Session Handoff: 2026-09-05 Cursor port

## 1. Last commit

- `0fc3aed` feat(rules): R-351 Dockerize every deployable artifact (#15), on `main`. This session's work is on branch `claude/port-rules-to-cursor-9covs0` (one commit, `feat(cursor): ...`), not yet merged.

## 2. Production state

- `main` is green in CI through #15. Nothing on `main` is live in Ian's `~/.claude` until pulled; the post-pull steps from the previous handoff still apply (`npm ci --prefix enforce`, delete `~/.claude/.post-compact-pending`, `claude --version` 2.1.251 or later, activate the naming judge key).
- Both suites on this branch: 44 enforcement fixtures (43 plus `cursor-port.test.sh`), 12 hook fixtures, all green. `enforce/hook-hashes.txt` regenerated (64 entries; now covers `cursor/hooks/*.sh` and `cursor/hooks.json`).

## 3. What shipped

- **`cursor/`, the Cursor port.** `build.mjs` renders 50 files from the canonical sources: 25 `.mdc` rules (3 always-on: global rules, session types, memory index; 9 glob-attached from the `paths:` frontmatter of the stack files; 13 agent-requested: one per `rulebook/reference.md` block, the three Tier 2 files, structure-conventions, cloud-deployment), 10 subagents, 12 commands (`session-start`, `session-handoff`, one dispatcher per agent), 2 skill overrides (`protocol`, `known-issues`, whose bodies use the shell-include syntax), and `PORT-STATUS.md`. Every Claude-specific sentence goes through a substitution whose needle must exist, so a source edit that moves one fails the build rather than emitting stale text. Skills otherwise load from `~/.claude/skills/` directly (Cursor reads it as a legacy global skills dir).
- **`cursor/hooks/claude-hook-adapter.sh` + `hooks.json`.** One adapter translates 8 Cursor events into the Claude Code hook payloads and runs the existing `hooks/*.sh` unchanged: 38 of 42 hooks port. It also mirrors the `settings.json` `Bash(...)` deny/ask rules on `beforeShellExecution` and the `Read(...)` deny rules on `beforeReadFile`. Cursor has no pre-edit event, so the edit gates run after the edit and their would-be denials are deferred to the `stop` hook as a `followup_message` (consumed once; an identical followup on the next stop is suppressed once, so a red suite cannot loop).
- **`cursor/install.sh`** symlinks `~/.cursor/{rules,hooks.json,agents,commands,skills}` into the port; refuses to clobber what it did not create; `--uninstall`; `--project <repo>` copies rules and hooks.json into a repo's `.cursor/`.
- **Tests and docs.** `enforce/tests/cursor-port.test.sh` (build freshness, port shape, 20 adapter decisions). README layout and a "Using the same rules from Cursor" section; SETUP "Cursor" section; `cursor/README.md` (install, layer map, per-event fidelity, caveats); `.gitignore` for `.cursor-hook-state/`.

## 4. Pending

**Ian's next steps, in order:**

1. Merge the branch, pull, then `bash ~/.claude/cursor/install.sh` and restart Cursor.
2. Verify in Cursor: Settings > Rules lists the `.mdc` files; Settings > Hooks lists 8 events. If Rules is empty, this build does not read `~/.cursor/rules`; use `install.sh --project <repo>` (the global rules dir is widely reported but not in Cursor's primary docs).
3. First Cursor session: run `/session-start` (the `sessionStart` hook's `additional_context` has open bug reports about not reaching the agent), then try `git commit -m "x"` with an em dash and confirm the deny message appears.
4. If any hook misfires after a Cursor update, set `CLAUDE_CURSOR_HOOK_DEBUG=1` in Cursor's environment and read `~/.claude/.cursor-hook-state/debug.log`: the payload field names are the only thing the adapter assumes. Facts were taken from Cursor's docs mirrors and the typed `cursor-hooks` helper because cursor.com was unreachable from the build session; `afterShellExecution` output is documented as ignored, `stop`/`followup_message` and `sessionStart`/`additional_context` as honored.
5. The previous handoff's steps 1 to 6 (judge key activation, `/status` checks, first-backend-repo ratchet baseline) are unchanged.

**Still open from earlier:** stale merged remote branches; the five deny-tier git guards spawning on every Bash call; the `.env` deny list enumerating variants.

**Not implemented by choice:** `preToolUse`/`postToolUse` (generic Cursor events added after 1.7) are not wired because their payload shape could not be verified; if they mirror Claude Code's, the edit gates could block pre-edit through them instead of deferring. `post-compact-rules`, `task-commit-reminder`, `settings-change-guard`, `model-switch-guard`, and the Notification half of `ntfy-notify` have no Cursor event (`cursor/PORT-STATUS.md`).

## 5. Next-session tasks, with files to read

- **After any rule edit,** `node cursor/build.mjs --write` and commit `cursor/` with it; `cursor-port.test.sh` fails otherwise. Adding a hook to `settings.json` needs either a `cursor/hooks.json` entry or a `NOT_PORTED` reason in `cursor/build.mjs`, or the build fails.
- **Editing the adapter or hooks.json:** regenerate `enforce/hook-hashes.txt` (`hooks/hook-integrity-check.sh --update`).
- **If Cursor's rules parser rejects a description,** `cleanDescription` in `build.mjs` already strips colons and quotes; widen it there.
