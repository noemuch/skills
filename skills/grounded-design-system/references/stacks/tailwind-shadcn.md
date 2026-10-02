# Stack: Tailwind and shadcn/ui

This file maps every mechanism of the skill onto a Tailwind CSS repository, v3 or v4, with or without shadcn/ui, and with shadcn/ui installed by the CLI or by hand. Load it when `detect-stack.sh` lists `tailwind-shadcn` in `stack-refs`.

## Detect

`detect-stack.sh` prints the major version, the entry stylesheet and the config on the `styling:` line, and the shadcn/ui setup on the `shadcn:` line.

| Signal | Meaning |
| --- | --- |
| `@import "tailwindcss"` in a CSS file, or `tailwindcss` `^4` | v4: tokens in CSS `@theme`; a config file is optional |
| `@tailwind base;` in a CSS file, or `tailwindcss` `^3` with `tailwind.config.*` | v3: tokens in `theme` and `theme.extend` of the config, values often from CSS variables |
| `components.json` at the root | shadcn/ui installed with the CLI; read `aliases.ui` and `tailwind.css` from it |
| `shadcn: installed by hand` | shadcn/ui copied before the CLI existed, or pasted: a `ui/` directory of components using `class-variance-authority` or Radix, and a `cn()` helper built on `tailwind-merge` |
| `registry.json` at the root or `public/r/*.json` | shadcn registry published |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Token source | v4: the CSS file holding `@theme` (named in `components.json` `tailwind.css` when present), with `:root` and one block per additional theme. v3: `tailwind.config.*` (`tokens-tailwind-config:` lists its `theme` and `theme.extend` keys) plus the CSS variables file it reads (`tokens-css:`). Both files together are the source |
| DESIGN.md token tables | Generated from the theme blocks the token source defines (`themes:`); usage column from the team |
| Catalog | With `components.json`: shadcn `registry.json` items, usage and status in each item's `meta` object. Installed by hand: sidecars beside the files of the detected `ui/` directory, or a registry the team chooses |
| Registry regen | `npx shadcn build` then `git diff --exit-code public/r`, when the team publishes a registry |
| Palette audit | `count-hardcoded.sh` columns `palette` (raw palette steps, `bg-white`, `text-black`), `arbcolor`, `arbvar`, `arblen`, `arbother`. Gate on arbitrary values without the team's exception marker |
| Contract test | Parse the CSS file holding the variables. v3: also assert that every `theme.extend.colors` entry reads a variable the CSS defines |
| Lint, imports | `no-restricted-imports` for icon libraries and for deep paths into the UI directory when the team re-exports; `no-restricted-syntax` on raw elements |
| Lint, classes | Check `lint-plugins:` first. `eslint-plugin-tailwindcss` (v3) has `no-arbitrary-value` and `no-custom-classname`; a repository that installs it with those rules `off` scores lint `violated`, and turning one on is the cheapest gate. For v4, check the current plugin docs for support before proposing one |
| Class order | `prettier-plugin-tailwindcss` or the lint plugin's order rule. Order is not a design rule; never count it as enforcement |

Example `registry.json` item with the catalog fields:

```json
{
  "name": "date-range-filter",
  "type": "registry:block",
  "title": "Date range filter",
  "description": "Two linked date inputs with presets, emitting an inclusive range.",
  "files": [{ "path": "registry/blocks/date-range-filter.tsx", "type": "registry:block" }],
  "meta": {
    "usage": "Filter a list over a period. One date: DatePicker.",
    "status": "stable",
    "introduced": { "pr": 1182, "date": "2026-03-14" }
  }
}
```

## shadcn/ui without components.json

A repository whose `ui/` directory was copied by hand has no `aliases.ui` to read. Take the directory from the `shadcn:` line, and the import alias from `tsconfig.json` `compilerOptions.paths` (`@/*`). Scope rules and sidecars to that directory. Whether the files are vendored (refreshed from upstream, never edited) or owned by the team is a question: the answer decides whether a hook protects them and whether lint exceptions cover them.

`component-usage.sh` prints importers per file of that directory. Files imported nowhere are a status question for the team: supported, kept as stock, or removed. Never call them dead.

## Normalizing components on install

`shadcn add` writes components that consume the semantic aliases shadcn ships (`bg-muted`, `text-muted-foreground`). Whether the team keeps those aliases or maps components onto its own token names is a team decision. Ask it once, write the answer in `AGENTS.md`, and add a rule scoped to the UI directory that says which vocabulary components use. Two token vocabularies side by side mean one of them changes silently when the other moves.

## Pitfalls

- Tailwind v4 has no config file to lint against. The CSS file is the source; point the contract test at it.
- In v3, `hsl(var(--x))` in the config is a definition, not a hardcoded color. `count-hardcoded.sh` counts only color functions with literal arguments, and reports the config apart as a token source.
- A semantic alias declared in `:root` and never consumed is either dead or a decision the team made deliberately. Ask before reporting it as dead.
- Arbitrary values that read runtime variables of a primitive library (`h-[var(--radix-select-trigger-height)]`) are behavior plumbing, not design values. The script counts them apart; never report them as violations.
- Files rendered outside the DOM (`next/og`, `@vercel/og`, email templates) cannot read CSS variables. The script lists them; report their literals apart and ask how the team wants them handled.
- `cn()` merges conflicting classes silently. A component default overridden by a consumer class shows nowhere in lint; visual regression catches it.
- Tailwind generates any arbitrary value it finds, so the build never fails on `text-[#123456]`. Only the audit and a lint rule do.
- The shadcn CLI overwrites files on `add --overwrite`. Add the UI directory to the hook's generated list only if the team treats it as vendored.
