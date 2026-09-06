# Session Handoff: 2026-09-06 TDD harness assessment and slice-loop enforcement (steps 1 to 3)

## 1. Last commit

- `0b6c1f7` feat(hooks): run the verification gate on SubagentStop (R-509), on `claude/tdd-harness-llm-code-fuf9rh`. Before it: `0d96c35` (tdd.sh), `d116dbb` (protected-path guard, R-410 to R-412), `4189a9c` and `3f2ba92` (the assessment and its nine decisions). No PR opened.

## 2. Production state

- Branch is green locally: 45 enforcement fixtures, 12 hook fixtures, run against this checkout through a fake `$HOME` with a git identity. CI has not run on the branch yet (it runs on `pull_request` and `main`).
- Nothing is live in Ian's `~/.claude` until the branch merges and is pulled. After the pull: `npm ci --prefix enforce` (the lockfile now carries `vitest` 5.0.0, pinned exact, as a devDependency for the live `tdd.sh` fixture), then `hooks/hook-integrity-check.sh` should be silent (the manifest was regenerated three times on the branch).
- The judge key is still pending (decision 9); R-401 anti-patterns 2, 4, 6, 7 are critic-only until it lands.

## 3. What shipped

- **Assessment (`docs/audits/2026-09-06-tdd-harness.md`):** current state, gap analysis (C-1 to C-4 critical), target workflow, concrete changes, agent-role design, guardrails, a worked example, the minimal plan, and the nine decisions asked one at a time.
- **Step 1, `hooks/protected-path-guard.sh` (R-410, R-411, R-412):** PreToolUse on Bash and Write|Edit. Denies writes to the gate inputs (`.claude/verify.sh`, `.enforce.json`, `.enforce-baseline.json`, `.claude/tdd-lock.json`); asks on test-runner configs and the `package.json` test/typecheck scripts; reads the slice lock (phase `open` denies production writes, `red`/`green` deny every test-tree write plus locked fixtures and the spec); reads `agent_type` against `enforce/role-policy.json` (test-author writes tests only, implementer never tests/fixtures/specs, slice-critic and spec-conformance-review nothing). Bash is judged by redirections, `tee`, and the operands of mutating verbs. Fixture: 60 cases.
- **Step 2, `enforce/tdd.sh` (R-412):** `open`, `red`, `green`, `close`, `status`. RED accepted only for assertion or missing-module failures with the rest of the suite green; records baseline and sha256 per file. GREEN checks hashes against the lock and the RED commit, then requires every named test to pass, none skipped, outside count at or above baseline. Vitest and Jest only. Fixture drives the bundled Vitest against a throwaway project.
- **Step 3, `SubagentStop`:** `verification-gate.sh` registered on it; skips roles whose policy entry is `deny: ["any"]`. Six new fixture cases.
- Rule text: R-410 to R-412 norm lines and Spec blocks, R-509 updated; manifest rows; `enforce/README.md` slice-lock section; README layout; PROTOCOL "What changed on 2026-09-06" and Appendix A origin.

## 4. Pending

**Ian, before anything else (both are one-command checks on the real build):**

1. Confirm `agent_type` reaches a `PreToolUse` command hook: add a scratch hook that logs `jq -r '.agent_type // "none"'` and dispatch one subagent. If absent, R-411 falls back to lock-only and the agent files in step 4 need their own `hooks:` block.
2. Confirm the Stop contract on the installed build still honors `{decision: "block", reason}` and `stop_hook_active` for `SubagentStop`; the current hooks reference excerpt shows `continueConversation` instead. A mismatch fails open silently.

**Then, from the assessment's minimal plan (steps 4 to 6, not started):**

4. `agents/test-author.md`, `agents/implementer.md`, `agents/slice-critic.md`; rewrite `skills/tdd-gated-dispatch/SKILL.md` around `tdd.sh` and the roles (strip code fences from the plan before handing a task to the test author, decision 2); R-705 and a new R-707 in `rulebook/agents.md`; `task-start` tier table (Standard: `tdd.sh open` then `red` before any production edit); drop the `test.skip` scaffold from `feature-create` and `task-cleanup`.
5. `prompts/spec-template.md`; extend `spec-glossary-check.sh` to warn on missing `## Acceptance criteria` and `## Non-goals`.
6. `import-x/no-cycle`; widen the observability ESLint block to `services/` and `clients/`; `enforce/rules/no-self-mock.mjs` and `behavior-assertion-required.mjs` with fixtures.

**Deferred by decision:** pytest, go test, and RSpec runners in `tdd.sh` (Vitest first); mutation testing on changed files; the dependency-addition guard; the judge-tier extension.

## 5. Next-session tasks, with files to read

- Read `docs/audits/2026-09-06-tdd-harness.md` sections 3 to 6 and the Decisions block before step 4; the agent files and the skill rewrite follow the role table there.
- Read `hooks/protected-path-guard.sh` header and `enforce/tdd.sh` header before touching either; both state what they do not see (an interpreter writing from its own source) and why the GREEN hash check exists.
- `enforce/role-policy.json` is the single place roles and path patterns live; a new role is a new key, and `tdd.sh red` validates test paths against the same `tests` pattern.
- When adding an enforcer, R-516 binds: manifest row plus fixture; `hook-integrity-check.sh --update` now also covers `enforce/*.sh` and `role-policy.json`.
