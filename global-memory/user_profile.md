---
name: Ian Greenough developer profile
description: Synthesized profile of the user based on cross-project memory sweep on 2026-04-06
type: user
---

Ian is a senior full-stack developer running a portfolio of 14+ personal projects across production, development, and template categories. Operates as a one-person CTO: designs the architecture, ships the code, defines the conventions, runs the audits, and monitors the deploys.

**Core stack:** Next.js 15, Express 5 + TypeScript, PostgreSQL (raw SQL via `pg`, no ORM), Supabase Auth, pnpm monorepos, Vercel + Railway + Neon deployments. Heavy Anthropic Claude API usage. Playwright, Vitest, lefthook, Radix UI, SCSS modules, Zod, BullMQ. Comfortable with browser extensions (WXT), OAuth providers, Stripe, Twilio, Resend.

**Working style:**
- Strict TDD. Tests first, red-green-refactor, commit test + implementation together.
- Atomic commits. One task per commit, separate commits for unrelated work.
- Prefers momentum over permission-asking. Wants Claude to act, not delegate back.
- Batches pushes and deploys; does not want incremental deploys mid-session unless asked.
- Values professional polish: 100% Lighthouse a11y, comprehensive test layers, audit discipline.

**Meta-practices:**
- Runs 8 specialized audit roles (Engineering, UX, Design, Marketing, Financial, Security, Legal, Criticism) as autonomous senior advisors.
- Dated audit history under `docs/audits/YYYY-MM-DD-<type>.md`, never overwriting.
- P0/P1 findings fixed test-first in current effort; P2/P3 logged to `ISSUES.md` and deferred.
- On-demand convention files (`CLAUDE-BACKEND.md`, `CLAUDE-FRONTEND.md`, etc.) loaded only when relevant to the task.

**Failure modes to watch for (from prior incidents):**
- Optimism-driven debugging: "fix and deploy to see if it works" instead of reproducing locally first.
- Project directory sprawl: restarting and restructuring faster than finishing.
- Re-teaching Claude the same lesson across projects because memory is project-scoped.

**How to apply:** Frame explanations at senior-engineer level. Do not suggest next steps; execute them. Do not ask for permission on routine verification/checks. Default to TDD. Default to atomic commits. Assume the five-tier test pyramid (unit, integration, component, E2E, smoke) unless the project explicitly says otherwise.
