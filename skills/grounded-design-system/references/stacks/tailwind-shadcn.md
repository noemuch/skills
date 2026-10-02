# Stack: Tailwind and shadcn/ui

This file maps every mechanism of the skill onto a Tailwind CSS (v3 or v4) repository, with or without shadcn/ui. Load it when `detect-stack.sh` lists `tailwind-shadcn` in `stack-refs`.

## Detect

| Signal | Meaning |
| --- | --- |
| `tailwindcss` in `package.json`, version `^4` | v4: tokens in CSS `@theme` |
| `tailwindcss` version `^3` and `tailwind.config.*` | v3: tokens in `theme.extend` |
| `@import "tailwindcss"` in a CSS file | v4 entry stylesheet |
| `components.json` at the root | shadcn/ui installed; read `aliases.ui` and `tailwind.css` from it |
| `registry.json` at the root or `public/r/*.json` | shadcn registry published |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Token source | v4: the CSS file named in `components.json` `tailwind.css`, blocks `:root`, `.dark`, `@theme inline`. v3: `tailwind.config.*` plus the CSS variables file |
| DESIGN.md token tables | Generated from the `:root` and `.dark` blocks; usage column from the team |
| Catalog | shadcn `registry.json` items. Put usage and status in each item's `meta` object |
| Registry regen | `npx shadcn build` then `git diff --exit-code public/r` |
| Palette audit | `count-hardcoded.sh` `palette-steps` and `arbitrary` columns; gate on arbitrary values without an `arbitrary:` comment |
| Contract test | Parse the CSS file named in `components.json` |
| Lint | `no-restricted-imports` for icon libraries and for `@/components/ui/*` deep paths if the team re-exports; `no-restricted-syntax` on raw elements |
| Class sorting and validity | `prettier-plugin-tailwindcss` for order. Validity of arbitrary classes is not checked by Tailwind; the audit covers it |

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

## Normalizing components on install

`shadcn add` writes components that consume the semantic aliases shadcn ships (`bg-muted`, `text-muted-foreground`). Whether the team keeps those aliases or maps components onto its own token names is a team decision. Ask it once, write the answer in `AGENTS.md`, and add a rule scoped to the `aliases.ui` path that says which vocabulary components use. Two token vocabularies side by side mean one of them changes silently when the other moves.

## Pitfalls

- Tailwind v4 has no config file to lint against. The CSS file is the source; point the contract test at it.
- A semantic alias declared in `:root` and never consumed is either dead or a decision the team made deliberately. Ask before reporting it as dead.
- `cn()` merges conflicting classes silently. A component default overridden by a consumer class shows nowhere in lint; visual regression catches it.
- Tailwind generates any arbitrary value it finds, so the build never fails on `text-[#123456]`. Only the audit does.
- The shadcn CLI overwrites files on `add --overwrite`. Add the UI directory to the hook's generated list only if the team treats it as vendored.
