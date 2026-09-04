/**
 * Builds the ESLint Node-API options shared by lint.mjs (single-file gate) and
 * ratchet.mjs (full-tree baseline). Both must activate the identical rule set,
 * or the ratchet would count violations the push gate never reports and the
 * baseline would be meaningless.
 *
 * Two rules are opt-in per repo, because both need vocabulary only the repo
 * can supply:
 *   R-303  import zones, from .enforce.json importZones
 *   R-316  the naming lexicon, from .enforce.json naming
 * A repo with neither key gets the same behavior it had before either existed.
 */
import importPlugin from "eslint-plugin-import";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import namingLexicon from "./rules/naming-lexicon.mjs";

const configPath = fileURLToPath(new URL("./eslint.config.mjs", import.meta.url));
const lexiconPath = fileURLToPath(new URL("./lexicon.json", import.meta.url));

/** Reads .enforce.json from a repo root; absent or malformed yields {}. */
function readEnforceConfig(repoRoot) {
  try {
    return JSON.parse(readFileSync(`${repoRoot}/.enforce.json`, "utf8"));
  } catch {
    return {};
  }
}

/** Resolves the R-303 import zones to absolute paths, or [] when not declared. */
function collectImportZones(enforceConfig, repoRoot) {
  if (!Array.isArray(enforceConfig.importZones) || enforceConfig.importZones.length === 0) {
    return [];
  }
  return enforceConfig.importZones.map((zone) => ({
    from: resolve(repoRoot, zone.from),
    message: zone.message,
    target: resolve(repoRoot, zone.target),
  }));
}

/**
 * Merges the shipped lexicon with the repo's naming key, or returns null when
 * the repo has not opted in. A repo list REPLACES the shipped list for that
 * field; `extend` adds to it instead, so a project can add three domain verbs
 * without restating fifty.
 */
function buildNamingOptions(enforceConfig) {
  const naming = enforceConfig.naming;
  if (!naming || naming.enabled === false) return null;

  const shipped = JSON.parse(readFileSync(lexiconPath, "utf8"));
  const extend = naming.extend ?? {};
  const merged = {};
  for (const field of ["verbs", "booleanPrefixes", "bareAdjectives", "irregularPlurals"]) {
    const base = naming[field] ?? shipped[field] ?? [];
    merged[field] = [...new Set([...base, ...(extend[field] ?? [])])].sort();
  }
  // Map-valued fields, including the layer scoping that disambiguates the read
  // synonyms. Each merges key by key, so a repo can retarget one verb without
  // restating the table.
  for (const field of ["bannedVerbs", "defaultVerbs", "scopeVerbs", "verbGroups", "verbScopes"]) {
    merged[field] = { ...(naming[field] ?? shipped[field] ?? {}), ...(extend[field] ?? {}) };
  }
  // The glossary is never shipped: it is the project's own domain vocabulary
  // (R-330). Absent means head-noun checking is skipped, not that it passes.
  merged.glossary = [...new Set([...(naming.glossary ?? []), ...(extend.glossary ?? [])])].sort();
  return merged;
}

/** ESLint options for a repo root, with the opt-in rules wired when declared. */
export function buildEslintOptions(repoRoot) {
  const enforceConfig = readEnforceConfig(repoRoot);
  const overrideConfig = [];

  const importZones = collectImportZones(enforceConfig, repoRoot);
  if (importZones.length > 0) {
    overrideConfig.push({
      files: ["**/*.ts", "**/*.tsx"],
      plugins: { import: importPlugin },
      rules: { "import/no-restricted-paths": ["error", { zones: importZones }] },
      settings: { "import/resolver": { node: { extensions: [".js", ".ts", ".tsx"] } } },
    });
  }

  const namingOptions = buildNamingOptions(enforceConfig);
  if (namingOptions) {
    overrideConfig.push({
      files: ["**/*.ts", "**/*.tsx"],
      ignores: [
        "**/__tests__/**",
        "**/__fixtures__/**",
        "**/__mocks__/**",
        "**/tests/**",
        "**/e2e/**",
        "**/*.test.ts",
        "**/*.test.tsx",
        "**/*.d.ts",
      ],
      // Namespace "lexicon", not "local": eslint.config.mjs already defines
      // "local" for one-export-per-file, and flat config refuses to redefine a
      // plugin namespace.
      plugins: { lexicon: { rules: { naming: namingLexicon } } },
      rules: { "lexicon/naming": ["error", namingOptions] },
    });
  }

  const options = { cwd: "/", overrideConfigFile: configPath };
  if (overrideConfig.length > 0) options.overrideConfig = overrideConfig;
  return options;
}
