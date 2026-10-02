# Stack: CSS only

This file maps the skill onto a repository styled with plain CSS or CSS Modules, with no utility framework, no Sass, no CSS-in-JS and no token pipeline. Load it when `detect-stack.sh` lists `css-only` in `stack-refs`: the script lists it only when no other styling reference matched. Sass and Less live in [sass.md](sass.md); theme objects and styled components in [css-in-js.md](css-in-js.md).

Describe the token layer the repository has. Never prescribe a new one: a token file, a selector convention and a naming scheme are team decisions, and a working layer stays as it is.

## Detect

| Signal | Meaning |
| --- | --- |
| `tokens-css:` lists files with 10 or more custom properties | Those files are the token layer; the count shows distinct names and declarations |
| `themes:` lists `:root` plus other selectors (`.dark`, `[data-theme=...]`, `prefers-color-scheme`) | One theme per selector; a single `:root` means one theme |
| `*.module.css` | CSS Modules: class names are local, custom properties are global |
| `.html` files with class attributes and no component framework | Global class names act as the component API |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Token source | The files `tokens-css:` lists, wherever they sit. Several files (one per layer, one per theme) are a valid layer; record which file holds which layer |
| Palette audit | Stylelint `color-no-hex`, `color-named: "never"`, `function-disallowed-list` for literal `rgb`, `hsl`, `oklch`, with `overrides` that turn them off for the token source paths |
| Contract test | [templates/token-contract.test.ts](../../templates/token-contract.test.ts), adapted: set `SOURCE` to the token file, `THEMES` to the selectors `themes:` lists, and the alias patterns to the repository's primitive names. With several token files, read each one. Without Vitest or Jest, port it to `node:test` with `node:assert`: the parser has no dependency |
| Catalog | `<name>.meta.json` beside each component file or stylesheet, or a single list the team already keeps. Add `.meta.ts` only where the repository already runs TypeScript |
| Component API | Global class names and element selectors. Inventory them as the catalog unit and ask which are public |

```json
{
  "rules": {
    "color-no-hex": [true, {
      "message": "Use a color token from DESIGN.md (var(--<token>)). No token fits? Log a gap, do not add a literal."
    }],
    "color-named": ["never", {
      "message": "Use a color token from DESIGN.md. Named colors bypass the token layer."
    }],
    "function-disallowed-list": [["rgb", "rgba", "hsl", "hsla", "oklch"], {
      "message": "Use a color token from DESIGN.md. Literal color functions live only in the token source."
    }]
  },
  "overrides": [{ "files": ["<token source paths>"], "rules": { "color-no-hex": null, "color-named": null, "function-disallowed-list": null } }]
}
```

## Pitfalls

- A file with many custom properties may be a component's local variables, not the system's tokens. Read it before calling it a source; set `DS_TOKEN_SOURCES` when the script guesses wrong.
- Global class names (`.btn-primary`) act as an undeclared component API. Inventory them in the audit and ask whether they are part of the system.
- `function-disallowed-list` also fires on `rgb(var(--x) / 50%)`, which reads a token. Read the first run of hits before making the rule blocking.
- Contrast and theme switching need a render. A unit test on values checks the declared pairs only; say so in the test name.
