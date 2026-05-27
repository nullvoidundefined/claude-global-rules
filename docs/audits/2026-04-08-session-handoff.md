# Session handoff: 2026-04-08

**Scope:** `~/.claude` global rules repo. This session rewrote `CLAUDE.md` end-to-end and shipped the Phase 2+3 enforcement batch that closes the self-reinforcement loop.

## Last commit on main

- `4c19c28 feat(hooks+audits): ship Phase 2A + 2B + 2.5 + 3 batch`
- Previous: `c62dfd7 Rewrite CLAUDE.md following Security + Criticism + Engineering audits`
- Both on `main`, both pushed to the private `claude-global-rules` remote.

## State verified

- `jq . ~/.claude/settings.json` valid.
- `~/.claude/hooks/no-em-dash.sh` tested: hyphen passes, U+2014 blocks.
- `~/.claude/hooks/fix-commit-requires-test.sh` tested: `chore:` passes, `fix:` with no staged test blocks.
- `~/.claude/hooks/session-end.sh` tested with a temp `-test-project` memory fixture: fire and miss entries correctly routed to `rule_fires.md` / `rule_misses.md`, dedup verified, test entries cleaned up.
- `~/.claude/hooks/session-start.sh` tested: emits real INDEX content as additionalContext.
- Session-touched files em-dash clean: `CLAUDE.md`, 3 standing role files, 4 new hooks, 1 prompt snippet, `settings.json`.

## What shipped today

**CLAUDE.md rewrite (`c62dfd7`)**
- Cut from 866 lines / ~11K tokens to 459 lines / ~6K tokens.
- New Non-negotiable rules block at top (R-001 through R-007, golden-path voice).
- New Secrets / untrusted input / cross-session boundaries section (R-100 through R-109): prompt injection defense, secret protection, global memory client scrubbing, redaction, loop budgets, MCP trust, least privilege, push validation, hook drift.
- Standing audit roster cut from 8 to 3.
- Added "Keeping this file alive" with promotion ladder, retirement ladder, fire/miss logs, Last validated timestamps.
- Added R-305 (feed lessons back at session end) with `fired:` / `miss:` memory prefix convention.
- Golden-path reframing applied throughout.
- Glossary, TOC, rule IDs added.
- Audit reports (`security`, `criticism`, `engineering`), triage doc, and rewrite draft committed to `docs/audits/`.

**Phase 3 file moves (`4c19c28`)**
- `audits/{ux,design,marketing,financial,legal}.md` → `audits/on-request/`.
- Standing roster directory: `engineering.md`, `security.md`, `criticism.md`.

**Phase 2.5 role file tightening (`4c19c28`)**
- Replaced "Advisory autonomy" with "Authority and scope" on all three standing role files.
- Added explicit "Reporting, not acting" boundary: roles report, user decides.
- Added per-role "Allowed read scope" from R-107 (Security gets broadest scope including vendor CLI configs for credential scans; Engineering and Criticism excluded from `.env*`, `~/.aws/`, `~/.ssh/`, etc.).

**Phase 2A canary hooks (`4c19c28`)**
- `hooks/no-em-dash.sh` as `PreToolUse` on `Write|Edit|Bash`. File self-scan-safe (uses printf byte escapes in test examples).
- `hooks/session-end.sh` as `SessionEnd`. Scans per-project feedback memory for `fired:` / `miss:` prefix lines, routes to `global-memory/rule_fires.md` / `rule_misses.md` with dedup.

**Phase 2B follow-up hooks (`4c19c28`)**
- `hooks/fix-commit-requires-test.sh` as `PreToolUse` on `Bash`. Blocks `git commit -m` with `fix:` family prefix unless staged diff includes a test file. Editor-driven commits unaffected.
- `hooks/session-start.sh` as `SessionStart`. Emits `global-memory/INDEX.md`, the most recent project handoff doc (`docs/audits/*session-handoff*.md` or latest dated audit), and retirement candidates as additional context at session start.
- `prompts/subagent-branch-setup.md`: reusable snippet for R-303 worktree verification.

**settings.json wiring**
- `PreToolUse Bash`: secret-scan, no-em-dash, fix-commit-requires-test (in order).
- `PreToolUse Write|Edit`: no-em-dash.
- `SessionStart`: session-start.
- `SessionEnd`: session-end.
- Notification hook unchanged.

**Enforcement status section** in CLAUDE.md now documents which rules are shipped and which are deferred, so future sessions know the real state.

## Pending

### Deferred (documented in CLAUDE.md "Enforcement status")

- **Continuous retirement scan.** Needs scheduling infrastructure (cron or `superpowers:loop`). When shipped, writes `~/.claude/global-memory/retirement_candidates.md`; the existing `session-start.sh` already picks up that file automatically. Effort: ~1 hour once the scheduler choice is made.
- **Last validated auto-flag.** PreToolUse on CLAUDE.md edits that warns (not blocks) when any rule's date is older than 180 days. Deferred for low payoff until there are enough dated rules to justify the complexity. Effort: ~1 hour.
- **Canonical lefthook template for projects.** `~/.claude/templates/lefthook.yml` that every project can adopt for consistent pre-commit gates (secret-scan, no-em-dash, fix-commit-requires-test at the project layer). Projects currently derive their own. Effort: ~1 hour.
- **Phase 4 measurement.** Review `rule_fires.md` and `rule_misses.md` after 30 days of normal use, apply the retirement ladder from CLAUDE.md, prune rules with zero fires. Inherently deferred by elapsed time.

### Open questions and edge cases

- **`fix-commit-requires-test` cwd sensitivity.** The hook inspects `git diff --cached --name-only` in whatever cwd the Bash shell runs in. Usually that is the project repo where the commit is happening, but if a commit is attempted from a directory with unrelated staged state, the hook may produce confusing results. First real `fix:` commit will tell us whether this matters. Mitigation if it does: pass the target directory explicitly via the command, or use `git -C <path>`.
- **Editor-driven commits skip R-201 enforcement.** The fix-commit hook only matches `git commit -m`. `git commit` without `-m` (editor launches) is not inspected. Honor-system for those. Future enhancement: write a git `commit-msg` hook that runs at the git layer.
- **Pre-existing em dashes in convention files, plans, and one old memory file** (141 occurrences in 12 files). Not touched this session. These would block any future edit to those files under the new hook. P3 cleanup item: sweep them out next time one of those files is touched.
- **The no-em-dash hook does not check PostToolUse or files read from disk.** It only gates content being WRITTEN. A file already on disk with an em dash is not flagged until someone edits it. That is the right scope for the hook; the retirement logic and the Last validated auto-flag would cover the "file already exists" case but neither is shipped.

## Recommended next session

In order:

1. **Read this handoff and `docs/audits/2026-04-08-triage.md`** to confirm current state.
2. **Verify the hooks are actually active** by running a dry test: try to write a test file containing U+2014 via the Write tool and confirm it blocks, then try a `fix:` commit without a staged test and confirm it blocks. If either test passes when it should have blocked, the hooks are not wired correctly.
3. **Ship the canonical lefthook template.** Write `~/.claude/templates/lefthook.yml` with pre-commit entries for secret-scan, no-em-dash (grep for U+2014 in staged files), and fix-commit-requires-test (commit-msg hook). Add a README at `~/.claude/templates/README.md` explaining how a project adopts it. Effort: ~1 hour.
4. **Decide on the retirement scan scheduling mechanism.** Either install cron, or use `superpowers:loop`, or set up a GitHub Actions scheduled workflow that runs against a checkout of `claude-global-rules`. Write the scan script (`~/.claude/scripts/retirement-scan.sh`) that reads `rule_fires.md` and `rule_misses.md`, computes per-rule fire counts over the trailing 90 days, and writes `retirement_candidates.md`. Effort: ~1 hour after the scheduling decision.
5. **Ship the Last validated auto-flag** only if there is appetite for it. Effort: ~1 hour.
6. **Do not open a full audit sweep.** The current audit reports are dated 2026-04-08 and still accurate. Per the rewritten CLAUDE.md, audits are gated: only run if the schedule says due, a specific risk signal has surfaced, or a major feature shipped. None of those apply yet.

Files to read first in the next session:
- `~/.claude/CLAUDE.md`
- `~/.claude/docs/audits/2026-04-08-triage.md`
- `~/.claude/docs/audits/2026-04-08-session-handoff.md` (this file)
- `~/.claude/global-memory/rule_fires.md` and `rule_misses.md` (to see what, if anything, fired between sessions)

## Companion docs

- `~/.claude/CLAUDE.md`: the rewritten rules file (current canonical).
- `~/.claude/PROTOCOL.md`: the ten-layer operating framework (pre-existing; the rewrite now references it from the top).
- `~/.claude/docs/audits/2026-04-08-security.md`: CISO audit (18 findings, 5 P0).
- `~/.claude/docs/audits/2026-04-08-criticism.md`: Devil's Advocate audit (verdict "Significant, trending Fatal"; motivated most of the bloat cuts).
- `~/.claude/docs/audits/2026-04-08-engineering.md`: CTO audit (structural and enforcement gaps; motivated most of the hook work).
- `~/.claude/docs/audits/2026-04-08-triage.md`: consolidated triage across all three audits, with the Q1 through Q7 question queue and the phase plan.
- `~/.claude/docs/audits/2026-04-08-claude-md-rewrite-draft.md`: the pre-swap draft. Intentionally preserved for history; can be deleted if the draft is no longer useful.
- `~/.claude/audits/engineering.md`, `security.md`, `criticism.md`: the three standing role files, now with tightened authority framing.
- `~/.claude/audits/on-request/{ux,design,marketing,financial,legal}.md`: on-request role files.

## Workflow reminders for the next session

- **No em dashes.** The hook will now block them at Write, Edit, and Bash. If a Write call is rejected with a no-em-dash reason, substitute period, comma, semicolon, colon, parentheses, or line break and retry.
- **Fix commits require tests.** The hook will now block `git commit -m "fix: ..."` without a staged test file. Honest relabel to `docs:` or `chore:` is the escape path when no test is needed.
- **Read `global-memory/INDEX.md` at session start** is now automated via the SessionStart hook. It prints into your context automatically.
- **Feed lessons back at session end** per R-305. Write `fired: R-NNN <context>` or `miss: R-NNN <context>; gap: <what the rule needs>` into feedback memory as observations occur; the SessionEnd hook routes them automatically.
- **Standing audit roster is three.** Engineering, Security, Criticism. The on-request five live at `audits/on-request/` and are invoked only when a specific situation calls for them.
- **Subagent dispatch prompts for git work** should paste `~/.claude/prompts/subagent-branch-setup.md` by reference instead of rewriting the branch-verification block each time.
- **Project-level `CLAUDE.md`** files still take precedence over this global file for project-specific rules.

## TODO updates pending

None. The CLAUDE.md "Enforcement status" section is the single source of truth for deferred enforcement work. `ISSUES.md` does not exist at `~/.claude/` and does not need to; this repo is not a product.
