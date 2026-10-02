---
name: grounded-design-system
description: Makes a team's design system AI-ready inside their own repository, so agents building UI read answers instead of guessing. Audits where the system is silent, sets up the context layer, catalog, enforcement and gap log one phase at a time, logs missing pieces instead of inventing around them, and runs readiness tests. Use when the user asks to make a design system AI-ready or agent-ready, audit a design system or component library for agents, write or fix AGENTS.md, CLAUDE.md or DESIGN.md for UI work, add component metadata or a registry, enforce tokens or lint rules for agents in CI, log a missing component or pattern, or test whether agents follow the design system.
license: MIT
---

# Grounded design system

This skill makes a design system answer the three questions every agent building UI asks, in the team's own repository and stack. It audits, sets up, logs gaps and tests, one action per run.

## The doctrine in eight lines

1. An agent building UI asks: **What am I using here? What am I not allowed to do? What happens when the answer does not exist?** Every artifact this skill produces answers one of the three.
2. A gap is `missing` (the decision was never made), `disconnected` (it exists where an agent cannot reach it: a Figma comment, a Slack thread, someone's head), `stale` (superseded or generated, yet the most findable answer) or `violated` (in the repository, but bypassed or unenforced). An area scores `answered` only when the repository states, keeps current and follows the decision; a probe that cannot run read-only scores `not determined`.
3. Flag, don't invent. A blocker honestly reported is a good outcome. The patch is the failure.
4. Documentation for intent, enforcement for anything expensive to get wrong. If an agent breaking a rule would take a reviewer more than a minute to catch, the rule leaves prose and moves into types, lint, tests, hooks or CI.
5. A rule is mechanical: a binary condition, a grep-able pattern, a number or an explicit list. Write down only what an agent gets wrong by default.
6. Clarity before completeness: fix 3 to 5 gaps per pass, never all of them.
7. Maturity has four levels. **Silent**: nothing answers, so the agent invents. **Guesses**: the agent reads an answer and nothing stops it ignoring it. **Obeys**: the wrong choice fails lint, types or CI. **Tells you**: the agent flags what is missing and the gap log grows. Report levels per area, as a distribution, never as one grade.
8. The team owns every decision. This skill owns the plumbing.

The full doctrine, with the vocabulary to reuse in every output, is in [references/doctrine.md](references/doctrine.md).

## Route the request

Read the first word of `$ARGUMENTS`. No argument means `audit`.

| Action | Invocation | Writes | Load |
| --- | --- | --- | --- |
| `audit` | `audit` | `design-system-audit.md` only | [actions/audit.md](actions/audit.md) |
| `setup` | `setup week1`, `setup week2`, `setup week3` | Files for one phase, after approval | [actions/setup.md](actions/setup.md) |
| `gap` | `gap <what is missing>` | One issue or one `GAPS.md` line | [actions/gap.md](actions/gap.md) |
| `test` | `test <area>`, or the plugin command `/readiness-check` | A readiness report | [actions/test.md](actions/test.md) |

Load the action file before taking any step. Load a reference only when the action file names it.

`setup` with no phase: read `design-system-audit.md` at the repository root. If it exists, propose the earliest phase whose areas it scores below `answered`, using the Phase column of the area table in [actions/audit.md](actions/audit.md#areas-and-probes). If it does not exist, run `audit` first and stop.

An agent working on UI in a repository that already uses this skill invokes `gap` on its own the moment it reaches for a raw element or an unknown value. That is the intended use.

## Hard rules

1. **Ask or log every team decision.** Token names, deprecations, ownership, the canonical component among duplicates, the themes in scope, which agents the repository serves, the gap label, the exception marker, CI provider choices and exception reasons belong to the team. When the repository does not state one, write it as a question in the output, or log it with `gap`. Never pick one. Templates carry placeholders (`<gap-label>`, `<exception-marker>`) for these; fill them with the team's answer, never with a default.
2. **`audit` is read-only, and scopes first.** It settles whether the repository is an app, a library that is the design system, or both, and which agents work there, before scoring anything. It writes `design-system-audit.md` and nothing else, and runs the bundled scripts and read-only commands only.
3. **Show the diff before touching an existing file.** Present the unified diff, wait for an explicit yes, then write. A new file is listed with its full path and purpose before it is created.
4. **The team's conventions win.** When the repository already has a working equivalent of a template (a registry, a lint rule, a gap list), extend it in its own format. Name the template you did not use and why.
5. **Every generated rule is checkable.** Each rule names its condition, pattern, number or list, and the command that verifies it. Generated text never contains `appropriate`, `expected`, `consider`, `if needed`, `use your judgment` or `looks fine`. Run the check in [references/agent-files.md](references/agent-files.md#lint-the-rules-themselves) before showing any agent file.
6. **One phase per `setup` run.** Finish the phase, run its readiness test, report, stop. The next phase starts on a new human request.
7. **Never build a workaround for a gap.** `gap` records the need. It does not create a component, a token or a style.
8. **Evidence or silence.** Every finding cites `path:line` or the command and its output. Without evidence, write `not determined` and add a question for the team.

## Scripts

Run from this skill's directory. In Claude Code the directory is `${CLAUDE_SKILL_DIR}`.

```bash
sh scripts/detect-stack.sh /path/to/repo      # inventory: repository kind, styling, tokens, themes, generated output, lint, CI, agent files, hooks
sh scripts/count-hardcoded.sh /path/to/repo   # hardcoded values per directory, usage apart from token definitions, repeated values
sh scripts/component-usage.sh /path/to/repo   # importers per component, raw elements, repeated class strings
```

All three are read-only, share one file universe (`scripts/lib.sh`: vendored trees, build output and generated files excluded), print plain text and exit 0 on any directory; they exit 2 only when the path is not a directory. Set `DS_GENERATED`, `DS_TOKEN_SOURCES` or `DS_EXCLUDE` when the repository needs it, and `DS_OFFLINE=1` to skip `gh`. Their output is evidence to quote, not a verdict. When a line contradicts the files, trust the files, cite them, and record the script line and the correction in the report.

## Pick the stack reference

`detect-stack.sh` prints `stack-refs:`, the reference files that apply: `tailwind-shadcn`, `radix`, `base-ui`, `storybook`, `css-in-js`, `sass`, `figma-variables`, `style-dictionary`, and `css-only` when no styling reference matched. Load each one listed, from [references/stacks/](references/stacks/). A repository can match several.

## Reference map

| File | Load when |
| --- | --- |
| [doctrine.md](references/doctrine.md) | Writing any report, rule or message; scores, levels, the two kinds of agent |
| [agent-files.md](references/agent-files.md) | Auditing or writing AGENTS.md, CLAUDE.md, rules, skills, DESIGN.md |
| [catalog.md](references/catalog.md) | Component metadata, status, registry, examples |
| [tokens.md](references/tokens.md) | Token layers, DESIGN.md token tables, contract tests |
| [enforcement.md](references/enforcement.md) | Palette audit, lint messages, exception allowlists, hooks |
| [change-types.md](references/change-types.md) | CI gate, change types, blast radius, visual regression, changelog |
| [readiness-tests.md](references/readiness-tests.md) | `test`, and the last step of every `setup` phase |

Templates in [templates/](templates/) are starting points. Adapt names, paths and commands to the detected stack before proposing them.

## Before you finish

| Check | Pass condition |
| --- | --- |
| Questions surfaced | Every team decision you met is a question or a logged gap, not an answer |
| Evidence | Every finding has `path:line` or a command with its output |
| Scope | The output names 3 to 5 gaps, ranked, and lists the rest as deferred |
| Rule wording | The banned-word check in [agent-files.md](references/agent-files.md#lint-the-rules-themselves) prints `no hits` on generated files |
| Writes | `audit` wrote one file. `setup` wrote only approved files. `gap` wrote one line or one issue |
