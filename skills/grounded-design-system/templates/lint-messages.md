# Lint messages written for the agent

Template from grounded-design-system: ready-made rules for ESLint, Biome and Stylelint whose messages say what to use instead and where to log a gap. Copy the rules for the linter the repository already runs. Replace `@acme/*` and paths with real ones, and `<gap-label>` and `<gap index>` with the team's answers.

Every message follows one shape:

```text
<What to use instead, with its import path>. <What to do when it does not fit: log a gap, with where>.
```

## ESLint (flat config)

```js
// eslint.config.js, merged into the existing config
const GAP = "No fit? Log a gap: gh issue create --label <gap-label>, plus one line in <gap index>. Do not substitute."

export default [
  {
    files: ["apps/**/*.{ts,tsx}", "src/**/*.{ts,tsx}"],
    rules: {
      "no-restricted-imports": ["error", {
        paths: [
          { name: "lucide-react", message: `Use an approved glyph from @acme/icons. ${GAP}` },
          { name: "react-icons", message: `Use an approved glyph from @acme/icons. ${GAP}` },
          { name: "@acme/ui/src", message: "Import from the package entry, @acme/ui. Deep imports bypass the public API." },
        ],
        patterns: [
          { group: ["@radix-ui/react-*", "@base-ui/react/*"], message: `Use the wrapper from @acme/ui. ${GAP}` },
        ],
      }],
      "no-restricted-syntax": ["warn",
        {
          selector: "JSXOpeningElement[name.name='button']",
          message: `Use Button from @acme/ui. Raw <button> only with a gap: ${GAP}`,
        },
        {
          selector: "JSXOpeningElement[name.name='input']",
          message: `Use Input, Checkbox or Switch from @acme/ui. Raw <input> only with a gap: ${GAP}`,
        },
        {
          selector: "JSXAttribute[name.name='style'] Property[key.name=/^(color|background|backgroundColor|borderColor)$/]",
          message: "Use a color token class from DESIGN.md. Inline color styles bypass the token layer.",
        },
      ],
    },
  },
  {
    // The UI package composes primitives directly.
    files: ["packages/ui/**/*.{ts,tsx}"],
    rules: { "no-restricted-imports": "off", "no-restricted-syntax": "off" },
  },
]
```

CI runs `eslint . --max-warnings=0`, so a warning blocks unless an inline disable names the gap:

```tsx
{/* eslint-disable-next-line no-restricted-syntax -- gap #412 saved views toolbar */}
```

## Biome

```json
{
  "linter": {
    "rules": {
      "style": {
        "noRestrictedImports": {
          "level": "error",
          "options": {
            "paths": {
              "lucide-react": "Use an approved glyph from @acme/icons. No fit? Log a gap in <gap index> with label <gap-label>. Do not substitute.",
              "react-icons": "Use an approved glyph from @acme/icons. No fit? Log a gap in <gap index> with label <gap-label>. Do not substitute."
            }
          }
        }
      }
    }
  },
  "overrides": [
    { "includes": ["packages/ui/**"], "linter": { "rules": { "style": { "noRestrictedImports": "off" } } } }
  ]
}
```

Biome has no selector-based syntax restriction equivalent to ESLint's `no-restricted-syntax`. Cover raw elements with a GritQL plugin, or with the palette audit script, and check the Biome version's docs for the current options shape. CI runs `biome ci`.

## Stylelint

```json
{
  "rules": {
    "color-no-hex": [true, {
      "message": "Use a color token from DESIGN.md (var(--color-*)). No fit? Log a gap, do not add a literal."
    }],
    "function-disallowed-list": [["rgb", "rgba", "hsl", "hsla", "oklch", "oklab"], {
      "message": "Use a color token from DESIGN.md. Literal color functions live only in the token source."
    }],
    "declaration-property-value-disallowed-list": [{
      "/^(margin|padding|gap)/": ["/\\d+px/"]
    }, {
      "message": "Use a spacing token (var(--space-*)). No step fits? Log a gap with the value and the screen."
    }]
  },
  "overrides": [
    { "files": ["<token source paths>"], "rules": { "color-no-hex": null, "function-disallowed-list": null } }
  ]
}
```

CI runs `stylelint "**/*.css" --max-warnings=0`. For SCSS, styled-components or emotion, Stylelint needs a `customSyntax`: see [references/stacks/sass.md](../references/stacks/sass.md) and [references/stacks/css-in-js.md](../references/stacks/css-in-js.md).

## Checking a message

A message passes when an agent that reads only the message can do one of two things: use the named alternative, or log the gap at the named place. A message that only says what is wrong fails this check. Rewrite it.
