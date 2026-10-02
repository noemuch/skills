# Stack: Sass and Less

This file maps the skill onto a repository whose styles are written in Sass (`.scss`, `.sass`) or Less, including a library that is itself the design system and commits its compiled CSS. Load it when `detect-stack.sh` lists `sass` in `stack-refs`.

Describe the token chain the repository has. A mature Sass architecture (primitive variables, semantic maps per theme, custom properties emitted with a configurable prefix) is a set of team decisions; never propose replacing it with a single token file.

## Detect

| Signal | Meaning |
| --- | --- |
| `.scss` or `.sass` files, `sass` or `sass-embedded` in `styling:` | Sass; `node-sass` is the deprecated compiler, record which one runs |
| `.less` files | Less: the same mechanisms with `@name:` variables and `customSyntax: "postcss-less"` |
| `tokens-sass:` | Token files: variables holding design values, maps of design values, or custom properties emitted through interpolation (`#{$prefix}primary:`) |
| `generated:` naming a `css/` directory or a `sass in:out` script | Compiled output. Every script excludes it from counts and from token detection |
| `themes:` | Theme selectors and `color-scheme` declarations found in the token files |
| `postcss-scss`, `stylelint-scss` in `lint-plugins:` | Part of the lint toolchain is already installed |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Token source | The files `tokens-sass:` lists. Record the chain: primitives (`$red-500: #d93526`), semantic map or mixin per theme, emitted custom properties. Which custom properties are public, meaning a consumer may override them, is a team decision; list them in DESIGN.md once answered |
| Compiled output | Generated. Agents edit the source only: a hook refuses edits under the output directory, and CI rebuilds and diffs it (`<build command> && git diff --exit-code <output dir>`). This check is the cheapest gate a library with committed output can add |
| Palette audit | Stylelint on the sources, with the rules below, turned off for the token directories by `overrides` |
| Contract test | See [Contract test](#contract-test) |
| Catalog | The module list the library already keeps (a map of enabled modules, the `@use` and `@forward` index), extended with usage and status; or a `<module>.meta.json` beside each partial. The catalog unit is the module; its API is the element selectors, classes, data attributes and custom properties it reads |
| Variant matrix | Themes, color variants and alternative builds (classless, scoped, fluid) multiply. Blast radius and visual regression run across the matrix, not per component |

```json
{
  "customSyntax": "postcss-scss",
  "plugins": ["stylelint-declaration-strict-value"],
  "rules": {
    "color-no-hex": [true, {
      "message": "Use a token from DESIGN.md. No token fits? Log a gap, do not add a literal."
    }],
    "color-named": ["never", {
      "message": "Use a token from DESIGN.md. Named colors bypass the token layer."
    }],
    "scale-unlimited/declaration-strict-value": [["/color$/", "fill", "stroke"], {
      "message": "Read a token (a Sass variable or a custom property). Literal values live only in the token directories."
    }]
  },
  "overrides": [{
    "files": ["<token directories>/**/*.scss"],
    "rules": { "color-no-hex": null, "color-named": null, "scale-unlimited/declaration-strict-value": null }
  }]
}
```

Run it once on a component partial before making it blocking. Read how the installed version of `stylelint-declaration-strict-value` treats functions and interpolated variables; adjust `ignoreFunctions` and `ignoreValues` to the result, and record what you changed and why.

## Contract test

Two levels, chosen by what the team wants to hold:

- **Aliases** (which primitive a semantic token reads): only the Sass sources know them, because compilation resolves `#{$zinc-550}` to a literal. Load the semantic map with the `sass` package's JavaScript API, emit each entry, and assert it against the contract table:

  ```js
  // tests/token-contract.test.mjs, node:test, no runner needed
  import { test } from "node:test"
  import assert from "node:assert/strict"
  import * as sass from "sass"

  const THEMES = ["<theme>"]                       // REPLACE: every theme the system defines
  const ALIASES = { primary: /^#/ }                // REPLACE: the team's contract per token

  for (const theme of THEMES) {
    const { css } = sass.compileString(
      `@use "<theme module>" as t; .probe { @each $k, $v in t.<map for ${theme}> { --#{$k}: #{$v}; } }`, // REPLACE
      { loadPaths: ["<scss root>"] },
    )
    for (const [token, pattern] of Object.entries(ALIASES)) {
      test(`${theme}: --${token} holds its contract`, () => {
        const m = css.match(new RegExp(`--${token}:\\s*([^;]+);`))
        assert.ok(m, `--${token} missing in ${theme}`)
        assert.match(m[1].trim(), pattern)
      })
    }
  }
  ```

- **Presence per theme** (every semantic token defined in every theme): parse the compiled CSS with [templates/token-contract.test.ts](../../templates/token-contract.test.ts), with `THEMES` set to the selectors `themes:` lists, after the build. Run it on each build of the matrix that ships.

## Pitfalls

- A configurable prefix (`var(#{$css-var-prefix}primary)`) defeats every rule or search written against `var(--`. Search for the emitted name in the compiled output and for the interpolated form in the sources; match `var\(` followed by `--` or `#{`.
- Compiled output outranks the source in every search: a token name returns hundreds of hits under the output directory and none in the sources. That is a `stale` finding until a hook and a regeneration diff guard the output.
- Sass color math in the token layer (`rgba($slate-550, 0.5)`, `color.mix(...)`) is a definition. Outside the token directories, ask whether it is allowed; it reads a token, so it is not a literal.
- A local constant (`$border-thumb: 2px;`) names a value. `count-hardcoded.sh` counts it under local definitions, apart from usage; whether component files may define their own constants is a team question.
- `rem` is the native unit of many Sass libraries. Read the `rem` column, not only `px`.
- `.meta.ts` sidecars bring a TypeScript toolchain to a repository that has none. Prefer JSON, or the module list that already exists.
