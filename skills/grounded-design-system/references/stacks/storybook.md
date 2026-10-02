# Stack: Storybook

This file maps the catalog, examples and visual regression onto Storybook. Load it when `detect-stack.sh` lists `storybook` in `stack-refs`.

## Detect

| Signal | Meaning |
| --- | --- |
| `.storybook/main.*` | Storybook configured; read `stories` globs and `framework` |
| `storybook` or `@storybook/*` in `package.json` | Version from the package |
| `*.stories.{ts,tsx,js,jsx,mdx}` | Story files; count them per directory |
| `@chromatic-com/storybook` or `chromatic` | Hosted visual regression in place |

## Read what Storybook already gives

Before proposing `parameters.meta`, score what the stories already answer. Each signal is evidence for the catalog area:

| Signal | Where | What it answers |
| --- | --- | --- |
| Autodocs | `tags: ["autodocs"]` in `.storybook/preview.*` or `main.*`, or per story file (`docs:` line of the inventory) | Props tables generated from types: name and API, not usage |
| `component:` on the default export | Each story file | Links the story to the component, so docs and type extraction work. Count story files without it |
| `argTypes` written by hand | Story files | Drifts from props; inferred argTypes do not |
| `parameters.docs.description` | Story files | Usage text, when present: count components that have one |
| Components without a story | Exported components with no story file | Unlisted in the catalog |
| CSF2 and CSF3 side by side | `Template.bind({})` beside object stories | Two story formats: a consistency finding |
| `@storybook/addon-a11y` | `tests:` line | Accessibility checks in the docs tool, not a merge gate by itself |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Catalog sidecar | `parameters.meta` on each CSF default export |
| Status filtering | `tags`, one per status: `status:stable`, `status:deprecated` |
| Registry | `storybook build` writes `storybook-static/index.json`; a script maps entries plus `parameters.meta` into `registry.json` |
| Examples as docs | Stories are the examples. MDX docs pages use `<Canvas of={Stories.Default} />`, never a pasted code block |
| Visual regression | Chromatic, or the Storybook test runner with Playwright screenshots, in each theme the system defines through a global toolbar parameter |
| `missing` entries | A story file with only a default export carrying `status: "missing"` and `issue`, rendering a placeholder that links the issue |

```ts
// date-range-filter.stories.tsx
const meta = {
  title: "Patterns/Date range filter",
  component: DateRangeFilter,
  tags: ["autodocs", "status:stable"],
  parameters: {
    meta: {
      type: "pattern",
      usage: "Filter a list over a period. One date: DatePicker.",
      status: "stable",
      introduced: { pr: 1182, date: "2026-03-14" },
    },
  },
} satisfies Meta<typeof DateRangeFilter>
export default meta
```

`index.json` does not include `parameters`. The registry script imports each story file's default export, or reads `parameters.meta` through a build step, to recover the fields. Check the Storybook version before choosing.

## Pitfalls

- Stories written as demos ("Playground", "Kitchen sink") make poor examples for an agent. One story per real usage, named after the usage.
- `argTypes` documentation drifts from props when written by hand. Let Storybook infer it from types.
- Snapshot tests on every story including interaction stories produce flaky diffs. Snapshot the static states only.
- Storybook is often the only place usage notes live. Notes in a hosted Storybook the agent cannot reach from the repository are `disconnected`; keep them in story files.
