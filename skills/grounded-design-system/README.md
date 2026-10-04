# grounded-design-system

Makes a team's design system AI-ready inside their own repository, so agents building UI read answers instead of guessing.

`grounded-design-system` is the companion of the article [Make your design system AI-ready](https://noechague.com/writing/make-your-design-system-ai-ready). It implements the article's doctrine in your repository and stack:

```text
/grounded-design-system audit            score where the system is silent, with evidence
/grounded-design-system setup week1      describe the catalog
/grounded-design-system setup week2      enforce it in CI
/grounded-design-system setup week3      log what's missing
/grounded-design-system gap <need>       log a gap instead of building around it
/grounded-design-system test <area>      run a readiness test
```

The audit scopes the repository first (an app that consumes a design system, a library that is one, or both) and scores 15 areas as `answered`, `missing`, `disconnected`, `stale`, `violated` or `not determined`. It reads Tailwind v3 and v4, shadcn/ui with or without `components.json`, CSS-in-JS theme objects, Sass and Less, plain CSS, Storybook and DTCG tokens.

Plugin users also get the command `/readiness-check <area>`, which runs the readiness test: one real decision, only the written context, the instruction "Flag missing context, do not invent it", and a report of the rules the agent applied against the gaps it named.

## Install

The whole collection installs at once, see the [collection README](../../README.md#install). This skill alone:

```bash
npx skills add noemuch/skills --skill grounded-design-system
```

Plugin users invoke it with the plugin prefix: `/grounded:grounded-design-system`.
