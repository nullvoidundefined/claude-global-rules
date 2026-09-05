#!/usr/bin/env node
/**
 * build.mjs: renders the Cursor port from the canonical Claude Code sources
 * into ~/.cursor, the directory Cursor reads beside ~/.claude:
 *
 *   ~/.cursor/rules/*.mdc            Cursor rules (always-on, glob-attached, or
 *                                    agent-requested), one per source file or
 *                                    rulebook block
 *   ~/.cursor/agents/*.md            Cursor subagents from agents/*.md
 *   ~/.cursor/commands/*.md          Cursor slash commands (session procedures
 *                                    and one dispatcher per agent)
 *   ~/.cursor/skills/<name>/         every skill, with the two shell-include
 *                                    skills given a body Cursor can use
 *   ~/.cursor/hooks.json             the hook wiring (from cursor/hooks.json)
 *   ~/.cursor/hooks/claude-hook-adapter.sh  the adapter (from cursor/hooks/)
 *   ~/.cursor/PORT-STATUS.md         which hook and permission layers port,
 *                                    and why the rest do not
 *
 * The loaders, the substitution primitive, and the --check / --write driver
 * live in enforce/portBuild.mjs, shared with openai/build.mjs. Nothing
 * generated is kept in this repository.
 *
 *   node cursor/build.mjs --write             build (or refresh) ~/.cursor
 *   node cursor/build.mjs --check             exit 1 when ~/.cursor is stale
 *   node cursor/build.mjs --print             list the files the build produces
 *   node cursor/build.mjs --write --project <repo>   build into <repo>/.cursor
 *   node cursor/build.mjs --write --out <dir>        build into any directory
 */
import { existsSync } from "node:fs";
import { join } from "node:path";
import {
  ROOT,
  SESSION_HANDOFF_STEPS,
  SESSION_START_STEPS,
  agentDispatchText,
  annotateEnforcerTags,
  currentR001Line,
  generatedMarker,
  homeDir,
  loadAgents,
  loadSettingsHookRows,
  loadSkills,
  loadStackConventions,
  parseFrontmatter,
  parsePortArgs,
  readSource,
  renderAllowlistGitignore,
  renderPortReadme,
  runPortBuild,
  splitFrontmatter,
  substitute,
} from "../enforce/portBuild.mjs";

const BUILDER = "cursor/build.mjs";
// cursor/hooks.json names the adapter with this placeholder; the build fills
// in the path Cursor resolves for the target: absolute for the user-level
// ~/.cursor, relative to the repo root for a project-level .cursor/.
const ADAPTER_PLACEHOLDER = "{{adapter}}";
const ARGS = parsePortArgs(process.argv.slice(2), { defaultOutDir: join(homeDir(), ".cursor") });
const OUT_DIR = ARGS.project ? join(ARGS.project, ".cursor") : ARGS.outDir;
const ADAPTER = ARGS.project ? ".cursor/hooks/claude-hook-adapter.sh" : "~/.cursor/hooks/claude-hook-adapter.sh";

const STACK_DESCRIPTIONS = {
  backend: "Express 5 and TypeScript API conventions - layers, handlers, services, repositories, clients, logging, containers. Auto-attached to server source trees.",
  database: "PostgreSQL conventions - migrations, raw SQL, repositories, schema rules. Auto-attached to migrations, .sql files, database and repository trees.",
  frontend: "Shared React client conventions - components, features, state, hooks, api wrappers. Auto-attached to .tsx files and client source trees.",
  "frontend-next": "Next.js App Router conventions. Auto-attached to app/ routes and next.config.",
  "frontend-vite": "Vite and TanStack Router SPA conventions. Auto-attached to vite.config, src/main.tsx, and src/routes.",
  go: "Go net/http and chi track - layout, pgx, golangci-lint, analogs of the [ts] rules. Auto-attached to .go files and go.mod.",
  python: "Python and FastAPI track - layout, SQLAlchemy, Alembic, pytest, ruff and mypy, analogs of the [ts] rules. Auto-attached to .py files.",
  ruby: "Ruby on Rails API track - layout, RSpec, RuboCop, analogs of the [ts] rules. Auto-attached to .rb files and the Gemfile.",
  styling: "SCSS module and CSS custom property conventions. Auto-attached to .scss and .module.css files.",
};

const RULEBOOK_BLOCK_HINTS = {
  "R-0xx": "Fetch when the session-start procedure needs its full Spec.",
  "R-1xx": "Fetch before touching credentials, databases, MCP actions, or a push of ~/.claude.",
  "R-2xx": "Fetch when a conduct or output rule needs its full Spec.",
  "R-3xx": "Read before any structural or naming decision.",
  "R-4xx": "Read before designing tests - the nine test anti-patterns live here.",
  "R-5xx": "Read before commit, push, merge, or pull-request work.",
  "R-6xx": "Fetch at session end, before writing a handoff or routing a learning to memory.",
};

const TIER2_DESCRIPTIONS = {
  agents: "R-7xx Agents and Dispatch - Tier 2 rules for multi-agent sessions. Fetch when dispatching subagents, parallel worktrees, or multi-repo work (R-001).",
  audits: "R-8xx Audits - Tier 2 rules for audit sessions. Fetch when running an engineering, security, criticism, or on-request audit (R-001).",
  cost: "R-9xx Cost, Routing, and Estimation - Tier 2 rules for planning and multi-agent sessions. Fetch when tagging plan tasks, choosing a model, or estimating work (R-001).",
};

// Why a Claude Code hook has no Cursor event. A hook wired in settings.json
// that is neither in hooks.json nor listed here fails the build. A key of the
// form "<hook>@<ClaudeEvent>" covers one registration of a hook that ports
// under its other events.
const NOT_PORTED = {
  "model-switch-guard": "PreModelSwitch is a Claude Code event; Cursor selects models in its own UI.",
  "ntfy-notify@Notification": "the Notification (permission request) event is Claude Code only; the Stop registration of this hook is ported.",
  "post-compact-rules": "re-injects rules after compaction; Cursor's preCompact hook cannot inject context and there is no post-compaction event.",
  "settings-change-guard": "ConfigChange is a Claude Code event and guards settings.json, which Cursor does not read.",
  "task-commit-reminder": "fires on Claude Code's TaskUpdate tool, which Cursor lacks; R-504 depends on recall under Cursor.",
};

// --- rendering ---------------------------------------------------------------------

function marker(sourceName) {
  return generatedMarker(BUILDER, sourceName);
}

// Cursor's .mdc frontmatter is parsed loosely; a colon or a quote inside the
// description is the one thing known to break it, so neither is emitted.
function cleanDescription(text) {
  return text.replace(/\s+/g, " ").replace(/:/g, " -").replace(/"/g, "'").trim();
}

function renderRule({ description, globs = "", alwaysApply = false }, sourceName, body) {
  return [
    "---",
    `description: ${cleanDescription(description)}`,
    globs ? `globs: ${globs}` : "globs:",
    `alwaysApply: ${alwaysApply ? "true" : "false"}`,
    "---",
    marker(sourceName),
    "",
    body.trim(),
    "",
  ].join("\n");
}

function renderFrontmatterFile(fields, sourceName, body) {
  const lines = ["---"];
  for (const [key, value] of Object.entries(fields)) lines.push(`${key}: ${value}`);
  lines.push("---", marker(sourceName), "", body.trim(), "");
  return lines.join("\n");
}

function portedHooks(hooksConfig) {
  const names = new Set();
  const events = {};
  for (const [event, entries] of Object.entries(hooksConfig.hooks)) {
    for (const entry of entries) {
      const parts = entry.command.trim().split(/\s+/);
      if (parts[0] !== ADAPTER_PLACEHOLDER) throw new Error(`hooks.json: ${event} command does not start with ${ADAPTER_PLACEHOLDER}`);
      if (parts[1] !== event) throw new Error(`hooks.json: ${event} entry passes event "${parts[1]}" to the adapter`);
      for (const name of parts.slice(2)) {
        if (!existsSync(join(ROOT, "hooks", `${name}.sh`))) throw new Error(`hooks.json: ${event} names hooks/${name}.sh, which does not exist`);
        names.add(name);
        (events[name] ??= []).push(event);
      }
    }
  }
  return { names, events };
}

// --- rules -------------------------------------------------------------------------

function buildGlobalRules(ported) {
  const source = readSource("CLAUDE.md");
  const rewritten = substitute(
    source,
    [
      [
        "The trailing bracket names the enforcer: `[manual]` depends on recall; `[judge]` is the push-time LLM judge; hooks and ESLint fire mechanically.",
        "The trailing bracket names the enforcer: `[manual]` depends on recall; `[judge]` is the push-time LLM judge; hooks and ESLint fire mechanically. Under Cursor the hooks fire through `~/.cursor/hooks.json` (the adapter is `~/.cursor/hooks/claude-hook-adapter.sh`); a tag reading `hook:X in Claude Code; manual in Cursor` names a hook with no Cursor event, so that rule depends on recall here.",
      ],
      [
        "lives in `~/.claude/rulebook/reference.md`, read on demand:",
        "lives in `~/.claude/rulebook/reference.md` (under Cursor also the `rulebook-reference-*` rules, one per block), read on demand:",
      ],
      [
        currentR001Line(source),
        "R-001: Run the session-start procedure before any other work: (1) the `sessionStart` hook injects `~/.claude/global-memory/INDEX.md` and the SHA-verified `docs/session-handoff/session-handoff.md` where Cursor honors hook context; the INDEX is also the always-on `global-memory-index` rule; Read the handoff yourself when its block is absent, and verify its recorded SHA with `git cat-file -e`; (2) classify the session type per the `session-types` rule; (3) fetch that type's Tier 2 rules; (4) `git status -s ~/.claude`, triage non-empty; (5) read the project `CLAUDE.md` or `AGENTS.md`; Claude Code's per-project auto memory does not load under Cursor. First line of the response after the reads: `Session: <type> | Loaded: <files or \"core only\"> | Skipped: <files>`. Re-read and re-declare on reclassification. [manual]",
      ],
      [
        "R-502: Create tasks (`TaskCreate`) for user-visible workstreams, not inline sub-steps.",
        "R-502: Track user-visible workstreams as tasks (Cursor's task list; `TaskCreate` in Claude Code), not inline sub-steps.",
      ],
      ["a `TaskUpdate` to `completed` triggers an immediate commit", "marking a task completed triggers an immediate commit"],
      [
        "The `CLAUDE-*.md` stack convention files auto-load by path when work touches matching files. Read one directly only when planning that layer before any file is open.",
        "The `CLAUDE-*.md` stack convention files are Cursor rules with `globs`, auto-attached when work touches matching files. Fetch one directly only when planning that layer before any file is open.",
      ],
      ["| `~/.claude/rulebook/reference.md` |", "| `rulebook-reference-*` rules (`~/.claude/rulebook/reference.md`) |"],
      ["| `~/.claude/rulebook/agents.md`, `audits.md`, `cost.md` |", "| `rulebook-agents`, `rulebook-audits`, `rulebook-cost` rules (`~/.claude/rulebook/`) |"],
      ["| `/structure-conventions` (skill) |", "| `structure-conventions` rule, or the `/structure-conventions` skill |"],
      ["| `~/.claude/CLOUD-DEPLOYMENT.md` |", "| `cloud-deployment` rule (`~/.claude/CLOUD-DEPLOYMENT.md`) |"],
    ],
    "CLAUDE.md",
  );
  return renderRule(
    { description: "Global rules R-001 to R-604 - the canonical rule file for every session. Always on.", alwaysApply: true },
    "CLAUDE.md",
    annotateEnforcerTags(rewritten, ported, "Cursor"),
  );
}

function buildSessionTypes() {
  const rewritten = substitute(
    readSource("rules/session-types.md"),
    [
      [
        "Stack convention files auto-load through path-scoped symlinks in `~/.claude/rules/` when work touches matching files.",
        "Stack convention rules auto-attach through their Cursor `globs` when work touches matching files.",
      ],
      ["| agents | `~/.claude/rulebook/agents.md` |", "| agents | `rulebook-agents` rule (`~/.claude/rulebook/agents.md`) |"],
      ["| audits | `~/.claude/rulebook/audits.md` |", "| audits | `rulebook-audits` rule (`~/.claude/rulebook/audits.md`) |"],
      ["| cost | `~/.claude/rulebook/cost.md` |", "| cost | `rulebook-cost` rule (`~/.claude/rulebook/cost.md`) |"],
    ],
    "rules/session-types.md",
  );
  return renderRule(
    { description: "Session types - classify the session from the first message and load its Tier 2 rules (R-001). Always on.", alwaysApply: true },
    "rules/session-types.md",
    rewritten,
  );
}

function buildGlobalMemoryIndex() {
  const rewritten = substitute(
    readSource("global-memory/INDEX.md"),
    [
      [
        "`hooks/session-start.sh` injects this index into every session as SessionStart context (R-001, R-002), and again after every compaction.",
        "This index is an always-on Cursor rule (R-001, R-002); the `sessionStart` hook injects it a second time where Cursor honors hook context.",
      ],
      [
        "Per-project auto memory (`~/.claude/projects/<project>/memory/MEMORY.md`) loads on its own;",
        "Claude Code's per-project auto memory (`~/.claude/projects/<project>/memory/MEMORY.md`) does not load under Cursor, so Read it when the project has one;",
      ],
    ],
    "global-memory/INDEX.md",
  );
  return renderRule(
    { description: "Global memory index - cross-project feedback and efficiency lessons, loaded at every session start (R-001, R-002). Always on.", alwaysApply: true },
    "global-memory/INDEX.md",
    rewritten,
  );
}

function buildStackRules() {
  const files = {};
  for (const convention of loadStackConventions()) {
    const description = STACK_DESCRIPTIONS[convention.name];
    if (!description) throw new Error(`rules/${convention.name}.md: add a description to STACK_DESCRIPTIONS in cursor/build.mjs`);
    files[`rules/${convention.name}.mdc`] = renderRule({ description, globs: convention.paths.join(",") }, convention.sourceName, convention.body);
  }
  return files;
}

function buildRulebookReference() {
  const files = {};
  const sections = readSource("rulebook/reference.md").split(/^(?=## )/m).slice(1);
  if (sections.length === 0) throw new Error("rulebook/reference.md: no ## sections found");
  for (const section of sections) {
    const heading = section.match(/^## (.+)$/m)[1].trim();
    const block = heading.match(/\(R-(\d)xx\)/)?.[0]?.slice(1, -1);
    const title = heading.replace(/\s*\(R-\dxx\)/, "");
    const slug = block ? `${block.toLowerCase().replace("-", "")}-${title.toLowerCase().replace(/[^a-z0-9]+/g, "-")}` : heading.toLowerCase().replace(/[^a-z0-9]+/g, "-");
    const hint = block ? RULEBOOK_BLOCK_HINTS[block] ?? "" : "Fetch when choosing which convention file applies.";
    const description = block
      ? `Full Spec, Scope, and Enforcement for the ${block} rules (${title}). ${hint} Fetch whenever a norm line in the global rules is not enough to act on, or when a hook or the push judge cites one of these rules.`
      : `Rulebook reference - ${heading}. ${hint}`;
    const preface = `Source: \`~/.claude/rulebook/reference.md\`, section "${heading}". Enforcement lines describe the Claude Code harness; the Cursor port status of each hook is in \`~/.cursor/PORT-STATUS.md\`.\n\n`;
    files[`rules/rulebook-reference-${slug}.mdc`] = renderRule({ description }, "rulebook/reference.md", preface + section);
  }
  return files;
}

function buildTier2Rules() {
  const files = {};
  for (const [name, description] of Object.entries(TIER2_DESCRIPTIONS)) {
    files[`rules/rulebook-${name}.mdc`] = renderRule({ description }, `rulebook/${name}.md`, readSource(`rulebook/${name}.md`));
  }
  return files;
}

function buildStructureConventions() {
  const { frontmatter, body } = splitFrontmatter(readSource("skills/structure-conventions/SKILL.md"));
  return renderRule({ description: parseFrontmatter(frontmatter).description }, "skills/structure-conventions/SKILL.md", body);
}

function buildCloudDeployment() {
  return renderRule(
    { description: "Cloud deployment - Railway, Cloudflare, environment variables, deploy commands, and deploy-time checks. Fetch for deploy sessions or when touching environment configuration." },
    "CLOUD-DEPLOYMENT.md",
    readSource("CLOUD-DEPLOYMENT.md"),
  );
}

// --- agents, commands, skills --------------------------------------------------------

function buildAgents(agents) {
  const files = {};
  for (const agent of agents) {
    files[`agents/${agent.file}`] = renderFrontmatterFile(
      { name: agent.fields.name, description: agent.fields.description, model: "inherit", readonly: agent.writes ? "false" : "true" },
      `agents/${agent.file}`,
      agent.body,
    );
  }
  return files;
}

function buildCommands(agents) {
  const files = {
    "commands/session-start.md": [marker("CLAUDE.md (R-001)"), "", ...SESSION_START_STEPS, ""].join("\n"),
    "commands/session-handoff.md": [marker("CLAUDE.md (R-601, R-602)"), "", ...SESSION_HANDOFF_STEPS, ""].join("\n"),
  };
  for (const agent of agents) {
    files[`commands/${agent.fields.name}.md`] = [marker(`agents/${agent.fields.name}.md`), "", agentDispatchText(agent, "subagent"), ""].join("\n");
  }
  return files;
}

function buildSkills() {
  const files = {};
  for (const skill of loadSkills()) {
    files[`skills/${skill.name}/SKILL.md`] = renderFrontmatterFile({ name: skill.fields.name, description: skill.fields.description }, skill.sourceName, skill.body);
  }
  return files;
}

// --- port status ---------------------------------------------------------------------

function buildPortStatus(hooksConfig, portedEvents) {
  const { rows } = loadSettingsHookRows();
  const lines = [];
  const seen = new Set();
  const hookNames = new Set();
  for (const row of rows) {
    seen.add(row.name);
    seen.add(`${row.name}@${row.event}`);
    hookNames.add(row.name);
    let status;
    if (NOT_PORTED[`${row.name}@${row.event}`]) {
      status = `not ported: ${NOT_PORTED[`${row.name}@${row.event}`]}`;
    } else if (portedEvents[row.name]) {
      status = `ported: \`${[...new Set(portedEvents[row.name])].join("`, `")}\``;
    } else if (NOT_PORTED[row.name]) {
      status = `not ported: ${NOT_PORTED[row.name]}`;
    } else {
      throw new Error(`hooks/${row.name}.sh is wired in settings.json but is neither in cursor/hooks.json nor explained in NOT_PORTED (cursor/build.mjs)`);
    }
    lines.push(`| \`${row.name}\` | ${row.event}${row.matcher ? ` (${row.matcher})` : ""} | ${status} |`);
  }
  for (const name of Object.keys(portedEvents)) {
    if (!seen.has(name)) throw new Error(`cursor/hooks.json names hooks/${name}.sh, which settings.json does not wire; add it there first or drop it`);
  }
  for (const key of Object.keys(NOT_PORTED)) {
    if (!seen.has(key)) throw new Error(`NOT_PORTED lists ${key}, which settings.json no longer wires; remove the entry`);
    if (!key.includes("@") && portedEvents[key]) throw new Error(`NOT_PORTED lists ${key}, but cursor/hooks.json ports it; remove the entry`);
  }
  const permissionRows = [
    ["`permissions.deny` `Bash(...)`", "mirrored by the adapter on `beforeShellExecution` (deny)"],
    ["`permissions.ask` `Bash(...)`", "mirrored by the adapter on `beforeShellExecution` (ask)"],
    ["`permissions.deny` `Read(...)`", "mirrored by the adapter on `beforeReadFile` (deny)"],
    ["`permissions.allow`", "not ported: Cursor's own command allowlist governs what runs without a prompt"],
    ["`permissions.defaultMode`, `model`, `enabledPlugins`", "not ported: Claude Code runtime settings with no Cursor equivalent"],
  ].map(([layer, status]) => `| ${layer} | ${status} |`);
  return [
    marker("settings.json and cursor/hooks.json"),
    "",
    "# Cursor port status",
    "",
    `Every hook wired in \`settings.json\`, and where it runs under Cursor. ${Object.keys(portedEvents).length} of the ${hookNames.size} hooks port through the adapter across ${Object.keys(hooksConfig.hooks).length} Cursor events; the rest depend on a Claude Code event Cursor does not have. The fidelity notes for each ported event are in \`cursor/README.md\`.`,
    "",
    "## Hooks",
    "",
    "| Hook | Claude Code event | Under Cursor |",
    "|---|---|---|",
    ...lines,
    "",
    "## Permission rules",
    "",
    "| settings.json layer | Under Cursor |",
    "|---|---|",
    ...permissionRows,
    "",
  ].join("\n");
}

// --- assembly ------------------------------------------------------------------------

function buildAll() {
  const hooksSource = readSource("cursor/hooks.json");
  const hooksConfig = JSON.parse(hooksSource);
  if (hooksConfig.version !== 1) throw new Error("cursor/hooks.json: version must be 1");
  const { names: ported, events: portedEvents } = portedHooks(hooksConfig);
  const agents = loadAgents();
  const files = {
    "hooks.json": hooksSource.split(ADAPTER_PLACEHOLDER).join(ADAPTER),
    "hooks/claude-hook-adapter.sh": readSource("cursor/hooks/claude-hook-adapter.sh"),
    "rules/000-global-rules.mdc": buildGlobalRules(ported),
    "rules/001-session-types.mdc": buildSessionTypes(),
    "rules/002-global-memory-index.mdc": buildGlobalMemoryIndex(),
    ...buildStackRules(),
    ...buildRulebookReference(),
    ...buildTier2Rules(),
    "rules/structure-conventions.mdc": buildStructureConventions(),
    "rules/cloud-deployment.mdc": buildCloudDeployment(),
    ...buildAgents(agents),
    ...buildCommands(agents),
    ...buildSkills(),
    "PORT-STATUS.md": buildPortStatus(hooksConfig, portedEvents),
    "README.md": renderPortReadme({ builder: BUILDER, targetName: ARGS.project ? "<repo>/.cursor" : "~/.cursor", toolName: "Cursor", repoName: "cursor-global-rules" }),
  };
  files[".gitignore"] = renderAllowlistGitignore(Object.keys(files));
  return files;
}

runPortBuild({ builder: BUILDER, files: buildAll(), outDir: OUT_DIR, mode: ARGS.mode, force: ARGS.force });
