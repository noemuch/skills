# Stack: Style Dictionary and DTCG

This file maps the token layer onto a repository that builds tokens from JSON with Style Dictionary or another DTCG-format pipeline. Load it when `detect-stack.sh` lists `style-dictionary` in `stack-refs`.

## Detect

| Signal | Meaning |
| --- | --- |
| `style-dictionary` in `package.json`, `sd.config.*` or `config.json` with `platforms` | Style Dictionary build |
| `*.tokens.json` or JSON with `$value` and `$type` | DTCG format |
| JSON with `value` and `type` (no `$`) | Legacy Style Dictionary format |
| `@tokens-studio/sd-transforms` | Tokens Studio pipeline |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Source | The JSON token files. Built CSS, TS and platform files are generated |
| Usage | `$description` on each semantic token; DESIGN.md's usage column is generated from it |
| Generated files | Add every build output to the hook's generated list. An agent edits JSON, then runs the build |
| Regen check | `npm run tokens:build && git diff --exit-code <output dir>` in CI |
| Contract test | Parse the JSON directly: every semantic token has a value in every theme file, and aliases (`{color.red.500}`) point into the scale the contract names |

```json
{
  "color": {
    "text": {
      "muted": {
        "$value": "{color.gray.500}",
        "$type": "color",
        "$description": "Secondary text: captions, metadata, helper text. Never for disabled states."
      }
    }
  }
}
```

Contract test sketch over DTCG JSON:

```ts
const semantic = flatten(readJson("tokens/semantic.light.tokens.json"))
test("destructive aliases the red scale", () => {
  expect(semantic["color.destructive"].$value).toMatch(/^\{color\.red\.\d+\}$/)
})
```

## Pitfalls

- Build outputs committed and hand-edited drift from the JSON. The regen check catches it; the hook prevents it.
- Theme files that each restate the full token tree hide a missing token in one theme. Assert key parity across theme files.
- `$description` empty on a semantic token is a `missing` usage. List the count in the audit; ask the team for the usage text.
- Name transforms (kebab, camel) differ per platform. DESIGN.md shows the name as components write it.
