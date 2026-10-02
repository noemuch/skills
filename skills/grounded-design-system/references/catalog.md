# Catalog

This file covers the queryable catalog: one metadata sidecar per component or pattern, the status vocabulary, examples as documentation and a registry regenerated in CI. It answers "What am I using here?" for a reader that queries instead of browsing.

## One sidecar per component

Documentation pages are written for someone browsing. An agent queries. Every component and pattern gets a small metadata file beside its example or source.

The sidecar answers five questions: what it is called, what kind of thing it is, when to use it, what it does, and whether it can be trusted.

| Field | Type | Required | Question it settles |
| --- | --- | --- | --- |
| `name` | string | always | What do I search for? |
| `type` | `"component" \| "pattern" \| "block"` | always | Do I import it or compose it? |
| `usage` | string | when not `missing` | When do I use it, and what do I use instead when I should not? |
| `description` | string | when not `missing` | What does it do? |
| `status` | see below | always | Can I trust it? |
| `issue` | number or URL | when `missing`, `needs-rework` or `deprecated` | Where is the decision tracked? |
| `introduced` | `{ pr: number, date: "YYYY-MM-DD" }` | when not `missing` | How old is this answer? |
| `replacedBy` | string | when `deprecated` | What do I use now? |

Write `usage` with its when-not in the same field. The when-not is what stops the agent picking the wrong one of two neighbors.

```ts
// filters/date-range.meta.ts
export default defineMeta({
  name: "Date range filter",
  type: "pattern",
  usage: "Filter a list over a period. One date: DatePicker.",
  description: "Two linked date inputs with presets, emitting an inclusive range.",
  status: "stable",
  introduced: { pr: 1182, date: "2026-03-14" },
})

// filters/saved-views.meta.ts
export default defineMeta({
  name: "Saved views",
  type: "pattern",
  status: "missing",
  issue: 412,
})
```

[templates/component.meta.ts](../templates/component.meta.ts) holds the type and the validator.

## Status vocabulary

| Status | Meaning for the agent |
| --- | --- |
| `missing` | The system acknowledges the gap. Do not improvise around it. Link the issue in your output. |
| `experimental` | Usable, API may change. Pin usage to the documented props. |
| `needs-review` | Built, not yet validated by the team. Usable, flag the usage in the PR description. |
| `needs-rework` | Known defects, tracked in `issue`. Use it, do not fork it. |
| `stable` | The default answer. |
| `deprecated` | Do not import in new code. Use `replacedBy`. |

A `missing` entry renders as a placeholder in the team's docs, linked to its issue, so people see the same hole the machine does.

Which component is `deprecated` and which is canonical is a team decision. The audit lists duplicates with their import counts and asks. It never assigns a status.

## Examples are the documentation

No hand-written code samples in MDX or Markdown that can drift from what renders. Each docs page imports and renders the real example file, and the code panel reads the same file from disk. One file, two views.

Check: this search on component docs pages returns nothing, or only snippets that are not component usage.

```bash
rg -n '^\s*`{3}(tsx|jsx)' docs/
```

## Registry regenerated in CI

A generator walks every sidecar and writes one registry file (JSON). CI regenerates it on every pull request and fails when the result differs from what is committed.

```bash
npm run registry:build
git diff --exit-code -- registry.json \
  || { echo "registry.json is stale. Run npm run registry:build and commit the result."; exit 1; }
```

The same generator fails when a component file has no sidecar, so a component without metadata does not merge. A command line that creates, lists, verifies and bulk-edits sidecars makes thousands of them cheap. Agents use it like any other tool.

## Adapters

Keep the team's existing catalog format. Put the five answers where the stack already stores metadata.

| Stack | Where the sidecar fields live | Regen and diff |
| --- | --- | --- |
| shadcn registry | `registry.json` items: `name`, `type`, `description`, plus `meta: { usage, status, issue, introduced }` | `npx shadcn build`, then `git diff --exit-code public/r` |
| Storybook | `parameters.meta` on the default export, `tags: ["status:stable"]` for filtering | A script reading `index.json` from `storybook build`, diffed |
| Plain | `<name>.meta.ts` or `<name>.meta.json` beside the component | A script globbing `**/*.meta.{ts,json}` into `registry.json` |

Details per stack are in [stacks/tailwind-shadcn.md](stacks/tailwind-shadcn.md) and [stacks/storybook.md](stacks/storybook.md).

## Pitfalls

- A sidecar with `usage: "Use for buttons"` restates the name. The usage names the situation and the alternative.
- Free-text `status` values (`"wip"`, `"beta"`) break every query. Validate the enum in the generator.
- `introduced` is the merge that made the entry current, not the first commit of the file. Ask the team which one they track before backfilling.
- Backfilling hundreds of sidecars in one PR hides decisions in noise. Backfill `stable` components first, one directory per PR.
