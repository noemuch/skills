# Changelog

Every release of the `grounded` plugin. The version matches `version` in `.claude-plugin/plugin.json`.

## 0.1.0

- `grounded-design-system`: first release, companion of the article "Make your design system AI-ready".
  - Actions: `audit` (read-only, scores 14 areas as answered, missing, disconnected or stale), `setup week1|week2|week3` (one phase per run, approval between phases), `gap` (issue plus gap index line, never a workaround), `test` (readiness test with a fresh agent).
  - References: doctrine, agent files, catalog, tokens, enforcement, change types, readiness tests, and seven stack mappings (Tailwind and shadcn/ui, Radix, Base UI, Storybook, Figma variables, Style Dictionary, CSS only).
  - Templates: AGENTS.md, DESIGN.md, component metadata type and validator, GAPS.md, path-scoped rule, lint messages for ESLint, Biome and Stylelint, GitHub Actions gate, Claude Code PreToolUse hook, token contract test.
  - Scripts: `detect-stack.sh` (repository inventory) and `count-hardcoded.sh` (hardcoded value counts per directory), both read-only and POSIX sh.
