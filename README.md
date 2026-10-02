# skills

[![skills.sh](https://skills.sh/b/noemuch/skills)](https://skills.sh/noemuch/skills)

Agent skills that make a codebase answer instead of letting the agent guess.

## Grounded

Every skill in this collection carries the `grounded-` prefix. A grounded system is one where an agent building on it reads answers from the repository: what to use, what it may not do, and what to do when the answer does not exist. Where the system is silent, a grounded skill flags the silence instead of filling it with the most plausible guess. Each skill applies that rule to itself: when it cannot tell what your team decided, it asks.

## Skills

| Skill | What it does |
| --- | --- |
| [**grounded-design-system**](skills/grounded-design-system/SKILL.md) | Makes a team's design system AI-ready inside their own repository, so agents building UI read answers instead of guessing. Audits where the system is silent, sets up the context layer, catalog, enforcement and gap log one phase at a time, logs missing pieces instead of inventing around them, and runs readiness tests. |

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

With the [skills CLI](https://skills.sh), for Claude Code, Cursor, Codex and other agents:

```bash
npx skills add noemuch/skills
```

As a Claude Code plugin:

```text
/plugin marketplace add noemuch/skills
/plugin install grounded@noemuch
```

Plugin users invoke skills with the plugin prefix: `/grounded:grounded-design-system`.

## License

[MIT](LICENSE)
