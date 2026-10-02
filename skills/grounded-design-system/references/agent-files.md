# Agent files

This file covers the context layer: where instructions live so every agent reads the same truth, how rules load by path, and how DESIGN.md is written for a machine. It answers the question "What am I using here?" at the entry point of every session.

## One source for every agent

Teams run several agents: Claude Code, Codex, Cursor, Copilot. Instructions written for one tool get copied to the others, the copies drift, and three tools work from three versions of the truth. Keep exactly one source.

```text
AGENTS.md            vendor-neutral, true whatever the tool
CLAUDE.md            one line: @AGENTS.md
DESIGN.md            the design language, written for agents
.agents/rules/       path-scoped rules, the only real copies
.agents/skills/      skills, the only real copies
.claude/skills/*     symlinks into .agents/skills/
.claude/rules/*      symlinks into .agents/rules/
.cursor/rules/*      symlinks into .agents/rules/
.codex/              symlinks, where the tool version supports a folder
```

Rules for the layout:

1. `AGENTS.md` holds every repository fact. `CLAUDE.md` contains `@AGENTS.md` and only Claude Code specifics, if any.
2. Real files live under `.agents/`. Tool folders contain symlinks only. Create them with relative targets so they survive a clone:

   ```bash
   mkdir -p .claude/skills
   ln -s ../../.agents/skills/ui-layout .claude/skills/ui-layout
   ```

3. A hook refuses a real directory created under `.claude/skills/`, with a message saying the other tools would never see it. See [enforcement.md](enforcement.md#agent-hooks). Without the hook, the convention erodes within weeks.
4. Each tool's folder name and rule format change between versions. Before writing symlinks, read the tool's current docs for the folder it scans. Record the version you checked in `AGENTS.md`.

Detect what exists before proposing anything. `detect-stack.sh` prints `agent-files:`. A repository with a working `.cursorrules` and nothing else keeps its content: move it into `AGENTS.md`, then symlink or point to it.

## What AGENTS.md says about UI

Keep the root file short. It routes; rules and DESIGN.md hold the detail. The UI section carries:

- Where the catalog is and the command to query it.
- The instruction to read `DESIGN.md` before writing UI code.
- The preference for system components over raw HTML, and the obligation attached to a raw element.
- The flag instruction from [doctrine.md](doctrine.md#flag-dont-invent).
- Where gaps are logged and with which label.
- The validation commands, in the order CI runs them.

[templates/AGENTS.md](../templates/AGENTS.md) is the starting point. Merge it into an existing file section by section, never replace the file.

## Path-scoped rules

An agent holding every rule at once follows none of them well. Twenty focused rules that each arrive when the agent touches matching files beat one root file that tries to say everything.

Scope each rule to the files it governs. Claude Code reads `paths` in `.claude/rules/*.md`. Cursor reads `globs` in `.cursor/rules/`. One file can carry both keys.

```markdown
---
description: Internals of library components
paths:
  - "packages/ui/src/components/**"
globs: packages/ui/src/components/**
---

# Component internals

- Every component exports its props type as `<Name>Props`.
- Variants are declared with `cva` in the same file. A variant defined with a ternary on `className` fails review.
- A new component ships with `<name>.meta.ts` beside it. `npm run registry:check` fails without it.
```

Confirm each tool loads the rule with a readiness test in that tool. Do not assume a key works because another tool reads it.

[templates/rule.md](../templates/rule.md) is the starting point.

## DESIGN.md, written for the machine

The first line addresses agents: read this before writing any UI code. The file lists every semantic token with its light value, its dark value and its usage. A value without a usage is a palette. A value with a usage is a decision.

```markdown
| Token | Light | Dark | Usage |
| --- | --- | --- | --- |
| `text-muted-foreground` | `#6B7280` | `#9CA3AF` | Secondary text: captions, metadata, helper text. Never for disabled states. |
```

Quick rules every DESIGN.md carries, adapted to the token syntax of the stack:

- Never write hex, `rgb()`, `hsl()` or `oklch()` in component code. Use a token from the tables below.
- Never use a raw palette step (`gray-500`) where a semantic token exists.
- **Match on usage, never on the nearest number.** A design value of `#6B7280` maps to the token whose usage fits, even when another token has that exact value.
- When no token fits the usage, stop and log a gap. Never write a literal.

Three answers to "secondary text", and why only the third survives a rebrand, a dark mode or a contrast fix:

```tsx
<p className="text-[#6B7280]">          // a value
<p className="text-gray-500">           // a palette step
<p className="text-muted-foreground">   // a decision
```

Generate the token tables from the token source when one exists, so DESIGN.md cannot drift from the CSS. Write the usage column by hand, from the team's answers. A usage you cannot source from the repository is a question for the team, not a sentence you write.

[templates/DESIGN.md](../templates/DESIGN.md) is the starting point.

## Lint the rules themselves

Run this on every agent file you write or audit. Each hit is a rule an agent satisfies with anything.

```bash
rg -n -i -w -e appropriate -e expected -e consider -e 'if needed' \
  -e 'use your judgment' -e 'looks fine' \
  AGENTS.md CLAUDE.md DESIGN.md .agents .claude .cursor 2>/dev/null
```

Without `rg`:

```bash
grep -rniwE 'appropriate|expected|consider|if needed|use your judgment|looks fine' \
  AGENTS.md CLAUDE.md DESIGN.md .agents .claude .cursor 2>/dev/null
```

Rewrite each hit into one of the four mechanical forms in [doctrine.md](doctrine.md#mechanical-rules). When the rewrite needs a number or a list the repository does not hold, it becomes a question for the team.

## Pitfalls

- A symlink with an absolute target breaks on every other machine. Use relative targets.
- Windows checkouts without `core.symlinks=true` turn symlinks into text files. State the setting in `AGENTS.md` when the team has Windows contributors.
- A root file over a few hundred lines is a sign rules belong in path-scoped files.
- A rule that restates what the code already shows dilutes the rules that matter. Delete it.
- Links to Figma, Notion or Slack in place of a rule mark a `disconnected` answer. Move the decision into the repository and keep the link as a source.
