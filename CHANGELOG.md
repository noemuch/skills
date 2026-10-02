# Changelog

Every release of the `grounded` plugin. The version matches `version` in `.claude-plugin/plugin.json`.

## 0.2.0

Fixes from audits run on three public repositories: a Next.js app with Tailwind v3 and shadcn/ui installed by hand, a React component library on emotion with a JS theme object and Storybook, and a Sass framework that commits its compiled CSS.

- `grounded-design-system`
  - Audit scopes first: app, library that is the design system, or both; contributor agents, consumer agents, or both; where their agent files must live. A library's consumer guidance must ship in the package. Stops and asks on an archived repository.
  - Scoring vocabulary completed: `answered`, `missing`, `disconnected`, `stale`, `violated`, `not determined`. An area with nothing to evaluate is `missing`, never answered by default. Enforcement areas are scored on their mechanism.
  - Maturity levels gain `silent` below `guesses`. The overall line is a distribution per level and per question, not a grade. Ranking uses two stated scales (frequency, cost) and says it is a judgment.
  - New area 15, consistency: one intent written several ways, raw elements beside components, semantic tokens beside palette steps, repeated class strings.
  - The area table carries the `setup` phase of each area, so `audit` maps gaps without loading `setup.md`.
  - Team decisions removed from the skill: the issue label and the exception comment prefix are now `<gap-label>` and `<exception-marker>` placeholders. `gap` reads or asks for the label (`gh label list`) and never creates one.
  - No theme is assumed: DESIGN.md, the contract test, visual regression and the audit work on each theme the system defines.
  - Scripts: shared file universe in `scripts/lib.sh` (build output, compiled CSS beside its Sass source, svgr output and files marked generated are excluded everywhere). `detect-stack.sh` reports repository kind and what a package ships, archived notices, repository access and branch protection, Tailwind v3 or v4, shadcn/ui without `components.json`, CSS-in-JS by import (re-exports included), token sources in CSS, Sass, Less, JS theme objects, Tailwind config and JSON, theme selectors, lint plugins and design rules, Husky 4, lint-staged and lefthook, CI files and gates case-insensitively, and counts Sass and Less as UI code. `count-hardcoded.sh` no longer drops adjacent matches, strips comments and code fences, separates token-source definitions and local definitions from usage, counts named colors, `bg-white`/`text-black` and `rem`, ignores runtime variables of primitive libraries and keyword arbitrary values, shows Tailwind columns only with Tailwind, lists repeated values and files rendered outside the DOM. New `component-usage.sh`: importers per component, raw elements, repeated class strings, files mixing semantic utilities with palette steps.
  - New stack references: `css-in-js.md` and `sass.md`. `tailwind-shadcn.md` covers v3 and shadcn/ui without `components.json`; `css-only.md` describes the existing token layer instead of prescribing one; `storybook.md` reads what Storybook already gives.
- New plugin command `/readiness-check`: runs the readiness test of `grounded-design-system`.

## 0.1.0

- `grounded-design-system`: first release, companion of the article "Make your design system AI-ready".
  - Actions: `audit` (read-only, scores 14 areas as answered, missing, disconnected or stale), `setup week1|week2|week3` (one phase per run, approval between phases), `gap` (issue plus gap index line, never a workaround), `test` (readiness test with a fresh agent).
  - References: doctrine, agent files, catalog, tokens, enforcement, change types, readiness tests, and seven stack mappings (Tailwind and shadcn/ui, Radix, Base UI, Storybook, Figma variables, Style Dictionary, CSS only).
  - Templates: AGENTS.md, DESIGN.md, component metadata type and validator, GAPS.md, path-scoped rule, lint messages for ESLint, Biome and Stylelint, GitHub Actions gate, Claude Code PreToolUse hook, token contract test.
  - Scripts: `detect-stack.sh` (repository inventory) and `count-hardcoded.sh` (hardcoded value counts per directory), both read-only and POSIX sh.
