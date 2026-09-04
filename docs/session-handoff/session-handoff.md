# Session Handoff: 2026-09-04 Configuration Audit (follow-up)

## 1. Last commit

- `c2dd7c5` docs(session-handoff): close the /feature-cleanup item and record the e2e flake (#8), on `main`.
- This session's work is on `claude/config-audit-8m7s5k`: the audit report, the ISSUES.md rows, and this handoff, in one commit. No PR opened; none was asked for.

## 2. Production state

- Unchanged. The session was read-only against the config: no hook, rule, or settings change shipped. Both fixture suites green on a fresh install in the remote container (38 enforcement, 12 hook); `hook-integrity-check.sh` silent.
- The remote container cannot see the maintainer's `~/.claude` runtime (plugins, `projects/`, plan type, CLI version), so every "to confirm" in the report that names `/context`, `/status`, `/doctor`, `/skill-doctor`, or `claude --version` is a local check.

## 3. What shipped

**`docs/audits/2026-09-04-config.md`.** Audit of the config against the Anthropic docs fetched today, the Claude Code changelog 2.1.160 to 2.1.261, the npm and PyPI registries, the Actions runtimes, the live plugin marketplace manifest, and community reports (confidence marked per claim). Four P1s, nine P2s, six P3s, and a probed-and-cleared list. The P2s and P3s are in `ISSUES.md`.

The P1s, in one line each:
- `session-end.sh` has no `timeout`; the docs now give `SessionEnd` a shared 1.5-second budget. The R-603 rollup can be killed silently on any machine with a populated `projects/` tree.
- Post-compaction re-injection uses a global sentinel file and a `UserPromptSubmit` hook; the docs provide `SessionStart` with `matcher: compact`, and everything `session-start.sh` injects is summarized away at compaction. The hand-copied rule list in `post-compact-rules.sh` has drifted from `CLAUDE.md`.
- `settings.json` starts on `opus[1m]` while the HARD RULE memory, R-903, and the post-compaction list say Sonnet. Sonnet 5 is native 1M; `opusplan` exists.
- The secret read side is still honor-system; the docs ship `Read(...)` deny rules that also cover `cat`, `head`, `tail`, `sed` in Bash.

## 4. Pending

**Decisions only the maintainer can make (each is one line in a file):**
- P1-3: Sonnet, `opusplan`, or Opus, recorded in whichever artifact loses.
- P2-1: `permissions.defaultMode`, explicit.
- P2-9: keep or drop the `code-review` and `code-simplifier` plugins once `/skill-doctor` reports what they cost.

**Time-boxed by an external date:**
- P2-3: `actions/checkout@v4` and `actions/setup-node@v4` run on `node20`, removed from hosted runners 2026-09-23. Nineteen days from the audit.

**Mechanical, fixture-covered, safe to do in one sitting:**
- P1-1 `timeout` on the `SessionEnd` entry; P1-2 `compact` matcher and sentinel removal (update `post-compact-rules.test.sh`, `hook-hashes.txt`); P1-4 `Read` deny rules; P2-2 allow-list collapse; P2-4 ESLint 10 and `import-x`; P2-7 derive the latency chain from `settings.json`; P3-4 and P3-5 wording.

**Still open from earlier sessions:** branch protection naming `fixtures` as required; deleting merged remote branches; the judge keychain step (now P2-6, with the `agent`-hook alternative written up).

## 5. Next-session tasks, with files to read

- **Start with P1-1 and P1-2** (`settings.json`, `hooks/session-end.sh`, `hooks/pre-compact.sh`, `hooks/post-compact-rules.sh`, `hooks/session-start.sh`, `hooks/tests/post-compact-rules.test.sh`). Read the report's "to confirm" lines first; the compaction one needs a `/compact` in a throwaway session and `/context` afterwards before deciding whether `post-compact-rules.sh` survives at all.
- **Then P2-3 before 2026-09-23** (`.github/workflows/enforce.yml`): both actions to v7, ruff to current, `permissions:` block, `dependabot.yml`.
- **Do not hand-edit the R-316 verb bullets** in `rulebook/reference.md`; they are generated from `enforce/lexicon.json`.
- **When adding an enforcer,** R-516 still binds: manifest entry plus fixture. `enforcement-guard-check.sh` matches enforcers by `.command` path, so a `type: agent` hook (P2-6) needs that check extended before it counts as registered.
