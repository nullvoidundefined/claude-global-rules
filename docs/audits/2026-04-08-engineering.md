# Engineering Audit: `~/.claude/CLAUDE.md` as Reusable Template

**Date:** 2026-04-08
**Auditor role:** Engineering (CTO), per `~/.claude/audits/engineering.md`
**Subject:** `~/.claude/CLAUDE.md` (866 lines, 44,416 bytes)
**Framing:** Document UX plus engineering correctness of the file as a reusable template that governs every Claude session across every project.

## Executive Summary

The file is a high-quality knowledge base. It encodes a significant amount of hard-won operational wisdom (test-first fixing, confidence theater, canary-before-fan-out, handoff docs, credential scans, lefthook scope). The rules are largely technically correct and internally consistent. The problem is not the content; it is the **shape**. As a document that is loaded into context at the start of every Claude session, it is:

1. **Too long to be fully absorbed.** 44KB / 866 lines / roughly 11,000 tokens of always-on context. Large sections are prose-dense with no headings-per-paragraph, which trains both human and model readers to skim. The "Cost discipline" section at the bottom explicitly says "keep handoff docs under 8KB" while this file itself is 5x that.
2. **Missing an information architecture.** There is no table of contents, no "if you read nothing else" section, no rule index, no severity / scope tagging on individual rules. Finding the rule that governs a specific situation (e.g., "can I use `--no-verify`?") requires a full scan.
3. **Inconsistent in rule format.** The file itself prescribes a "Why + How to apply" structure for rules. Roughly half the rules follow it. The other half are prose paragraphs with the "why" embedded mid-sentence. This is the single highest-leverage fix.
4. **Missing enforcement hooks** for several MUST-level rules. The em-dash ban, the fix-commit-requires-test rule, and the worktree-verify rule are all honor-system. The file acknowledges the problem for one of them (fix commits) but does not ship the check.
5. **Under-cross-referenced.** Rules that depend on other rules or external files rarely link to them. The convention-file table is the only section that does this well.

**Top 3 priorities** (ranked by leverage):

1. **[P1, UX]** Add a table of contents and an "If you read nothing else" quick-reference at the top. Current file forces full linear read to find any rule.
2. **[P1, correctness]** Ship enforcement for the em-dash ban and the fix-commit-requires-test rule as lefthook `commit-msg` / `pre-commit` hooks in a canonical `~/.claude/hooks/` directory. The current rules are load-bearing but entirely honor-system.
3. **[P1, UX]** Normalize every rule to the "Rule / Why / How to apply / Counter-example" template. The file itself prescribes this structure and then violates it in roughly half its own rules.

---

## Operational Basics (for the document-as-product)

| Check | Status | Notes |
|---|---|---|
| Is there a table of contents? | NO | Blocker for a 866-line doc |
| Is there a quick-reference / "read this first" section? | NO | |
| Are rules consistently structured? | PARTIAL | Mixed prose and template form |
| Are cross-references linked? | NO | Rules reference each other by name, no anchors |
| Are convention-file pointers correct? | YES | All 6 files in the table exist at the listed paths |
| Do `global-memory/INDEX.md` and `feedback_model_routing.md` exist? | YES | Verified |
| Do all 8 audit role files referenced in the role table exist? | YES | Verified in `~/.claude/audits/` |
| Are MUST-level rules machine-enforced? | NO | Em dash, fix+test, branch-verify are honor-system |
| Is the file size under the implicit token budget of "always-on context"? | NO | 44KB / ~11K tokens is substantial on every session start |

---

## Document UX Review

### DU-1. No table of contents or rule index [P1, UX]

**Finding.** 866 lines, no TOC, no anchors, no rule numbers. A Claude session that wants to find "what is the rule on pre-commit hook scope?" has to scan the whole file or grep for a keyword that may or may not appear. A human reader is worse off.

**Why it matters.** The 30-second findability test fails for almost every rule. For a document loaded at the start of every session, the practical consequence is that Claude will "remember" the rules it encountered near the top of the file and skim the middle and bottom. Cost-discipline rules at the bottom are therefore the most likely to be silently ignored, which is the exact opposite of what the user wants.

**Recommended edit.**
- Add a TOC at the top (15 lines, bullet list of section headings with markdown anchors).
- Number every rule (`R-001`, `R-002`, etc.) so other rules can reference them unambiguously.
- Add a "Quick Reference" block at the very top with the 5 most load-bearing rules in one-line form: no em dashes, test-first bug fix, root cause not symptoms, no deploy to "see if it works", read global memory index at start.

### DU-2. Inconsistent rule format [P1, UX]

**Finding.** The file recommends a "Rule / Why / How to apply" format implicitly (several rules follow it explicitly with bolded labels). Many rules are dense prose paragraphs with the "why" buried mid-sentence. Examples of well-structured rules: "Pre-commit hooks lint and format staged files only", "No confidence theater". Examples of poorly structured rules: "Root cause, not symptoms" (three sentences, no "How to apply"), "Never deploy to see if it works" (two sentences).

**Why it matters.** Inconsistency trains the reader to skim. When every third rule follows the template, the reader learns to look for the bolded headers. When a critical rule is three sentences of prose, the reader skips it.

**Recommended edit.** Normalize every rule to this exact template:

```
### <Rule title>

**Rule.** <one sentence, imperative>
**Why.** <one to three sentences>
**How to apply.** <bullet list or numbered steps>
**Counter-example.** <what this rule forbids, concretely>
```

Rules that genuinely need more (confidence theater, handoff doc format) can extend this with additional subheadings but must still start with these four labels.

### DU-3. No "If you read nothing else" section [P1, UX]

**Finding.** For a document loaded into every session, there is no explicit signal about which rules are non-negotiable vs which are context-dependent. Em dash ban (non-negotiable) sits next to estimation discipline (context-dependent) at the same visual weight.

**Recommended edit.** Add at the top, before any other content:

```
## Non-negotiable rules (these override everything else)

1. Never use the em dash character (U+2014). See R-001.
2. Fix bugs test-first. Write failing test, fix code, verify passing. See R-014.
3. Never deploy to "see if it works". Reproduce locally first. See R-022.
4. Never bypass safety checks with --no-verify without explicit user approval. See R-015.
5. Read ~/.claude/global-memory/INDEX.md before starting substantive work. See R-025.
```

### DU-4. Section ordering buries the most-used rules [P2, UX]

**Finding.** "Cost discipline" (arguably the most actively-applied section during normal work) is at the bottom. "Output conventions" (em dash ban) is near the top but is one rule. "Audit Roles" and "Estimation discipline" are large middle sections that most sessions will never touch.

**Recommended edit.** Reorder by access frequency, not by topical grouping:

1. Non-negotiable rules (new, see DU-3)
2. Output conventions (em dash)
3. Session lifecycle (check git status, check global memory, offer handoff)
4. Testing + debugging discipline (test-first, root cause, confidence theater)
5. Cost discipline + complexity tagging + model routing
6. Convention file pointers
7. Audit roles + schedule (less frequently invoked)
8. Estimation discipline (only relevant during planning conversations)

### DU-5. Terminology is assumed, not defined [P2, UX]

**Finding.** Key terms are used without a canonical definition:

- "P0 / P1 / P2 / P3" is used 30+ times. Defined inline in the Audits section but nowhere highlighted as a canonical definition block.
- "Canary" (in parallel-agent context) is defined inline in the debugging section but never called out as a term.
- "Complexity tag" (trivial / standard / complex) is defined inline in cost discipline but not linked from elsewhere.
- "Confidence theater" is defined exhaustively but the definition is buried under a testing subheading.
- "Handoff doc" is defined in three different places with overlapping but non-identical content.

**Why it matters.** A Claude session that sees "P2 finding" in one rule and wants to know what a P2 finding is has to grep for it. Humans maintaining the doc will slowly drift the definitions apart.

**Recommended edit.** Add a "Glossary" section near the top with canonical one-paragraph definitions, and link every inline use back to the glossary.

### DU-6. Handoff doc rules are duplicated and drifting [P2, UX]

**Finding.** There are three sections that describe handoff docs:
1. "Check for existing session handoff docs when starting work"
2. "Offer a session handoff doc when wrapping up"
3. "Keep handoff docs concise" (in cost discipline)

They overlap significantly. The format spec is in (2), the read protocol is in (1), the length guidance is in (3). A reader assembling the full picture has to read all three and diff them. The three sections also disagree slightly: (2) says "under 8KB" appears nowhere in its spec, which is only in (3).

**Recommended edit.** Consolidate into a single "Session handoff documents" section with subheadings: "When to read", "When to write", "Required format", "Length target", "Where to store".

### DU-7. Length: roughly 40% of the file could be trimmed without losing rules [P2, UX]

**Finding.** Several sections use 300 to 500 words to convey rules that could be stated in 80 to 120 words. Examples:

- "Dual-commit discipline for dual-repo sessions": the entire narrative about the 2026-04-08 session is motivation, not rule. Move the narrative to a `## Rationale footnotes` section or drop it.
- "Subagent dispatch prompts must specify the worktree path explicitly": the "Why" paragraph repeats the rule.
- "No confidence theater": the 9 enumerated anti-patterns are good but each includes a full explanatory paragraph. Compress to one-line definitions with concrete examples.

**Why it matters.** Every token of always-on context competes with the task the user is actually asking about. A 40% trim would free roughly 4500 tokens per session for actual work.

**Recommended edit.** Pass every section through a "one-sentence rule, two-sentence why, bullet how-to-apply" compression. Move all narrative incident histories to `~/.claude/global-memory/incidents/YYYY-MM-DD-<slug>.md` and reference them by path.

### DU-8. Cross-references are by name, not by anchor [P2, UX]

**Finding.** Rules reference each other by prose ("see the canary-first rule", "the `~/.claude/CLAUDE.md` estimation section"). There are no markdown anchors. A reader who wants to jump to a referenced rule has to scroll or search.

**Recommended edit.** Add explicit anchors (`<a id="R-017-canary"></a>`) on every rule header and use `[canary rule](#R-017-canary)` link syntax throughout.

### DU-9. Self-test: can a session find the right rule quickly? [P1, UX, failing]

I tested three plausible scenarios:

**Scenario A: "Fix this bug."** A session loads the file and needs to know: do I write a test first? Yes, the rule is findable under "Test-first bug fixing". **Pass** (keyword match works).

**Scenario B: "Deploy the project."** A session needs to know: what do I check after `git push`? The rule is in `<project-path> (project-level), not in the global file. The global file does not mention post-deploy polling at all. A session reading only the global file would not know to poll. **Fail.** The deploy-monitoring rule should either be referenced from the global file or promoted to it.

**Scenario C: "Commit a formatting cleanup."** A session needs to know: is this allowed, and under what conditions? The rule is under "Test-first bug fixing" (weirdly), titled "`style: format all files` commits are smoke". A reader looking under "commits" or "formatting" would not find it. **Fail.** The rule belongs under a "Commit discipline" section, not under "Testing".

**Recommended edit.** Reorganize the file so that each rule lives under the section a reader would look in first, not the section where the rule was originally written.

### DU-10. No onboarding path [P2, UX]

**Finding.** If a brand-new Claude session loaded only this file with no prior context, it would not know what to do first. The file starts with "Global Rules for All Projects" and immediately enters the em-dash rule. There is no "Welcome, here is how to use this file" orientation.

**Recommended edit.** Add a 10-line "How to use this file" block at the top:

```
This file is loaded at the start of every Claude session. Read it in this order:
1. Non-negotiable rules (above). These are load-bearing.
2. Session lifecycle. Run the start-of-session checks.
3. The glossary if you encounter an unfamiliar term.
4. The convention file pointer table when you start touching code.
5. The audit role table only when asked to run an audit.
```

---

## Engineering Correctness Review

### EC-1. Em-dash ban is honor-system, not enforced [P1, correctness]

**Finding.** The file spends 400 words explaining why the em dash must never appear in any output, then ships no mechanism to check for it. Every session is expected to manually scan its own output for U+2014 before sending.

**Why it matters.** The rule's own rationale is "the user considers em dashes a violation of trust." A trust-critical rule should not rely on self-audit. A single lapse is catastrophic per the stated rationale.

**Recommended fix.** Ship two enforcement layers:

1. A lefthook `pre-commit` hook at `~/.claude/hooks/no-em-dash.sh` that greps every staged file for U+2014 and fails the commit if found. Install path should be documented in this file.
2. A Claude Code `PostToolUse` hook for the Write and Edit tools that rejects any content containing U+2014. This is the high-leverage enforcement because it catches the violation before it lands on disk.

Both hooks are 10 lines of shell. The engineering cost is trivial; the value is the rule's entire stated purpose.

### EC-2. Fix-commit-requires-test rule is honor-system [P1, correctness]

**Finding.** The rule says `fix:` commits MUST include a test file change, and "commits that violate this rule are evidence of optimism-driven debugging and the engineering audit will flag them retroactively." Retroactive flagging is not enforcement. It is blame assignment after the fact.

**Why it matters.** The rule is prescriptive and load-bearing. Retroactive detection during an audit run that happens biweekly means 14 days of uncaught violations can accumulate before the gap is surfaced. The whole point of the rule is to make the violation expensive at commit time, not at audit time.

**Recommended fix.** Ship a lefthook `commit-msg` hook that:
1. Checks whether the commit subject starts with `fix:` / `fix(` / `bug:` / `bugfix:` / `hotfix:`.
2. If yes, checks whether the staged diff includes any file matching the test globs listed in the rule.
3. If no test file, rejects the commit with a message pointing at this rule and suggesting the `docs:` / `chore:` relabel option (with the "relabeling does not dodge the rule" caveat).

### EC-3. Subagent branch-verify rule has no enforcement layer [P2, correctness]

**Finding.** The rule requires every subagent dispatch prompt to include "CRITICAL BRANCH SETUP" with `cd`, branch verification, and a chained `&&` commit. Enforcement is that the dispatcher (the main session) remembers to include it.

**Recommended fix.** Add a canonical `~/.claude/prompts/subagent-branch-setup.md` snippet that the main session can include by reference. This turns the rule from "remember to write this" into "paste this block". Not full enforcement, but substantially reduces the failure mode.

### EC-4. Confidence theater rule is technically excellent but missing a measurement loop [P2, correctness]

**Finding.** The 9 anti-patterns are correctly identified and technically sound. There is no mechanism to measure them in a given codebase. The rule relies on the engineering audit to catch them, but the audit role definition does not specify how to measure them mechanically (e.g., grep for `vi.mock` of the module-under-test, grep for tests whose only assertion is `toBeDefined()`).

**Recommended fix.** Add a `## Measurement` subsection to the confidence-theater rule with grep / regex recipes for each of the 9 anti-patterns so the audit has a mechanical starting point.

### EC-5. Convention-file pointer table is correct but incomplete [P2, correctness]

**Finding.** The table lists 6 convention files. All 6 exist at the listed paths (verified). However, the "project-level CLAUDE.md may reference their own project-local copies" note is not enforced or cross-checked anywhere. A project could silently drift.

**Recommended fix.** Add to the engineering audit role: "verify that every file referenced by path in `~/.claude/CLAUDE.md` exists and is non-empty." A 20-line audit script that runs during engineering audits would catch pointer rot the moment it happens.

### EC-6. "Read global memory before starting work" is honor-system AND hidden [P1, correctness]

**Finding.** The rule to read `~/.claude/global-memory/INDEX.md` at the start of every substantive work is arguably the single most load-bearing operational rule in the file (it gates cross-project lessons). It is buried in the "Debugging and fixing" section, which is the wrong section. There is no mechanism to verify it was read.

**Recommended fix.**
1. Move this rule to the new "Session lifecycle" section at the top.
2. Add a `SessionStart` Claude Code hook that prints the contents of `~/.claude/global-memory/INDEX.md` to the session transcript, forcing the information into context regardless of whether the session explicitly reads it.

### EC-7. Test-first rule over-claims its applicability [P2, correctness]

**Finding.** The rule says "When fixing any breaking issue, follow this exact process: 1. Write a test that reproduces the failure." This is technically correct for most bugs but genuinely hard or impossible for some categories: timing-dependent race conditions, hardware-specific failures, production-only environmental failures, third-party API misbehavior that cannot be replayed. The rule does not acknowledge these categories or offer a substitute ("capture a log trace, document the repro steps, then fix").

**Recommended fix.** Add a short "When a test is genuinely impossible" subsection with the escape hatch: document the repro, link an issue, fix, manually verify, log a `tech-debt:` note to eventually write the test when the infrastructure supports it. This prevents the escape hatch from being used promiscuously while acknowledging the legitimate edge cases.

### EC-8. Lefthook is assumed, not specified [P3, correctness]

**Finding.** Multiple rules reference lefthook (pre-commit, pre-push, commit-msg). The file does not specify a canonical `lefthook.yml` template or installation path. Each project is expected to re-derive the configuration.

**Recommended fix.** Add a `~/.claude/templates/lefthook.yml` canonical template and reference it from every rule that depends on a hook.

### EC-9. "Route models by task difficulty" depends on an external file [P3, correctness]

**Finding.** The rule delegates to `~/.claude/global-memory/feedback_model_routing.md` (verified to exist). This is fine, but the summary in the main file is thin and the delegation is easy to miss. Model routing is one of the highest-impact cost levers and deserves inline treatment, not delegation.

**Recommended fix.** Inline the model-routing decision table into the main file. It is roughly 20 lines. Keep the external file as the canonical long-form reference.

### EC-10. No versioning or change-log [P2, correctness]

**Finding.** The file is under `~/.claude/` which is (per the dual-commit-discipline rule) a git repo. There is no in-file change log, no "last updated", no rule version numbers. When a rule changes, there is no signal to sessions that were loaded with the old version.

**Recommended fix.** Add a `## Change log` section at the bottom with dated entries and add a "Last updated: YYYY-MM-DD" header line at the top. When a rule changes, bump the date and log the change.

---

## Security (of the document itself)

### S-1. The file documents credential-scan patterns [P3, correctness]

The file references the credential-scan section of the engineering audit role. It does not itself contain credentials. Clean.

---

## Database, API Design, Performance, Dependencies

Not applicable (the subject is a rules document, not an application).

---

## Bug Fix Discipline (of the file's own history)

Not scanned in this audit. Recommend a follow-up audit that runs `git log` on `~/.claude/CLAUDE.md` and cross-checks commit history against the file's own "fix commits must include tests" rule. The file itself is unlikely to have fix commits (it is prose), so the check is more useful on the audit role files and hook scripts.

---

## Runbook-vs-Code Drift

Not applicable in the traditional sense. However, the file contains several rules that reference external files (`~/.claude/audits/*.md`, `~/.claude/global-memory/*.md`, the 6 convention files). All referenced files were verified to exist at the listed paths at audit time. No drift. Recommend automating this check (see EC-5).

---

## Workspace Hygiene

Not applicable (the file is a single canonical location under `~/.claude/`). No duplicates to flag.

---

## Tech Debt Register (for this file)

| ID | Item | Severity | Effort |
|---|---|---|---|
| TD-1 | No TOC / quick-reference / anchors | P1 | S |
| TD-2 | Inconsistent rule format | P1 | M |
| TD-3 | Em-dash ban has no enforcement hook | P1 | S |
| TD-4 | Fix-commit-requires-test has no enforcement hook | P1 | S |
| TD-5 | Handoff doc rules duplicated across 3 sections | P2 | S |
| TD-6 | Terminology not centralized in a glossary | P2 | S |
| TD-7 | File length roughly 40% above minimum for content | P2 | M |
| TD-8 | No onboarding / "how to read this file" block | P2 | S |
| TD-9 | Global memory read rule is buried and honor-system | P1 | S |
| TD-10 | No change log / versioning | P2 | S |
| TD-11 | Self-test finds 2 of 3 scenarios unfindable via natural search | P1 | M |
| TD-12 | Lefthook config is assumed, not templated | P3 | S |
| TD-13 | Convention-file pointer rot check is not automated | P2 | S |
| TD-14 | Subagent dispatch prompt rule has no reusable snippet | P2 | S |

---

## Prioritized Recommendations

| Rank | Action | Impact | Effort | Finding |
|---|---|---|---|---|
| 1 | Add TOC, anchors, and "Non-negotiable rules" quick-reference at top | H | S | DU-1, DU-3 |
| 2 | Ship `~/.claude/hooks/no-em-dash.sh` as a lefthook + PostToolUse hook | H | S | EC-1 |
| 3 | Ship `~/.claude/hooks/fix-commit-requires-test.sh` as lefthook commit-msg | H | S | EC-2 |
| 4 | Normalize every rule to "Rule / Why / How to apply / Counter-example" | H | M | DU-2 |
| 5 | Move global-memory-read rule to top under Session lifecycle, add SessionStart hook | H | S | EC-6 |
| 6 | Consolidate handoff doc rules into one section | M | S | DU-6 |
| 7 | Add a Glossary section (P0..P3, canary, complexity tag, handoff, confidence theater) | M | S | DU-5 |
| 8 | Reorder sections by access frequency | M | M | DU-4 |
| 9 | Compress the file by roughly 40% by moving incident narratives to `~/.claude/global-memory/incidents/` | M | M | DU-7 |
| 10 | Add Measurement subsections to the confidence-theater and bug-fix-discipline rules | M | S | EC-4 |
| 11 | Add canonical lefthook template at `~/.claude/templates/lefthook.yml` | M | S | EC-8 |
| 12 | Inline the model-routing decision table | M | S | EC-9 |
| 13 | Add a change log and "Last updated" header | L | S | EC-10 |
| 14 | Automate convention-file existence check in engineering audit | L | S | EC-5 |
| 15 | Add "when test-first is genuinely impossible" escape hatch | L | S | EC-7 |

---

## Concrete Recommended Edits (high-leverage diffs)

### Edit 1: Add this block at line 1 of the file

```markdown
# Global Rules for All Projects

**Last updated:** 2026-04-08
**How to use this file:** Load at session start. Read the Non-negotiable rules block below. Skim the TOC. Jump to the section matching your current task. When in doubt, grep for the rule ID (R-NNN).

## Non-negotiable rules (override everything else)

1. [R-001] Never use the em dash character (U+2014). Substitute period, comma, semicolon, colon, parentheses, or line break.
2. [R-014] Fix bugs test-first: failing test, then fix, then passing test, then commit.
3. [R-015] Never bypass safety checks (`--no-verify`, lint disable, commented-out test) without explicit user approval.
4. [R-022] Never deploy to "see if it works". Reproduce locally first.
5. [R-025] Read `~/.claude/global-memory/INDEX.md` before starting substantive work in any project.

## Table of contents

- [Output conventions](#output-conventions)
- [Session lifecycle](#session-lifecycle)
- [Testing and debugging](#testing-and-debugging)
- [Cost discipline](#cost-discipline)
- [Convention files](#convention-files)
- [Audit roles](#audit-roles)
- [Estimation discipline](#estimation-discipline)
- [Glossary](#glossary)
- [Change log](#change-log)
```

### Edit 2: Add a Glossary section before the Change log

```markdown
## Glossary

- **P0 / P1 / P2 / P3.** Severity tags. P0 = broken, data loss, or security hole, fix now. P1 = critical path degraded, high-risk, fix this sprint. P2 = quality or UX friction, defer to `ISSUES.md`. P3 = nice-to-have or cosmetic, defer.
- **Complexity tag.** `[trivial]` (inline in main session), `[standard]` (one implementer + one reviewer), `[complex]` (full implementer + spec reviewer + code quality reviewer). See cost discipline.
- **Canary.** A single subagent dispatched first before any parallel fan-out, to validate the dispatch pattern end-to-end.
- **Handoff doc.** A dated file at `docs/audits/YYYY-MM-DD-session-handoff.md` that captures session end state. See Session lifecycle.
- **Confidence theater.** A test that passes without actually exercising the thing it claims to test. Nine canonical anti-patterns; see Testing.
- **Subagent.** A separate Claude invocation dispatched by the main session to perform a scoped task. Full model cost per dispatch.
```

### Edit 3: Ship these two hook files

`~/.claude/hooks/no-em-dash.sh`:
```bash
#!/usr/bin/env bash
# Rejects any staged content containing U+2014.
set -euo pipefail
if git diff --cached | grep -P '\xe2\x80\x94' > /dev/null; then
  echo "ERROR: em dash (U+2014) found in staged content. See R-001."
  exit 1
fi
```

`~/.claude/hooks/fix-commit-requires-test.sh`:
```bash
#!/usr/bin/env bash
# commit-msg hook. Rejects fix: commits with no test file change.
set -euo pipefail
msg_file="$1"
subject=$(head -n1 "$msg_file")
if [[ "$subject" =~ ^(fix:|fix\(|bug:|bugfix:|hotfix:) ]]; then
  if ! git diff --cached --name-only | grep -E '(\.test\.|\.spec\.|e2e/|__tests__/|test/)' > /dev/null; then
    echo "ERROR: fix commit must modify a test file. See R-014."
    echo "If this is not a bug fix, relabel as docs: or chore:."
    exit 1
  fi
fi
```

Both scripts are idempotent, 10 lines each, and address the two highest-leverage honor-system gaps in the file.

---

## Acknowledgments

The file is genuinely good content. Every rule in it earned its place through a real incident or a real cost lesson. The criticism in this audit is almost entirely about shape, not substance. A reorganized version of this file with working enforcement hooks would be the best operational-rules document I have seen for this kind of cross-project knowledge base.

The single most important insight from this audit: **a rule loaded into every session is only as good as its findability under a 30-second scan and its enforcement under zero-trust assumptions.** This file has world-class content, honor-system enforcement, and middling findability. Fix the bottom two and the content does its intended job.
