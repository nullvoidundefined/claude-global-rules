# Criticism Audit: `~/.claude/CLAUDE.md` as a Reusable Template

**Date:** 2026-04-08
**Auditor:** Devil's Advocate (Opus)
**Subject:** `~/.claude/CLAUDE.md`, the global rules file loaded at the start of every Claude session across every project.
**Frame:** Is this template, taken as a whole, actually making Claude more effective at shipping working software, or has it accumulated process weight that produces the appearance of discipline without proportional outcomes?

---

## The Brutal Truth

This file is an example of the exact anti-pattern it spends thousands of words warning against. It is **meta-system performance art**: a 10,000-plus token rulebook whose dominant activity is rules about how to audit, handoff, document, triage, tag, dispatch, retrospect, gate, and meta-commit, with a comparatively thin layer of rules that actually make the generated code better. The Cost Discipline section was added because earlier sections (8-role audits, mandatory retrospectives, handoff docs, dual-commit rituals, dispatch protocols, complexity tags) had already ballooned the token bill and slowed the shipping loop. That is an incident without a rule update: the correct response was to delete the sections that caused the bloat, not to append a section telling future Claude to "gate" the bloat. The file is now self-referentially patching wounds that earlier sections of the same file inflicted. Every new session pays the full tax of loading this every turn, regardless of whether the current task is a one-line README fix or a security-critical refactor. The template is not the solution to Ian's discipline problem. It is Ian's discipline problem wearing a discipline costume.

A new Claude session reading this file before starting work is, by the file's own calibration, supposed to ship an afternoon-scale task in an afternoon. Reading and internalizing this file is not an afternoon-scale task. The rulebook is heavier than the work it governs.

---

## Verdict

**Rule-layer health rating: Significant, trending Fatal.**

If this were a pull request, I would not merge it. I would request a rewrite down to roughly 20 percent of its current size, with an explicit deletion list and a moratorium on new meta-rules until the remaining rules had demonstrably prevented at least one incident per quarter.

---

## What's Actually Good (kept short, as instructed)

Three rules in this file are genuinely load-bearing and should survive any cut:

1. **The em-dash ban.** Specific, enforceable, zero ambiguity, aligned with the user's stated aesthetic. Pure signal.
2. **"No confidence theater."** The nine enumerated anti-patterns are precise, correctly identify the failure modes, and give a testable definition ("if I replaced the implementation with `throw new Error('not implemented')`, would this test fail?"). This is the single best piece of writing in the file.
3. **"Never deploy to see if it works" and "root cause, not symptoms."** Short, blunt, and directly improve shipped code quality. No ceremony.

Also worth keeping, more briefly: the "test-first bug fixing" *principle*, the "check global memory before starting work" pointer, and the "dual-commit for dual-repo sessions" reminder.

That is roughly six rules. Everything else is on trial.

---

## What's Broken (objective)

### B1. Internal contradictions

- **"Do not pad timelines" vs. "write a handoff doc, run audits, triage findings, tag complexity, dispatch canaries, retrospect incidents."** The estimation section tells Claude to ship at Ian's pace, which the section itself describes as "3x to 5x faster than prior estimates." The rest of the file installs a process machine that cannot plausibly execute at that pace without being skipped. Either the pace is real, in which case most of the ceremony has to go, or the ceremony is real, in which case the pace estimate is fantasy.

- **"Keep handoff docs concise" and "under 8KB" vs. the 8-section format spec for handoff docs.** The enumerated required sections (last commit on main, production state verified, shipped today, pending grouped by urgency, recommended next session, workflow reminders, companion docs, TODO updates pending) will not fit in 8KB if the session did any real work. The file is telling Claude to follow eight required sections and also to produce a 6KB doc. Pick one.

- **"Route models by task difficulty" (Haiku for simple tasks) vs. the canonical criticism role definition telling me "Do not run this audit on Sonnet. Preferred model: Opus."** Fine in isolation, but across the audit roster there is no honest cost model for which audits justify Opus. The "Cost discipline" section says to gate audits by schedule, but the role files say each audit needs Opus. Nothing reconciles the two. Result: any session that runs an audit pays Opus prices, and the cost-discipline section is decorative.

- **"Pre-commit hooks lint and format staged files only" vs. "Commits whose subject starts with fix: MUST include at least one test file in the same commit."** The second rule cannot be enforced by a staged-files-only hook without a commit-msg hook that also inspects the staged file list. The file mandates the rule without mandating the enforcement mechanism. Either the rule is honor-system (and will decay), or the hook needs to be specified.

- **"Never batch unrelated bug IDs into a single commit" vs. "style: format all files commits are smoke; investigate hook drift root cause before committing the drift fix."** Together these require that formatting drift be fixed in a dedicated commit AND paired with a hook-verification commit in the same session AND never bundled with anything else. That is a three-commit ritual for a missed format run. In practice this will produce either skipped rules or unnecessarily noisy git history.

### B2. Rules with no enforcement mechanism (dead rules)

The following are honor-system rules dressed as policy. Each will decay the moment attention lapses:

- "Never use the em dash character." No pre-commit hook, no CI grep, no linter rule specified. Enforcement is "scan your draft before sending," which is exactly the failure mode the confidence-theater rule warns against.
- "Never batch unrelated bug IDs into a single commit." No commit-msg hook specified.
- "Pre-push fast lane + CI full suite" describes what should exist, not what does exist or how to verify it in an arbitrary project.
- "Check `~/.claude` git status at session start." No hook. No automation. Pure honor system, in a rulebook that elsewhere says honor-system rules are "broken for discipline."
- "Offer a session handoff doc when wrapping up." Honor system. The rule itself admits the prior session failed to offer one; the remedy is to write a longer rule and hope.
- "Read global memory before starting work." Honor system.
- "Parallel agent orchestration requires a canary." Honor system.
- "Subagent dispatch prompts must specify the worktree path explicitly." Honor system.

By the file's own standard ("A rule with no enforcement mechanism is either theater or an honor-system rule; call which"), most of this file is theater. The file contains the diagnosis and ignores it when looking in the mirror.

### B3. Redundancy that guarantees drift

The file itself warns against redundancy: "Redundancy is not benign; it is a latent conflict waiting to surface when one copy is updated and the others are not." Then it duplicates:

- The em-dash rule is defined here and (per the file's own references) repeated across convention files and audit role files. The canonical location should be one file. One line.
- The test-first bug-fix rule lives here and also implicitly in the convention files.
- The audit scheduling rules appear in the "Audit Roles" table AND in "Cost discipline / Audit cadence is enforced, not aspirational" AND in the individual role files. Three copies, all subtly different.
- "Check global memory" is a rule here; the global memory index itself contains overlapping rules; the feedback_model_routing file is another overlapping rule surface.

### B4. Rules that describe the rulebook instead of governing code

A surprisingly large fraction of this file is rules about rules: the session-start check of `~/.claude` git status, the session-end commit-and-push of `~/.claude`, the dual-commit discipline for dual-repo sessions, the "check for existing session handoff docs" rule, the "offer a session handoff doc when wrapping up" rule, the "convention files read on demand not globally" table, the "audit role definitions live in separate files" table, the "cost discipline" section. This is a rulebook about how to maintain the rulebook. None of it ships product. All of it is paid on every session load.

---

## What's Weak

### W1. The "Cost discipline" section is a confession, not a fix

Its existence is evidence that the file became expensive enough to warrant a new section. The correct response to "our process is too expensive" is deletion, not gating. Adding `[trivial]` / `[standard]` / `[complex]` complexity tags is more process on top of process. The new tags will themselves need enforcement and they do not have it. The section reads like a team that noticed its meeting overhead was too high and responded by adding a "meeting complexity tag" meeting.

### W2. The file optimizes for audit defensibility, not shipping

Almost every rule is phrased as something an auditor could later grade the team on ("the engineering audit will flag occurrences in any repo," "a future auditor will catch," "the retrospective that cross-checks will catch any relabel"). The target reader of many rules is a hypothetical future auditor, not the current Claude session trying to finish a task. That inverts the purpose of a rulebook.

### W3. The estimation-discipline section is in the wrong file

"Do not pad timelines" is a user-to-Claude calibration note. It belongs in a short preamble or in global memory, not in a 10,000-token behavioral rulebook. It is also self-defeating: the existence of the rest of this file is the reason estimates would need padding in the first place.

### W4. The audit roster (8 roles) is wildly over-scoped for a solo operator

Engineering, UX, Design, Marketing, Financial, Security, Legal/Compliance, Criticism. Each with a canonical role file, each with its own advisory autonomy, each preferred on Opus, each writing a dated report, each with its own failure-modes list. This is an enterprise compliance apparatus bolted onto a personal portfolio of 8 demo apps. The "when to run audits" schedule even says the full 8-role sweep is pre-launch, but the roster still exists as standing infrastructure that must be maintained, read, and reconciled. For the stated context (8 progressive fullstack AI demo apps), three roles would suffice: Engineering, Security, Criticism. Marketing and Legal and Design on demo apps is cosplay.

### W5. The handoff-doc regime is a symptom of distrust of the task list

The file explicitly states: "The TaskCreate / TaskList tool surface is session-scoped. Tasks that only live in the task list disappear when the session ends." The remedy chosen was to write an 8-section handoff doc, committed to git, at the end of every session with outstanding work. A cheaper remedy would be: use `TODO.md` or `ISSUES.md` as the source of truth for outstanding work, continuously. The handoff doc pattern is a second source of truth that now needs its own check-at-start rule, its own format rule, its own size rule, and its own offer-proactively rule. Four rules where one ("maintain TODO.md") would do.

### W6. "No confidence theater" is excellent but buried

The nine enumerated anti-patterns are the best content in the file, and they are hidden under the "Testing" section near the top where a skimming reader will hit the test-first-bug-fixing rule first and tune out. If the file cared more about shipped code quality than about audit defensibility, this section would be at the top.

---

## What's Missing

Things a real Claude session regularly needs that this file does not address:

1. **How to tell when the user wants a short answer vs. a thorough one.** The file has zero guidance on response-length calibration, which is the single most common failure mode in Claude's user-facing output.
2. **How to handle partial information and ambiguity.** When to ask a clarifying question vs. proceed with a stated assumption. The file is silent.
3. **How to decide whether to use a tool or answer from knowledge.** Rules are given for which MCP servers exist (in project CLAUDE.md) but not for when to reach for them vs. just reasoning.
4. **Context budgeting.** Nothing about reading files in parts, nothing about which files to avoid loading, nothing about token-aware search strategy, despite the file being, itself, a context-budget problem.
5. **Concrete code-quality rules.** Naming, error handling, logging standards, SQL injection patterns, input validation defaults. Zero. Everything code-quality is punted to convention files that are "read on demand." Most of the file's word count is ceremony; almost none of it is "how to write better code."
6. **A "delete a rule" process.** The file has elaborate procedures for adding rules and enforcing rules, and zero procedure for retiring rules. Rules enter; rules never leave. This is how the file got to its current size and how it will keep growing.
7. **How to say "I disagree with the rule" when a rule conflicts with the current task.** Claude will eventually hit a situation where a rule is wrong for the context; there is no escape hatch specified other than "user explicitly authorizes."

---

## Lies the Template Tells Itself

1. **"This file makes Claude ship faster and more safely."** Unverified. No evidence is cited. There is no before/after velocity data, no prevented-incident count, no tracked reduction in revert rate. The file asserts that process "must earn its keep by enabling faster or safer shipping" and then does not measure its own keep. Classic metrics theater: the file holds itself to a standard it cannot demonstrate meeting.

2. **"Convention files read on demand, not globally, keeps this file cheap to load."** False framing. This file is still enormous on its own. The "read on demand" convention is offset by the file's own girth. A lean global file loaded every turn plus on-demand conventions is the correct architecture. A fat global file plus on-demand conventions is double taxation.

3. **"Process must earn its keep."** Stated as a principle; not applied to this file. If applied honestly, three-quarters of the sections would be cut on the next pass.

4. **"The team can handle the brutal truth."** The file's tone in the criticism-audit role explicitly says so. But the existence of this file is itself a form of not handling it: Ian wrote rules instead of shipping, which is the exact displacement activity the file warns against.

5. **"We do not use em dashes because they are an AI tell."** True and fine. But the file relies on Claude noticing and scrubbing every draft by hand. A one-line pre-commit grep would enforce it in 3 seconds per commit. The rule is aesthetic; the enforcement is missing; the gap is the exact "dead rule" pattern the file elsewhere condemns.

6. **"Audits protect the organization."** Unverified. No evidence is cited that past audits caught anything that would not have been caught by the next user interaction with a broken feature. The audit roster is treated as inherently valuable rather than measured.

---

## Theater Check

### Process theater

**Positive for process theater.** Specific artifacts:

- The 8-role audit roster on a solo operator's 8-demo-app portfolio.
- The handoff-doc regime (8 required sections, proactive offer rule, session-start check rule, and a session-end commit rule).
- The dual-commit discipline for dual-repo sessions (elaborate protocol for committing in two places).
- The `~/.claude` session-start and session-end git-status checks.
- The parallel-agent canary protocol (real concern, correct principle, but specified at enterprise-dispatch length).
- The subagent dispatch worktree path protocol (three-step verification spec for what should be a one-line rule: "subagents must absolute-path everything").
- The complexity tagging regime (`[trivial]` / `[standard]` / `[complex]`) with gating rules for each tier.
- The audit-scheduling regime with its own gating rules.

None of these are cited against a measured incident reduction. All of them are paid in tokens on every session.

### Confidence theater

**The file itself is an instance.** The "No confidence theater" section is the file's best content and the file violates its spirit by not applying the same rigor to its own efficacy. If I replaced this file with six one-line rules (em dash ban, no self-mocks, root-cause debugging, no deploy-to-debug, test-first bug fixing, use TODO.md for persistent state), would the next session ship worse code? Nobody has measured. The file exists on vibes.

### Metrics theater

The audit-cadence rules specify frequencies but no outcome metric. "Biweekly during beta" is activity, not outcome. No rule says "if an audit has not caught a real problem in the last N runs, cut its cadence in half." Audits are treated as inputs to be scheduled, not as processes with measurable yield.

### Security theater

Not applicable here since the file governs process, not product security, but note that the security audit role file exists and is part of the same roster and thus subject to the same questions.

---

## Is It Actually Running?

Claims made by the file that are unverified in the current state:

- **"A commit whose subject starts with fix: MUST include at least one test file."** UNVERIFIED. No hook shown. Enforcement described as "the engineering audit will flag commits that violate this rule retroactively." That is not enforcement; that is post-hoc blame.
- **"Pre-push fast lane runs a ~30-second fast lane."** UNVERIFIED in the global file. The rule describes a policy that project-level lefthook configs are supposed to implement. The global rule cannot verify it.
- **"Pre-commit hooks lint and format staged files only."** UNVERIFIED globally. Same issue.
- **"CI runs the authoritative full-repo gate on every push."** UNVERIFIED. Policy statement.
- **"Build-smoke test for runtime-loaded non-code assets."** UNVERIFIED. This is an excellent rule that I suspect is not wired into any project. Worth checking.
- **"Check `~/.claude` git status at session start."** UNVERIFIED. Honor system; no hook runs on session start.

By the file's own "absence of evidence is evidence of absence" rule, most of the enforceable-sounding rules in this file are unenforced.

---

## Process-vs-Outcome Balance

Approximate rule count by category:

- **Rules that directly improve shipped code quality** (confidence-theater, root-cause debugging, no deploy-to-debug, test-first bug fixing, em-dash ban, build-smoke contracts): roughly 6.
- **Rules about audits, audit roles, audit cadences, audit reports**: roughly 12 including the role table.
- **Rules about handoff docs, session-start checks, session-end checks, dual-commit, and meta-session hygiene**: roughly 10.
- **Rules about dispatch protocols, canaries, worktree paths, parallel agent orchestration**: roughly 4.
- **Rules about cost discipline, complexity tags, audit gating, and model routing**: roughly 5.
- **Rules about estimation discipline**: 1 long section.
- **Rules about convention file loading and deferral**: 2.

Ratio of outcome-direct rules to process-maintenance rules: roughly **6 : 33**. That is process-vs-outcome imbalance by any reasonable standard. The file is overwhelmingly about running the rulebook, not about writing better software.

This is **meta-system performance art**. Recommend an immediate moratorium on new meta-rules. Any new rule added to this file must delete or shorten an existing rule of equal or greater length.

---

## The User's Experience, Honestly (as the Claude session reading this)

On session start I am instructed to:

1. Read this file in full.
2. Check `~/.claude` git status. Acknowledge dirty state in my opening response.
3. Read `~/.claude/global-memory/INDEX.md` if present.
4. Look for handoff docs in the project's `docs/audits/`.
5. Verify the claimed state still holds by checking git log for intervening commits.
6. Reconcile the handoff with the current code.
7. Read the project-level `CLAUDE.md`.
8. Read any nested `CLAUDE.md`.
9. Potentially read convention files on demand based on what the task touches.
10. Route the model based on task complexity.
11. Tag every plan task with a complexity level.
12. Gate subagent dispatch on the 5-task threshold.
13. Canary any parallel agent fanout.
14. Chain worktree verification into every dispatched bash call.
15. Apply test-first bug fixing.
16. Apply "no confidence theater" to any test I write.
17. Apply staged-files-only scoping to any pre-commit hook I configure.
18. Never use an em dash.
19. At session end: check if a handoff doc should be written. Offer proactively. Commit any `~/.claude` edits. Dual-push if dual-repo.

That is the pre-work before I can start the task. If the task is "fix a typo in README," items 1 through 14 are pure overhead. The file knows this and adds cost-discipline gates that are themselves more rules to load and check. The correct answer is not more gates; it is fewer rules.

I lose trust in the file roughly at the second handoff-doc rule, where the file starts writing rules about rules it just wrote. By the dual-commit discipline section I am skimming. By the time I reach the Cost discipline section I am skipping. A rulebook that I am skipping is not governing my behavior; it is producing the feeling in Ian that my behavior is governed.

---

## If I Were Competing Against This Template

I would write a 30-line rules file containing:

```
1. No em dashes (enforced by pre-commit grep).
2. No confidence theater. If replacing impl with throw would pass, rewrite the test.
3. Root cause, not symptoms. Never bypass a failing check to ship.
4. Never deploy to see if it works. Reproduce locally first.
5. Test-first for bug fixes. Failing test in the same commit as the fix.
6. Build-smoke non-code assets. If runtime loads it, post-tsc check asserts dist/ has it.
7. Use TODO.md as the single source of truth for outstanding work across sessions.
8. Run one audit only: Criticism. Run it before launch. Run it when something smells.
9. Read global memory at start. Update it at end if a lesson was learned.
10. Honest estimates. No padding. No apology for shipping fast.
```

That covers 80 percent of the value of the current file at 3 percent of the weight. It would load in milliseconds. The remaining 20 percent of value (dispatch protocols, handoff docs, role playbooks) would live in files that are read only when the current task actually invokes them, not loaded globally.

The current file's competitive weakness is that it is optimizing for a hypothetical future auditor instead of the actual current session. A competitor who optimizes for the current session wins.

---

## The Rules That Run Claude (focused findings)

### Gaps

- **No enforcement of the em-dash ban.** This should be a one-line pre-commit hook template that every project inherits. Currently honor-system.
- **No "retire a rule" process.** Rules accumulate monotonically. This is how the file reached its current weight.
- **No measurement of rule efficacy.** No section says "a rule that has not caught an incident in N sessions is a candidate for deletion."
- **No context-budget rule.** Ironic given the file's size.
- **No rule-length budget.** Nothing says "the global rulebook is capped at X tokens."

### Conflicts

Enumerated in "B1. Internal contradictions" above. The most severe is the estimation-pace rule vs. the ceremony load. The most practical is the 8KB handoff cap vs. the 8-section handoff format.

### Waste

- The 8-role audit roster for a solo operator building demo apps. Cut to 3 (Engineering, Security, Criticism). Keep the role files, remove five of them from the standing roster.
- The dual-commit discipline section. Should be one sentence: "If you edit ~/.claude, commit and push it before ending the session."
- The subagent dispatch protocol. Should be one sentence: "Subagent dispatch prompts specify the absolute worktree path and chain branch-verification into the commit bash call."
- The complexity-tag gating system. Useful intuition, 80 percent shorter.
- The retrospective rules. The rule that says "only write retrospectives after incidents" is correct and makes most of the surrounding retrospective rules obsolete. Cut.

### Redundancy

- The em-dash ban appears here and in every sibling convention file and every audit role file. Canonicalize to this file; one-line pointers elsewhere.
- The test-first bug-fixing rule appears here and in testing conventions. Canonicalize.
- Audit scheduling appears in three places. Canonicalize to the role table.
- "Never use git commit --no-verify" appears twice in adjacent sections.

### Dead rules

Enumerated in "B2" above. At minimum: the em-dash ban, the commit-msg test-file enforcement, the session-start `~/.claude` check, the handoff-doc offer rule, the global-memory read rule, the canary rule, the worktree dispatch rule. None have enforcement mechanisms. All are honor-system. Per the file's own definition, they are theater until wired.

### Thoroughness

The file claims to govern backend, frontend, database, styling, and deployment via "read on demand" convention files. Fine in principle. The thoroughness problem is that the global file itself spends almost all its words on meta-process and almost none on code-quality rules that should precede the convention-file dive. A global file that governs "how Claude behaves" should have more rules about code and fewer about process.

**Rule-layer health rating: Significant, trending Fatal.** One more major self-referential expansion of this file crosses into Fatal.

---

## The Hard Prioritization

If Ian could only fix 5 things about this file before showing it to anyone:

1. **Cut it to under 2,000 tokens.** Delete Cost discipline (the confession), delete most of Session lifecycle (handoff-doc meta-regime), delete the dual-commit discipline, delete the dispatch protocol verbosity, delete the estimation-discipline section (move to global memory), delete the audit-roster table (move to a separate index). Keep the six or seven load-bearing rules listed in "What's Actually Good."
2. **Wire enforcement for the em-dash ban.** One pre-commit grep hook template that every project inherits. This converts the most important aesthetic rule from honor-system to enforced.
3. **Retire five of the eight audit roles from the standing roster.** Keep Engineering, Security, Criticism. The other five can live as available-on-request role files but are not part of "when to run audits" cadence.
4. **Replace the handoff-doc regime with a live TODO.md convention.** Single file, continuously maintained, git-tracked. The session-start rule becomes "read TODO.md." The session-end rule becomes "update TODO.md." The proactive-offer rule disappears.
5. **Add a "delete a rule" process.** Any new rule added to this file must cite either an incident it would have prevented or an existing rule it replaces. No rule enters without justification. This is the only rule that prevents the file from returning to its current size within three months.

---

## What Would Make Me Wrong

For each Fatal/Significant finding, the single piece of evidence that would overturn it:

- **"The file is process-theater."** Overturned by: a log showing that in the last 90 days, a specific rule in this file prevented a specific incident that would otherwise have reached production. Not a "retrospective said this was good" citation. A "the rule fired and blocked the bug" citation. If such a log exists for 5+ rules, the file has earned its weight. I strongly suspect it does not.

- **"The 8-role audit roster is enterprise cosplay on a solo portfolio."** Overturned by: any audit report in `docs/audits/` from the last 60 days that caught a finding the team would have missed without that specific role. If Marketing or Legal or Design ever surfaced a real issue that changed shipped behavior, the roster is justified.

- **"The handoff-doc regime is a second source of truth."** Overturned by: evidence that at least one session was measurably more productive because it read a handoff doc AND that a simpler TODO.md would not have delivered the same benefit. The doc would have to save more session time than it cost the prior session to write, aggregated over the last 10 handoffs.

- **"The dead rules are theater."** Overturned by: showing an enforcement mechanism for each. Any rule that cannot have its enforcement shown should be either wired or deleted.

- **"The file is self-referentially patching wounds earlier sections inflicted."** Overturned by: showing that Cost discipline was written before the sections it gates. Git-blame will settle this. If Cost discipline post-dates the audit roster and the handoff-doc regime (I expect it does), the diagnosis stands.

- **"Internal contradictions exist between estimation pace and ceremony load."** Overturned by: a measured session where Claude followed every rule in this file AND shipped an afternoon-scale task in an afternoon. If that session exists and is reproducible, the contradiction is illusory.

---

## The Minimum Viable Template

What I would keep, with rough token budget:

```
Section 1: Output conventions (200 tokens)
  - No em dashes. Enforced by pre-commit grep. Canonical here.
  - Honest direct voice. No hedging.

Section 2: Code quality rules (400 tokens)
  - No confidence theater. The 9 anti-patterns, compressed.
  - Root cause, not symptoms.
  - Never deploy to debug.
  - Test-first for bug fixes.
  - Build-smoke for runtime-loaded non-code assets.

Section 3: Session lifecycle (200 tokens)
  - Start: read global memory INDEX. Read project TODO.md.
  - End: update TODO.md. Commit and push ~/.claude if edited.

Section 4: Estimation (50 tokens)
  - Do not pad. Ship at the user's observed pace.

Section 5: Audits (150 tokens)
  - Three roles standing: Engineering, Security, Criticism.
  - Five others available on request.
  - Cadence: pre-launch full sweep; reactive targeted audits
    otherwise; never full sweep as default reaction.

Section 6: Convention files (150 tokens, table only)
  - Read on demand. Names and triggers.

Section 7: Meta (100 tokens)
  - This file is capped at 1,500 tokens.
  - Any new rule must cite an incident prevented or a rule replaced.
  - Rules with no enforcement mechanism are either wired or deleted
    within 30 days of discovery.
```

Total: roughly 1,250 tokens, or about 12 percent of the current file. Every rule in this minimum version is either directly enforced or directly improves shipped code. No rule exists because "a future auditor will check it."

Everything else in the current file can live in on-demand files: the dispatch protocols in a subagent-dispatch.md, the handoff-doc format in a session-handoff.md, the audit scheduling in a separate audit-cadence.md, the complexity-tag gating in a planning.md. The global file loads the core 1,250 tokens every session. The rest loads when the current task actually needs it.

---

## Closing Statement

This file is Ian's discipline instinct operating without a forcing function to delete. It has accumulated by accretion, each new section a reasonable response to a specific past pain. Taken individually, most rules defend themselves. Taken as a whole, the file is the exact over-engineered process ceremony that Ian explicitly tells Criticism audits to call out in product codebases. The fact that the file contains the diagnosis of its own pathology (the "process theater" definition, the "meta-system performance art" phrase, the "process must earn its keep" assertion) and has not been cut is itself the single most damning finding. The diagnosis is present; the surgery is missing. A team that can see the disease and not treat it is in worse shape than a team that cannot see it at all, because the first team has ruled out ignorance as an excuse.

Cut the file. Wire the rules that remain. Measure what they catch. Delete what they do not.

If this were a pull request: **request changes, do not merge.**
