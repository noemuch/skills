# Stack: CSS only

This file maps the skill onto a repository with no utility framework and no token pipeline: plain CSS, CSS Modules, Sass or CSS-in-JS over custom properties. It is the floor every other stack builds on. Load it when `detect-stack.sh` lists `css-only` in `stack-refs`, or when no other stack reference matches.

## Detect

| Signal | Meaning |
| --- | --- |
| `*.module.css` or `*.module.scss` | CSS Modules |
| `sass` in `package.json`, `*.scss` | Sass; tokens may be Sass variables, CSS custom properties or both |
| `styled-components`, `@emotion/*`, `@vanilla-extract/*` | CSS-in-JS; tokens often live in a theme object |
| `:root {` with `--` declarations | Custom properties as the token layer |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Token source | One `tokens.css` with `:root` and a theme selector (`[data-theme="dark"]` or `.dark`). Sass variables only for build-time values like breakpoints |
| CSS-in-JS | The theme object is the token source; type it so an unknown key fails `tsc` |
| Palette audit | Stylelint: `color-no-hex`, `function-disallowed-list` for `rgb`, `hsl`, `oklch` outside the token file, `declaration-property-value-allowed-list` to force `var(--*)` on color properties |
| Contract test | Parse `tokens.css` with [templates/token-contract.test.ts](../../templates/token-contract.test.ts) unchanged |
| Catalog | Plain `<name>.meta.ts` or `.meta.json` sidecars and a glob script |

```json
{
  "rules": {
    "color-no-hex": [true, {
      "message": "Use a color token from DESIGN.md (var(--color-*)). No token fits? Log a gap, do not add a literal."
    }],
    "function-disallowed-list": [["rgb", "rgba", "hsl", "hsla", "oklch"], {
      "message": "Use a color token from DESIGN.md. Literal color functions live only in tokens.css."
    }]
  },
  "overrides": [{ "files": ["src/styles/tokens.css"], "rules": { "color-no-hex": null, "function-disallowed-list": null } }]
}
```

## Pitfalls

- Sass variables compile away. An agent reading compiled CSS sees literals. Keep color tokens as custom properties so the semantic name survives to the browser.
- CSS-in-JS theme objects typed as `Record<string, string>` accept any key. Type them with literal keys.
- Global class names (`.btn-primary`) act as an undeclared component API. Inventory them in the audit and ask whether they are part of the system.
