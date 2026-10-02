# Action: audit

Purpose: score where the design system is silent for an agent, with evidence, and name the 3 to 5 gaps worth closing first. This is the default action. It is read-only: it writes `design-system-audit.md` at the repository root and nothing else.

## Inputs

- The repository root. Default: the current working directory's git toplevel (`git rev-parse --show-toplevel`).
- Optional: a sub-path to scope the audit, for monorepos (`audit packages/ui`).

## Steps

1. Load [references/doctrine.md](../references/doctrine.md). Every finding uses its vocabulary: the six scores, the four gap classes and the four levels.
2. Run the inventory from this skill's directory and keep the raw output for the report appendix:

   ```bash
   sh scripts/detect-stack.sh "$ROOT"
   sh scripts/count-hardcoded.sh "$ROOT"
   sh scripts/component-usage.sh "$ROOT"     # add the UI directory as a second argument when the script cannot find it
   ```

3. Scope the audit before scoring anything. See [Scope](#scope) below. Ask the user what the inventory cannot settle, and wait for the answer.
4. Load each file listed in `stack-refs:` from [references/stacks/](../references/stacks/).
5. Read the agent files listed in `agent-files:`, in full. Run the banned-word check from [references/agent-files.md](../references/agent-files.md#lint-the-rules-themselves) on them and keep each hit with `path:line`.
6. Score each area in the table below. For each one, run its probe, read the files it points to, and assign exactly one score from [doctrine.md](../references/doctrine.md#scores-and-gap-classes): `answered`, `missing`, `disconnected`, `stale`, `violated` or `not determined`. Cite `path:line` or the command and its output for every score.
7. For each area, record the level it reaches: `silent`, `guesses`, `obeys` or `tells you`, per [doctrine.md](../references/doctrine.md#maturity-levels).
8. List every team decision you met that the repository does not state. Each becomes a question in the report. Use the list in [doctrine.md](../references/doctrine.md#flag-dont-invent).
9. Rank the areas not scored `answered` with the two scales in [doctrine.md](../references/doctrine.md#clarity-before-completeness). Keep the top 3 to 5. Name the rest under "Deferred".
10. For each top gap, name the phase that closes it from the Phase column below. A gap that needs a team decision before any file changes says `team decision`, then the phase.
11. When a script line contradicts the files, trust the files: score from them, cite them, and record the script line and the correction under "Verified corrections" in the appendix.
12. Write `design-system-audit.md` in the format below. Show the user the summary, the top gaps and the questions.

## Scope

Read `repo-kind:`, `package:`, `archived-notice:` and `gh-cli:` from the inventory, then settle three things:

| Settle | From | Ask when |
| --- | --- | --- |
| What the repository is: an **app** that consumes a design system (held in the repository or installed from a package), a **library** that is the design system and publishes it, or a **monorepo** with both | `repo-kind:`, `package:` lines (published, app framework, what ships) | `repo-kind: undetermined`, or a published package that may not be the design system |
| Which agents work here: **contributor agents** (editing the system), **consumer agents** (building with it), or both | The kind above; the README's audience | Always for a library or a monorepo: consumer agents of a library live in other repositories |
| Where their agent files must live | The table in [doctrine.md](../references/doctrine.md#two-kinds-of-agent); for a library, the `ships` part of `package:` | The package ships no README or guidance file, and nothing says whether it should |

Write the result as the `Scope:` line of the report. When the user cannot answer now, state the working assumption in that line and make it question 1.

Adapt the probes to the scope:

- **Library**: area 1 also checks whether consumer guidance ships (`files` in `package.json`, README, types, doc comments). Area 6 reads source directories, never the token directories beside them. Area 14 measures blast radius on the variant matrix (themes, builds, entry points) and on external consumers, since `rg -l` inside the repository counts internal composition only. The stale probe "more imports than its replacement" does not apply to external usage.
- **App**: probes as written.
- **Monorepo**: score the package and the app separately when their answers differ, and say which one each evidence line belongs to.

## Areas and probes

The Question column names which of the three questions the area answers: Using (What am I using here?), Not allowed (What am I not allowed to do?), Doesn't exist (What happens when the answer doesn't exist?). The Phase column names the `setup` phase that closes the area; [setup.md](setup.md) reads the same column.

| # | Area | Question | Phase | Probe | Answered when |
| --- | --- | --- | --- | --- | --- |
| 1 | Agent entry point | Using | week1 | `agent-files:`; for a library, the `ships` part of `package:` | One vendor-neutral source for the agents in scope; tool files import or link it; consumer guidance ships when consumers are in scope |
| 2 | Rule scoping | Using | week1 | `.agents/rules`, `.claude/rules`, `.cursor/rules`, frontmatter `paths` or `globs` | UI rules load by path, not all at once from the root |
| 3 | Rule wording | Not allowed | week1 | Banned-word check from step 5 | Agent files exist, the check finds zero hits, and each UI rule is a condition, pattern, number or list. No agent file: the check prints `no agent files`, and the area is `missing`, not a pass |
| 4 | Design language | Using | week1 | `DESIGN.md`, docs pages, token source, `themes:` | Every semantic token has a value in each theme the system defines and a usage, readable in the repository. Rendered contrast: `not determined`, it needs a render |
| 5 | Token layer | Using | week2 | `token-source:` and `tokens-*:` lines | One source, and components read semantic tokens. Components bypassing a real layer: `violated`, with the bypass count |
| 6 | Hardcoded values | Not allowed | week2 | `count-hardcoded.sh` usage columns per directory, repeated values | Directories holding component or style source at zero usage, or each hit carries the team's exception marker. Token sources, generated files and files rendered outside the DOM are reported apart |
| 7 | Catalog | Using | week1 | `catalog:`, sidecars, story `component` and `parameters`, autodocs, `registry.json`, a module map | Each component has name, type, usage and status in a machine-readable file |
| 8 | Registry in CI | Not allowed | week2 | CI files for a regeneration plus `git diff --exit-code`, on the registry and on committed build output | A component without metadata fails CI, and committed output that differs from its source fails CI |
| 9 | Lint and types for agents | Not allowed | week2 | `lint:`, `lint-plugins:`, `lint-design-rules:`, restricted imports and syntax with their `message` text, closed union prop types | Messages say what to use instead and where to log a gap. An installed design rule left `off`: `violated` |
| 10 | Exceptions | Not allowed | week2 | `eslint-disable`, `stylelint-disable`, `biome-ignore` counts; allowlist tests | Exceptions live in a test with a reason per entry |
| 11 | Agent hooks | Not allowed | week2 | `hooks:`; `.claude/settings.json`; versioned git hooks; CI | Edits to generated files, `--no-verify` and commits on a protected branch are refused with a fix, by any versioned mechanism. `.git/hooks` is local and does not count. Committing tool-specific hook files is a team decision; ask it |
| 12 | Gap logging | Doesn't exist | week3 | `design-files:`; the gap label from `gh label list` when `gh-cli:` shows access | Agents are told to log, and a log exists with entries |
| 13 | CI gate | Not allowed | week2 | `ci:`, `ci-design-gates:`, branch protection from `gh-cli:` | At least one design-system check runs on pull requests and the default branch is protected. A check that runs without protection: `violated` |
| 14 | Change discipline | Not allowed | week3 | PR templates, spec folders, change-type labels; blast radius per [Scope](#scope) | Change types declared and checked; blast radius sets evidence |
| 15 | Consistency | Using | week1, then week2 | `component-usage.sh` (importers per component, raw elements, repeated class strings, semantic utilities beside palette steps); repeated values from `count-hardcoded.sh`; one search per intent (`rg -n -e danger -e destructive -e error <ui dirs>`) | Each intent has one form in code, or the repository documents the alternatives with when to use each. A documented canonical form that code mixes with others: `violated`. No canonical form stated: `missing` plus a question |

Score `disconnected` when the probe finds a pointer instead of an answer: a Figma, Notion, Slack, wiki or docs-site URL in place of a rule, `// ask design`, "see the design team".

Score `stale` when the probe finds two answers and the wrong one is easier to find: a deprecated component with more imports than its replacement (count with `rg -l`), a README naming a token absent from the token source, a token whose name hits compiled output and misses its source (`rg -l -e '<token name>'`, then compare hits in the source directory and the output directory). To tell which of two answers is older, read `git log -1 --format=%cs -- <path>`.

Probes for areas outside the repository (issue labels, branch protection) need `gh` with access to this repository. `gh-cli:` prints the permission. With `READ` on an upstream, labels and protection belong to the upstream's owners: say so in the evidence. Without access, score the area `not determined` and add a question.

When the inventory shows no agent files, no CI and no tests, write one `Baseline:` line in the report naming what is absent and the areas it decides, and cite `baseline` in those rows instead of repeating the same fact.

## Stop conditions

- The path is not a directory, or holds no source file at all: stop and ask for the root.
- `detect-stack.sh` reports `ui-code: none` (no component, markup or style file of any kind): stop. Report that no UI code was found and ask where it lives.
- `archived-notice:` is not `none`, or `gh-cli:` shows `archived true`: stop before scoring and ask whether the audit should run, quoting the line.
- A probe requires writing a file, installing a package or running the project's build: skip it, score `not determined`, and list the command for the team to run.

## Completion criteria

The audit is complete when all of these hold:

- `design-system-audit.md` exists and is the only file this run created or changed (`git status --porcelain` shows only that path, or what was already there before the run).
- The `Scope:` line names the kind, the agents served and where their files live, or an assumption that question 1 asks about.
- All 15 areas have a score, a level and at least one evidence line. A `not determined` score carries a question or a command for the team.
- No area with nothing to evaluate is scored `answered`.
- The top gaps list holds 3 to 5 entries, each with class, evidence, rank on both scales and the phase that closes it.
- The questions list holds every team decision met, and none of them is answered in the report.
- The raw output of the three scripts is in the appendix, with every correction listed under "Verified corrections".

## Output format

```markdown
# Design system audit

Repository: <name> at <commit sha>, <date>
Scope: <app | library | app and library>; agents served: <contributors | consumers | both>; agent files live in: <paths>
Stack: <one line from detect-stack.sh>
Levels: silent <n>, guesses <n>, obeys <n>, tells you <n>. Using: <n per level>. Not allowed: <n per level>. Doesn't exist: <n per level>
Baseline: <absent infrastructure and the areas it decides, or omit the line>

## Top gaps

The rank is a judgment on two scales; reorder it if the team weighs them differently.

| Rank | Gap | Class | Question | Frequency x cost | Evidence | Closed by |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | No usage for semantic tokens | missing | Using | 3 x 3 | `app/globals.css:12-48` defines 31 tokens, no usage text anywhere | team decision, then `setup week1` |

## Areas

| # | Area | Score | Level | Evidence |
| --- | --- | --- | --- | --- |
| 1 | Agent entry point | answered | guesses | `CLAUDE.md:1` is `@AGENTS.md` |

## Questions only the team can answer

1. `Modal` (42 importers) and `Dialog` (17 importers) both wrap the same primitive. Which one is canonical, and is the other `deprecated`?

## Deferred

- <area or gap>, <one-line reason it ranks below the top gaps>

## Appendix: inventory

<raw detect-stack.sh output>
<raw count-hardcoded.sh output>
<raw component-usage.sh output>

### Verified corrections

- `<script>: <line>`: says <what>; the files say <what>, `path:line`
```
