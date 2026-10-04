# skills

[![skills.sh](https://skills.sh/b/noemuch/skills)](https://skills.sh/noemuch/skills)

A collection of agent skills for design engineers: design systems, interfaces, motion, and the workflows that let agents build them without guessing.

These skills cover what I write about on [noechague.com](https://noechague.com) and what I build day to day as a design engineer.

## Skills

- [**grounded-design-system**](skills/grounded-design-system): Makes your design system AI-ready inside your own repository. Audits where the system is silent, sets up the catalog, the enforcement and the gap log one step at a time, and logs what is missing instead of inventing it.
- [**readiness-check**](commands/readiness-check.md): Tests whether agents follow your design system: one real decision, only the written context, and a report of what they applied against what they could not find. User-invoked, Claude Code plugin.

Skills that make an area of your codebase answer carry the `grounded-` prefix. Tools you run by hand get a short name.

## Install

```bash
npx skills add noemuch/skills
```

### Claude Code plugin

```text
/plugin marketplace add noemuch/skills
/plugin install grounded@noemuch
```

## License

[MIT](LICENSE)
