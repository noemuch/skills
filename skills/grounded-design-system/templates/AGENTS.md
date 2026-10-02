<!--
Template from grounded-design-system. Merge the UI sections into the repository's
existing AGENTS.md; never replace the file. Replace every <placeholder> and
@acme/ui with real values: <gap-label> and <exception-marker> are the team's answers,
never defaults. Delete this comment.
-->

# AGENTS.md

Instructions for every coding agent in this repository. `CLAUDE.md` imports this file with `@AGENTS.md`. Skills and rules live in `.agents/`; tool folders hold symlinks only.

## Building UI

1. Read `DESIGN.md` before writing UI code. It lists every token with its usage.
2. Query the catalog before building anything: `<catalog command, e.g. npm run catalog -- list --type pattern>`. Use a component whose `usage` matches the need. Skip components with `status: "deprecated"`; use their `replacedBy`.
3. Import components from `@acme/ui`. Prefer them over raw HTML elements.
4. A raw element (`<button>`, `<input>`, `<table>`, `<dialog>`) where a component would sit requires a gap entry in the same change. See "When the system has no answer".
5. Colors, spacing, radii and shadows come from tokens. Hex, `rgb()`, `hsl()` and `oklch()` in component code fail `<palette audit command>`.
6. An arbitrary value (`w-[312px]`) carries a comment starting with `<exception-marker>` on the same or previous line, stating why no token fits.
7. Match a design value to a token by usage, never by the nearest number.

## When the system has no answer

When the design system has no component, token or pattern for what you need, flag it with a gap entry instead of building around it. A blocker honestly reported is a good outcome; the patch is the failure.

A gap entry is two things:

1. An issue: `gh issue create --label <gap-label> --title "<Thing>: <what it must do>"`, with the file that needed it in the body.
2. One line in `<GAPS.md or packages/ui/README.md#component-gaps>`: `- <Thing>: <what it must do> (#<issue>)`.

Then continue the task without the missing piece, or keep the raw element with `eslint-disable-next-line no-restricted-syntax -- gap #<issue>`.

## Changing the design system

- Declare the change type before writing code: `create`, `refine`, `extend` or `refactor`. A change that drifts from its type returns to the spec.
- Consumers counted by `<blast radius command>` set the evidence: 0 to 10 standard checks; 11 to 50 add screenshots of 3 consumers; over 50 add 5 consumers and a human note.
- Every touched component gets a line in its changelog: type, what, why.
- Generated files are never edited by hand: `<registry.json>`, `<tokens build output>`. Edit the source and run `<regen command>`.

## Validation, in CI order

```bash
<lint command> --max-warnings=0
<typecheck command>
<test command>
<registry regen command> && git diff --exit-code <registry path>
<visual regression command>
```

## Working rules

- Work on a branch in its own worktree. Commits on `<protected branch>` and `--no-verify` are refused by hooks.
- When a session reveals something: an actionable fix becomes an issue, a recurring convention becomes a rule in `.agents/rules/`, a story becomes a note.
