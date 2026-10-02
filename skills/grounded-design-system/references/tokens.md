# Tokens

This file covers the token layer: semantic names that carry a usage, how they are declared per stack, and the contract tests that hold them. Tokens answer "What am I using here?" through DESIGN.md and "What am I not allowed to do?" through the audit and the tests.

## Three layers, one direction

```text
primitive     --gray-500: #6B7280            a value on a scale
semantic      --muted-foreground: var(--gray-500)   a decision with a usage
component     --button-fg: var(--primary-foreground)  optional, only when a component overrides
```

Component code reads semantic tokens. Primitives are read only by semantic tokens. A component reading a primitive is a palette step, and it is the second of the three answers in [agent-files.md](agent-files.md#designmd-written-for-the-machine).

Which primitives exist, how semantic tokens are named and which usage each carries are team decisions. The audit inventories what exists and asks. It never renames a token.

## Where tokens are declared

| Stack | Declaration | Reference |
| --- | --- | --- |
| Tailwind v4 | `@theme` and `@theme inline` in a CSS file, with `:root` and one block per additional theme for values | [stacks/tailwind-shadcn.md](stacks/tailwind-shadcn.md) |
| Tailwind v3 | `theme` and `theme.extend` in `tailwind.config.*`, values often from CSS variables | [stacks/tailwind-shadcn.md](stacks/tailwind-shadcn.md) |
| Plain CSS | Custom properties on `:root`, plus one selector per additional theme | [stacks/css-only.md](stacks/css-only.md) |
| Sass or Less | Variables and maps for primitives, often emitted as custom properties per theme | [stacks/sass.md](stacks/sass.md) |
| CSS-in-JS | A theme object, a `createTheme` call or a config with `tokens` | [stacks/css-in-js.md](stacks/css-in-js.md) |
| Style Dictionary or DTCG | JSON with `$value` and `$type`, built to CSS, TS and platform files | [stacks/style-dictionary.md](stacks/style-dictionary.md) |
| Figma variables | Collections and modes, exported to DTCG JSON | [stacks/figma-variables.md](stacks/figma-variables.md) |

`detect-stack.sh` prints what it found under `token-source:` and `tokens-*:`, and the theme selectors under `themes:`. Exactly one of these is the source. When two exist (a DTCG file and a hand-edited CSS file), the audit scores the token area `stale` for the one that lost, and asks which one wins.

## Contract tests on tokens, never on component classes

Test the token layer itself. Never assert class names or computed styles on components: those tests break on every refactor and prove nothing a browser screenshot does not show better.

A contract test parses the token source and asserts relations that prose cannot hold:

- Every semantic token is defined in every theme.
- A status token aliases the right scale in each theme (`--destructive` reads from `red`, never from `orange`).
- Hover surfaces stay inside their contract (`--accent` is one step from `--background`, never three).
- No semantic token holds a literal where an alias is required.
- Foreground and background pairs meet a contrast floor the team chose, in each theme.

[templates/token-contract.test.ts](../templates/token-contract.test.ts) parses CSS custom properties without a dependency and runs under Vitest or Jest. It fits a token source written as CSS. For a theme object, import it instead of parsing ([stacks/css-in-js.md](stacks/css-in-js.md#contract-test)); for Sass, test the maps or the compiled output per theme ([stacks/sass.md](stacks/sass.md#contract-test)); for JSON, read the JSON ([stacks/style-dictionary.md](stacks/style-dictionary.md)). Fill its contract tables with the team's decisions. Leave a table empty and failing with a message pointing to the open question rather than guessing an alias.

## Arbitrary values

Arbitrary values (`w-[312px]`, `text-[#6B7280]`, inline `style={{ color }}`) are allowed only where no token exists, and only with a comment on the same or previous line that starts with the team's exception marker and states why. The marker is a team decision; ask it, then use it everywhere the audit and the gate read it.

```tsx
{/* <exception-marker> chart legend swatch matches series color from the data, no token by design */}
<span className="size-2 bg-[var(--series-color)]" />
```

The palette audit in [enforcement.md](enforcement.md#palette-and-hardcoded-value-audit) fails on an arbitrary value without that comment. When a design brings a value with no matching token, the agent stops and asks: either the system gets a new token, or the exception gets documented. Never a silent literal.

## Measure the current state

```bash
sh scripts/count-hardcoded.sh /path/to/repo
```

Read the usage counts per directory. The script reports matches inside token sources and on local definition lines (`$x:`, `--x:`) in separate columns: they are the system working. The repeated-values section shows literals written several times, which are candidate missing tokens or candidate equalities to report. Matches in component directories are candidates. Report both, label which is which, and never call a candidate a violation before reading the line.

## Pitfalls

- Naming tokens after values (`--gray-dark`) leaks the palette into the decision layer. Ask for usage names; do not rename.
- In a system with several themes, a token with the same value in two themes is often a forgotten override. List it as a question, not a fix.
- In Tailwind v4, a `@theme` variable that references another variable (`--color-background: var(--background)`) needs `@theme inline`. Without `inline`, the reference resolves where `--color-background` is declared, and a theme class that redefines `--background` on a subtree does not reach the utility.
- Contrast is measured on rendered pairs. A unit test on token values checks the declared pair only; say so in the test name.
