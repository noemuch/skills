# Doctrine

This file holds the principles every action applies and the vocabulary every output reuses. Read it before writing a report, a rule or a message. It implements the article "Make your design system AI-ready" (https://noechague.com/writing/make-your-design-system-ai-ready).

## The three questions

An agent building interface asks three questions, in this order:

| Question | What answers it | Where it lives |
| --- | --- | --- |
| What am I using here? | Agent files, DESIGN.md, a queryable catalog | `AGENTS.md`, `DESIGN.md`, metadata sidecars, registry |
| What am I not allowed to do? | Semantic tokens, lint, types, tests, hooks, CI | Config and test files, never prose alone |
| What happens when the answer doesn't exist? | A flag instruction, a gap log, an issue label, the gap loop | Root instructions, `GAPS.md`, the issue tracker |

Most systems answer the first partially, in a docs site written for people. Few answer the second in a form a machine has to respect. Almost none answer the third, so the agent improvises. Tag every finding, rule and template with the question it answers.

## Two kinds of agent

A **contributor agent** edits the design system itself: its tokens, its components, its build. A **consumer agent** builds interface with it, in the same repository (an app that holds its system) or in another one (an app that installs a published package).

| Repository | Contributor agents read | Consumer agents read |
| --- | --- | --- |
| App holding its own system | Root `AGENTS.md`, rules scoped to the system's directories | The same root files |
| Library publishing the system | Root `AGENTS.md` and rules, in the repository | Only what the package ships: README, types, doc comments, and any file the package's `files` field lists |
| Monorepo with both | Root `AGENTS.md`, nested `AGENTS.md` in the package | The app's files in the repository; what the package ships everywhere else |

A guidance file at the root of a library never reaches a consumer in another repository unless the package ships it. Which agents a repository serves is a team decision; the audit asks it before scoring anything.

## Scores and gap classes

Score every audited area, and classify every gap, with exactly one of these words:

| Score | Meaning | Evidence |
| --- | --- | --- |
| **answered** | The repository states the decision where an agent reads it, the statement is current, and the code follows it | The file and line that state it, and a count showing the code follows it |
| **missing** | The decision was never made, or there is nothing to evaluate: no rule file means rule wording is `missing`, never answered by default | A search that returns nothing, a raw element where a component would sit, an arbitrary value with no token |
| **disconnected** | The decision exists where an agent cannot reach it: a Figma comment, a Slack thread, a Notion page, a hosted docs site, someone's head | A link to an external tool in place of a rule, a comment like `// ask design`, a team member's answer to an audit question |
| **stale** | The most findable answer is not the current source: it was superseded, or it is a generated copy that outranks its source | A deprecated component with more imports than its replacement, a README naming a removed token, a token name with 236 hits in compiled CSS and 0 in the source |
| **violated** | The decision is in the repository and reachable, but code does not follow it, or nothing enforces it where an agent breaking it costs a reviewer more than a minute | 19 raw palette steps beside a semantic token layer; a lint plugin installed with its design rule off; a CI check that runs without branch protection |
| **not determined** | The probe cannot run read-only: it needs repository access, a build, a render or an admin | The command for the team to run, and a question |

`missing`, `disconnected`, `stale` and `violated` are the four gap classes. `answered` and `not determined` are scores only.

Score an enforcement area on its mechanism. `answered`: a mechanism exists and blocks. `violated`: the rule exists in prose or config, but it is off, a warning nobody fails on, or not wired to a gate. `missing`: no rule exists anywhere.

The fix differs per class. Missing needs a team decision. Disconnected needs the decision moved into the repository. Stale needs the old answer removed or marked `deprecated`, or the generated copy guarded, so the current source is the most findable. Violated needs enforcement, or a migration of the code that bypasses the decision.

## Flag, don't invent

When the system has no answer, the agent says so instead of producing the most plausible answer. Plausible is the failure: a wrong answer that looks right ships.

This skill applies the rule to itself. These decisions belong to the team, and the skill asks or logs them, never decides them:

- Token names, token values, and which token a value maps to
- Which component is canonical when two implement the same thing, and which form is canonical when one intent is written several ways
- What is deprecated, and what replaces it
- Who owns a component, a token file or a rule
- Which themes are in scope
- Which agents the repository serves (contributors to the system, consumers of it) and where their files live
- Issue labels, gap index location, CI provider and branch protection
- The exception marker and the reason attached to an exception

A literal equal to a token value is evidence, written as an equality (`#37D5D3` = `color.seafoam`). It is never a mapping: the usage decides the token, and the team decides the usage. A literal close to a token value is not reported as a match.

Write the root instruction for the team's repository in two sentences:

```markdown
When the design system has no component, token or pattern for what you need, flag it with a gap entry instead of building around it. A blocker honestly reported is a good outcome; the patch is the failure.
```

## Documentation or enforcement

Documentation states intent. Enforcement holds when the agent did not read, misread or decided it knew better. Place every rule with one test:

> If an agent breaking it would take a reviewer more than a minute to catch, it does not belong in prose.

| Rule | Reviewer time to catch | Home |
| --- | --- | --- |
| "Use `Card` for grouped content" | Seconds, it is visible in the diff | Prose in a path-scoped rule |
| "No hex colors in components" | Minutes across a large diff | Palette audit in CI |
| "Status colors alias the right scale in every theme" | Requires running each theme | Token contract test |
| "Never edit `registry.json` by hand" | Invisible until the next regen | Hook plus CI diff |

## Mechanical rules

A rule resolves to one of four forms. Anything else is a conversation the team has not finished.

| Form | Example |
| --- | --- |
| Binary condition | "A component file without a sibling `.meta.ts` fails CI." |
| Grep-able pattern | "`rg 'text-\[#' src/` returns nothing." |
| Number | "Dialogs are at most `max-w-lg`." |
| Explicit list | "Icons come from `@acme/icons`. `lucide-react` and `react-icons` are refused." |

Banned in any generated rule: `appropriate`, `expected`, `consider`, `if needed`, `use your judgment`, `looks fine`. Each one is satisfied by anything, so the agent complies with the letter and misses the intent.

Rewrite, do not delete:

| Paraphrasable | Mechanical |
| --- | --- |
| Use appropriate spacing. | Spacing uses the `gap-*` and `p-*` steps 1, 2, 3, 4, 6, 8. Arbitrary spacing fails lint. |
| Consider using the design system button. | Use `Button` from `@acme/ui`. A raw `<button>` requires a gap entry. |
| Make sure it looks fine in every theme. | Every new component has one snapshot per theme in `e2e/__snapshots__`. |

Write only what the agent gets wrong by default. Anything it learns by reading the code costs context and dilutes the rules that matter. Test a candidate rule: delete it, run the readiness test, and keep it only if the output gets worse.

## Clarity before completeness

Pick 3 to 5 gaps per pass. Rank them on two scales and multiply:

| Scale | 3 | 2 | 1 |
| --- | --- | --- | --- |
| Frequency: how often an agent meets the question | Every UI change (secondary text color, spacing) | Every component of one kind (form fields, dialogs) | One screen or one pattern (a chart legend) |
| Cost: what a wrong answer does | Ships to users unnoticed | Caught in review | Cosmetic, caught at a glance |

Break ties with the evidence count: the number of files the gap touches. The rank is a judgment; say so in the report and let the team reorder it. Defer the rest by name, so nothing is lost and nothing dilutes the pass.

## Maturity levels

| Level | Agent behavior at a gap | Signal in the repository |
| --- | --- | --- |
| Silent | Nothing answers the question, so the agent invents | No file an agent reads holds the answer: the area scores `missing` or `disconnected` |
| Guesses | Reads an answer, and nothing stops it ignoring one | Docs, conventions or code examples exist; no blocking check. Typical of `answered` documentation areas and of `violated` or `stale` ones |
| Obeys | The wrong choice fails types, lint, tests, hooks or CI | Palette audit, restricted imports, closed union types, contract tests, a merge-blocking check |
| Tells you | Flags what is missing instead of inventing it | A flag instruction, and a gap log that agents write to |

`silent` is the same word the readiness test uses for a system that does not answer, on purpose: both describe what the agent finds.

The levels describe a status, not a grade. A repository can obey on tokens and stay silent on layout. Report the level per area, and report the whole as a distribution: how many areas sit at each level, per question. Never collapse it into one word.

## The gap loop

A flagged gap is worth something only when it closes. Every gap takes the same six steps:

```text
Missing -> Flag -> Issue -> Build -> Vizreg -> Changelog
```

Missing: an agent hits a case the system does not cover. Flag: it says so instead of improvising. Issue: the gap becomes a tracked request carrying the screen that needed it. Build: the component is built once, in the library, with its metadata. Vizreg: visual regression proves nothing else moved. Changelog: the change is recorded with its reason on the component's page.

## Words to reuse

Use these terms verbatim in reports and generated files: `answered`, `missing`, `disconnected`, `stale`, `violated`, `not determined`, `silent`, `guesses`, `obeys`, `tells you`, `flag`, `gap`, `gap index`, `gap label`, `exception marker`, `blast radius`, `create`, `refine`, `extend`, `refactor`, `readiness test`, `contributor agent`, `consumer agent`.
