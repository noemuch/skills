# Stack: CSS-in-JS and theme objects

This file maps the skill onto a repository whose styles live in JavaScript or TypeScript: styled-components, emotion (directly or through a re-export such as `@storybook/theming` or `@mui/system`), Stitches, vanilla-extract, Panda, Linaria, or plain style objects reading a theme object. Load it when `detect-stack.sh` lists `css-in-js` in `stack-refs`.

## Detect

| Signal | Meaning |
| --- | --- |
| `css-in-js:` lists an import with a file count | The styling library, counted by import, so re-exports appear under their own name with the engine in brackets |
| `tokens-js:` lists a file | A theme object (exported `color`, `spacing`, `typography`... holding literals) or a theme constructor (`createTheme`, `createGlobalTheme`, `createStitches`, a config with `tokens`) |
| `polished` in dependencies | Color math over tokens (`rgba(color.secondary, 0.5)`): a derivation, not a literal |
| `*.css.ts` files | vanilla-extract: styles compile at build time |
| `panda.config.*` | Panda: tokens and semantic tokens in the config; `strictTokens` makes unknown tokens a type error |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Token source | The file `tokens-js:` lists: the theme object or the constructor call. It is the whole layer; there may be no CSS custom property anywhere |
| Themes | The objects passed to `ThemeProvider`, or the themes the constructor creates. Count them by reading; a single object means one theme |
| Types | The cheapest enforcement. A theme declared `as const` or with `satisfies` gives literal keys, so `color.foo` fails `tsc` in TypeScript files. A theme typed `Record<string, string>` accepts any key. Closed union props (`appearance: "primary" \| "secondary"`) are enforcement too: count them in the lint and types area |
| Palette audit | ESLint `no-restricted-syntax` on literals in component files, or Stylelint with a `customSyntax` for template literals. Both below |
| Contract test | See [Contract test](#contract-test) |
| Catalog | Storybook when present ([storybook.md](storybook.md)); otherwise sidecars beside the components |

ESLint, for hex literals in strings and template literals outside the theme file:

```js
// merged into the existing config; files and ignores use the real paths
{
  files: ["src/components/**/*.{ts,tsx,js,jsx}"],
  ignores: ["<theme file>"],
  rules: {
    "no-restricted-syntax": ["error",
      {
        selector: "Literal[value=/^#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/]",
        message: "Read the color from the theme (<import path>). No token fits? Log a gap, do not add a literal.",
      },
      {
        selector: "TemplateElement[value.raw=/#[0-9a-fA-F]{3,8}\\b/]",
        message: "Read the color from the theme inside the template literal. No token fits? Log a gap.",
      },
    ],
  },
}
```

Stylelint reads styled-components and emotion template literals only through `customSyntax: "postcss-styled-syntax"`; without it, Stylelint lints the plain CSS files and nothing else. It does not read object styles (`{ color: "#fff" }`): cover those with the ESLint selectors above.

## Contract test

No parser is needed: import the object.

```ts
// tests/token-contract.test.ts
import { expect, test } from "vitest"
import { color, background } from "<theme file>"   // REPLACE

// REPLACE: the team's contract. "QUESTION: ..." marks an open decision and fails with it.
const CONTRACT: Record<string, RegExp | string> = {
  "color.negative": /^#/,
  "background.negative": "QUESTION: does background.negative pair with color.negative?",
}

const theme = { color, background } as Record<string, Record<string, string>>
for (const [path, rule] of Object.entries(CONTRACT)) {
  test(`${path} holds its contract`, () => {
    if (typeof rule === "string") throw new Error(`Open team decision for ${path}: ${rule}`)
    const [group, key] = path.split(".")
    expect(theme[group]?.[key], `${path} is missing`).toBeDefined()
    expect(theme[group][key]).toMatch(rule)
  })
}
```

With several themes, run the same contract over each theme object, and assert that every theme has the same keys.

## Pitfalls

- MDX and plain JavaScript files are not type-checked. A docs page that reads `typography.weight.black` renders nothing and fails nowhere. A contract test that imports the theme and checks the keys docs pages name catches it.
- Literal copies of token values in components (`#37D5D3` where `color.seafoam` holds it) are evidence, written as equalities. The usage decides which token applies, never the matching value.
- Object styles with unitless numbers (`fontSize: 13`, `padding: 10`) and size maps (`{ large: 40 }`) hold design values that `count-hardcoded.sh` does not count. Read the top component files by hand.
- Generated SVG components (svgr output) hold hundreds of illustration colors. `detect-stack.sh` excludes them when a script or a file marker shows they are generated; when it does not, set `DS_GENERATED`.
- A syntax-highlighting theme or a third-party color set inside a component is an exception for the team to accept, with its reason in the allowlist test.
