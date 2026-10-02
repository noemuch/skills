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

## Gap classes

Classify every gap as exactly one of three:

- **missing**: the decision was never made. Nothing in the repository or outside it states it. Evidence: a search that returns nothing, a raw element where a component would sit, an arbitrary value with no token.
- **disconnected**: the decision exists where an agent cannot reach it. A Figma comment, a Slack thread, a Notion page, a ticket, someone's head. Evidence: a link to an external tool in place of a rule, a comment like `// ask design`, a team member's answer to an audit question.
- **stale**: the decision was superseded, yet the old version is still the most findable answer. Evidence: a deprecated component with more imports than its replacement, a README that names a removed token, two docs pages that disagree.

An area with an in-repository, reachable, current answer scores **answered**.

The fix differs per class. Missing needs a team decision. Disconnected needs the decision moved into the repository. Stale needs the old answer removed or marked `deprecated`, so the current one is the most findable.

## Flag, don't invent

When the system has no answer, the agent says so instead of producing the most plausible answer. Plausible is the failure: a wrong answer that looks right ships.

This skill applies the rule to itself. These decisions belong to the team, and the skill asks or logs them, never decides them:

- Token names, token values, and which token a value maps to
- Which component is canonical when two implement the same thing
- What is deprecated, and what replaces it
- Who owns a component, a token file or a rule
- Issue labels, gap index location, CI provider and branch protection
- The reason attached to an exception

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
| "Status colors alias the right scale in dark mode" | Requires running both themes | Token contract test |
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
| Make sure it looks fine in dark mode. | Every new component has a dark snapshot in `e2e/__snapshots__`. |

Write only what the agent gets wrong by default. Anything it learns by reading the code costs context and dilutes the rules that matter. Test a candidate rule: delete it, run the readiness test, and keep it only if the output gets worse.

## Clarity before completeness

Pick 3 to 5 gaps per pass. Rank by cost of a wrong answer times frequency of the question. A gap every screen hits (secondary text color) beats a gap one screen hits (a chart legend). Defer the rest by name, so nothing is lost and nothing dilutes the pass.

## Maturity levels

| Level | Agent behavior at a gap | Signal in the repository |
| --- | --- | --- |
| Guesses | Finds the right component, nothing stops it ignoring one | Docs exist, no blocking check |
| Obeys | The wrong choice fails lint, types or CI | Palette audit, restricted imports, contract tests, a merge-blocking check |
| Tells you | Flags what is missing instead of inventing it | A gap log that agents write to, issues labeled for the system |

The levels describe a status, not a grade. A repository can obey on tokens and guess on layout. Report the level per area.

## The gap loop

A flagged gap is worth something only when it closes. Every gap takes the same six steps:

```text
Missing -> Flag -> Issue -> Build -> Vizreg -> Changelog
```

Missing: an agent hits a case the system does not cover. Flag: it says so instead of improvising. Issue: the gap becomes a tracked request carrying the screen that needed it. Build: the component is built once, in the library, with its metadata. Vizreg: visual regression proves nothing else moved. Changelog: the change is recorded with its reason on the component's page.

## Words to reuse

Use these terms verbatim in reports and generated files: `missing`, `disconnected`, `stale`, `answered`, `guesses`, `obeys`, `tells you`, `flag`, `gap`, `gap index`, `blast radius`, `create`, `refine`, `extend`, `refactor`, `readiness test`.
