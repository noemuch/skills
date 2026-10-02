# Stack: Radix

This file maps the skill onto a repository whose components wrap Radix Primitives or Radix Themes. Load it when `detect-stack.sh` lists `radix` in `stack-refs`.

## Detect

| Signal | Meaning |
| --- | --- |
| `@radix-ui/react-*` packages or the `radix-ui` umbrella package | Radix Primitives: behavior only, the team styles |
| `@radix-ui/themes` | Radix Themes: styled components with their own token system |
| `@radix-ui/colors` | Radix color scales used as primitives |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Behavior | Radix owns focus, roving tabindex, ARIA state, portals and collision. The team never reimplements them by hand |
| Catalog | Sidecars sit on the team's wrapper (`@acme/ui/dialog`), never on the Radix primitive |
| Tokens | Primitives: team tokens. Themes: `--accent-*`, `--gray-*` and the `Theme` props (`accentColor`, `grayColor`, `radius`, `scaling`) are the token layer |
| Lint | Restrict direct `@radix-ui/react-*` imports outside the UI package, with a message pointing at the wrapper |
| Contract test | Themes: assert the `Theme` props the app passes match DESIGN.md. Primitives: test the team's CSS tokens |

```js
"no-restricted-imports": ["error", { patterns: [{
  group: ["@radix-ui/react-*", "radix-ui"],
  message:
    "Import the wrapper from @acme/ui (Dialog, Popover, ...). " +
    "No wrapper exists? Log a gap with label area:design-system, do not wrap it locally.",
}]}]
```

Allow the import inside the UI package itself with an `overrides` block scoped to its path.

## Pitfalls

- A wrapper that spreads props onto the Radix root without forwarding `ref` breaks `asChild` composition. Visual regression does not catch it; a keyboard test does.
- Radix data attributes (`data-state="open"`) are the styling hook. A component styling open state with its own boolean diverges from the primitive's state.
- Two wrappers around the same primitive (`Modal` and `Dialog`) is a canonical-component decision. List both with import counts and ask.
- Radix Themes and a custom token layer side by side produce two vocabularies. Ask which one components read.
