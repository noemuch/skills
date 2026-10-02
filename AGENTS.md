# AGENTS.md

Conventions for contributing skills to this repository. `CLAUDE.md` imports this file; put every repository fact here.

## What this repository is

A collection of agent skills distributed two ways: `npx skills add noemuch/skills` (skills CLI) and the Claude Code plugin `grounded`, served by the marketplace `noemuch` in `.claude-plugin/`. It is documentation plus a few POSIX shell scripts. There is no build.

Skills are discovered from `skills/` automatically, and plugin commands from `commands/`. Adding either needs no manifest change. A command is a thin entry point: it loads a skill's action file and adds no rule of its own.

## Naming

- Every skill is named `grounded-<domain>`: `grounded-design-system`, `grounded-tokens`, `grounded-components`. "Grounded" means the system answers instead of the agent guessing.
- The name appears in two places: the directory under `skills/` and `name` in the `SKILL.md` frontmatter. They are identical: lowercase letters, digits and single hyphens, 64 characters at most.
- Renaming a skill means changing both, then `rg -n '<old-name>'` returns nothing.

## Skill layout

```text
skills/grounded-<domain>/
├── SKILL.md       entry point, at most 150 lines
├── actions/       one file per action: purpose, inputs, steps, stop conditions, completion criteria, output format
├── references/    knowledge loaded on demand; stacks/ for per-stack mappings
├── templates/     files proposed to the user's repository, adapted before use
└── scripts/       read-only POSIX sh, deterministic output
```

- `SKILL.md` frontmatter carries `name`, `description` and `license: MIT`. `description` is at most 1024 characters, states what the skill does, then "Use when" with concrete triggers.
- `SKILL.md` holds the doctrine in a few lines, the action routing table, the hard rules and the reference map. Everything else lives one link away.
- Links from `SKILL.md` go one level deep. A reference may link a sibling reference or a template.
- Every file states its purpose in its first lines. Templates say they are templates and what to replace.

## The doctrine every skill applies to itself

- **Flag, don't invent.** A decision that belongs to the user's team (naming, deprecation, ownership, labels, exception reasons) is asked or logged, never decided by the skill.
- **Read-only by default.** An audit action writes its report only. A write action shows the diff of every existing file and waits for a yes.
- **Rules are mechanical.** Every generated rule is a binary condition, a grep-able pattern, a number or an explicit list, with the command that verifies it.
- **Evidence or silence.** Findings cite `path:line` or a command and its output.

## Writing

- English, imperative, positive: say what to do. Pair any "never" with what to do instead.
- No emojis. No em dashes or en dashes; write "0 to 10" for ranges.
- Banned in skill text and generated rules, except where a file defines the list: `appropriate`, `expected`, `consider`, `if needed`, `use your judgment`, `looks fine`.
- Concrete examples in code blocks. Neutral names: `@acme/ui`, `@acme/icons`. No company, client, product or person names.
- Sentence-case headings that carry their point.

## Checks before committing

```bash
# Frontmatter and manifests parse
node -e 'for (const f of [".claude-plugin/plugin.json", ".claude-plugin/marketplace.json"]) JSON.parse(require("fs").readFileSync(f, "utf8"))'
claude plugin validate .

# Scripts
shellcheck -s sh skills/*/scripts/*.sh skills/*/templates/hooks/*.sh

# Dashes and banned words (hits allowed only in the files that define the list)
rg -n '[\x{2013}\x{2014}]' .
rg -n -i -w -e appropriate -e expected -e consider -e 'if needed' -e 'use your judgment' -e 'looks fine' skills
```

## Versioning

Bump `version` in `.claude-plugin/plugin.json` and add a `CHANGELOG.md` entry in the same commit as any change under `skills/`. Plugin users receive updates only when the version changes.
