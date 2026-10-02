# Stack: Base UI

This file maps the skill onto a repository built on Base UI primitives. Load it when `detect-stack.sh` lists `base-ui` in `stack-refs`.

## Detect

| Signal | Meaning |
| --- | --- |
| `@base-ui/react` in `package.json` | Current package name |
| `@base-ui-components/react` | Earlier package name; record which one the repository uses |
| `components.json` alongside it | shadcn/ui configured on Base UI; also load [tailwind-shadcn.md](tailwind-shadcn.md) |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Behavior | Base UI owns focus management, ARIA state machines, portals, positioning and collision. Compose its parts; never reimplement them |
| Composition | Cards, sections, separators, list rows: plain elements with tokens. A primitive brings behavior, so a component with no behavior needs none |
| Catalog | Sidecar on the team's composed component, naming the primitive in `description` |
| Styling hooks | Base UI exposes state as data attributes (`data-open`, `data-checked`, `data-disabled`). Rules reference those, never a local boolean |
| Lint | Restrict primitive imports outside the UI layer when the team wraps them; allow them where the team composes directly |

Example rule for a repository that composes Base UI directly in its components:

```markdown
---
paths:
  - "components/ui/**"
---

- Interactive behavior comes from `@base-ui/react` parts. A hand-written focus trap, `tabIndex` loop or `aria-expanded` toggle fails review.
- Style state with Base UI data attributes: `data-[open]:`, `data-[checked]:`. A `useState` mirror of primitive state fails review.
```

## Pitfalls

- Wrapping a Base UI primitive in a third-party styled wrapper brings that wrapper's defaults (colors, fixed heights). Each default becomes something to undo. Prefer the primitive directly.
- Base UI renders through a `render` prop for element replacement. A component that clones children to change the element type fights the primitive.
- The package was renamed. Mixed imports from both names in one repository are a `stale` finding.
