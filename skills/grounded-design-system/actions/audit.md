# Action: audit

Purpose: score where the design system is silent for an agent, with evidence, and name the 3 to 5 gaps worth closing first. This is the default action. It is read-only: it writes `design-system-audit.md` at the repository root and nothing else.

## Inputs

- The repository root. Default: the current working directory's git toplevel (`git rev-parse --show-toplevel`).
- Optional: a sub-path to scope the audit, for monorepos (`audit packages/ui`).

## Steps

1. Load [references/doctrine.md](../references/doctrine.md). Every finding uses its vocabulary.
2. Run the inventory from this skill's directory and keep the raw output for the report appendix:

   ```bash
   sh scripts/detect-stack.sh "$ROOT"
   sh scripts/count-hardcoded.sh "$ROOT"
   ```

3. Load each file listed in `stack-refs:` from [references/stacks/](../references/stacks/).
4. Read the agent files listed in `agent-files:`, in full. Run the banned-word check from [references/agent-files.md](../references/agent-files.md#lint-the-rules-themselves) on them and keep each hit with `path:line`.
5. Score each area in the table below. For each one, run its probe, read the files it points to, and assign exactly one score: `answered`, `missing`, `disconnected` or `stale`. Cite `path:line` or the command and its output for every score.
6. For each area, record the maturity level it reaches: `guesses`, `obeys` or `tells you`.
7. List every team decision you met that the repository does not state. Each becomes a question in the report. Use the list in [doctrine.md](../references/doctrine.md#flag-dont-invent).
8. Rank the non-`answered` areas by cost of a wrong answer times how often an agent asks the question. Keep the top 3 to 5. Name the rest under "Deferred".
9. Map each top gap to the `setup` phase that closes it.
10. Write `design-system-audit.md` in the format below. Show the user the summary, the top gaps and the questions.

## Areas and probes

The Question column names which of the three questions the area answers: Using (What am I using here?), Not allowed (What am I not allowed to do?), Doesn't exist (What happens when the answer doesn't exist?).

| # | Area | Question | Probe | Answered when |
| --- | --- | --- | --- | --- |
| 1 | Agent entry point | Using | `AGENTS.md`, `CLAUDE.md`, tool folders from `agent-files:` | One vendor-neutral source; tool files import or link it |
| 2 | Rule scoping | Using | `.agents/rules`, `.claude/rules`, `.cursor/rules`, frontmatter `paths` or `globs` | UI rules load by path, not all at once from the root |
| 3 | Rule wording | Not allowed | Banned-word check from step 4 | Zero hits, and each UI rule is a condition, pattern, number or list |
| 4 | Design language | Using | `DESIGN.md`, docs pages, token source | Every semantic token has light value, dark value and usage, readable in the repository |
| 5 | Token layer | Using | `token-source:` from the inventory | One source; components read semantic tokens |
| 6 | Hardcoded values | Not allowed | `count-hardcoded.sh` per directory | Component directories at zero, or each hit carries a reason comment |
| 7 | Catalog | Using | `catalog:` from the inventory, sidecars, story `parameters`, `registry.json` | Each component has name, type, usage, status in a machine-readable file |
| 8 | Registry in CI | Not allowed | CI files for a regen plus `git diff --exit-code` | A component without metadata fails CI |
| 9 | Lint for agents | Not allowed | Lint config: restricted imports and syntax, their `message` text | Messages say what to use instead and where to log a gap |
| 10 | Exceptions | Not allowed | `eslint-disable`, `stylelint-disable`, `biome-ignore` counts; allowlist tests | Exceptions live in a test with a reason per entry |
| 11 | Agent hooks | Not allowed | `.claude/settings.json` hooks, versioned git hooks (`.husky`, `lefthook.yml`); `.git/hooks` is local and does not count | Generated files, `--no-verify` and commits on main are refused with a fix |
| 12 | Gap logging | Doesn't exist | `GAPS.md`, a gaps section in the UI README, issue labels (`gh label list` when `gh` is authenticated) | Agents are told to log, and a log exists with entries |
| 13 | CI gate | Not allowed | Workflows: lint with zero warnings, visual regression, changelog check | At least one design-system check blocks merge |
| 14 | Change discipline | Not allowed | PR templates, spec folders, change-type labels, consumer counting | Change types declared and checked; blast radius sets evidence |

Score `disconnected` when the probe finds a pointer instead of an answer: a Figma, Notion, Slack or wiki URL in place of a rule, `// ask design`, "see the design team". Score `stale` when the probe finds two answers and the older one is easier to find: a deprecated component with more imports than its replacement (count with `rg -l`), a README naming a token absent from the token source.

Probes for areas outside the repository (issue labels, branch protection) need `gh`. When `gh` is missing or unauthenticated, score the area `not determined` and add a question.

## Stop conditions

- The path is not a repository and has no `package.json`: stop and ask for the root.
- `detect-stack.sh` reports `ui-code: none`: stop. Report that no UI code was found and ask where it lives.
- A probe requires writing a file, installing a package or running the project's build: skip it, score `not determined`, and list the command for the team to run.

## Completion criteria

The audit is complete when all of these hold:

- `design-system-audit.md` exists and is the only file this run created or changed (`git status --porcelain` shows only that path, or what was already there before the run).
- All 14 areas have a score, a maturity level and at least one evidence line, or `not determined` with a question.
- The top gaps list holds 3 to 5 entries, each with class, evidence and the `setup` phase that closes it.
- The questions list holds every team decision met, and none of them is answered in the report.
- The raw output of both scripts is in the appendix.

## Output format

```markdown
# Design system audit

Repository: <name> at <commit sha>, <date>
Stack: <one line from detect-stack.sh>
Overall: guesses | obeys | tells you (the lowest level reached by areas 1, 7, 9 and 12)

## Top gaps

| Rank | Gap | Class | Question | Evidence | Closed by |
| --- | --- | --- | --- | --- | --- |
| 1 | No usage for semantic tokens | missing | Using | `app/globals.css:12-48` defines 31 tokens, no usage text anywhere | `setup week1` |

## Areas

| # | Area | Score | Level | Evidence |
| --- | --- | --- | --- | --- |
| 1 | Agent entry point | answered | obeys | `CLAUDE.md:1` is `@AGENTS.md` |

## Questions only the team can answer

1. `Modal` (42 imports) and `Dialog` (17 imports) both wrap the same primitive. Which one is canonical, and is the other `deprecated`?

## Deferred

- <area or gap>, <one-line reason it ranks below the top gaps>

## Appendix: inventory

<raw detect-stack.sh output>
<raw count-hardcoded.sh output>
```
