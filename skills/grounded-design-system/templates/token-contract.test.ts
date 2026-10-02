/**
 * Template from grounded-design-system: contract tests on the token layer itself,
 * never on component class names. Parses CSS custom properties with no dependency
 * and runs under Vitest (or Jest: swap the import). Fill the CONTRACT tables with the
 * team's decisions. An open decision stays as a QUESTION entry, which fails with the
 * question as its message until someone answers it.
 */
import { readFileSync } from "node:fs"
import { describe, expect, test } from "vitest"

// REPLACE: the token source and the selector of each theme block.
const SOURCE = "src/styles/tokens.css"
const THEMES = { light: ":root", dark: ".dark" } as const

// Every semantic token components may read. Each must be defined in every theme.
const SEMANTIC = [
  "background",
  "foreground",
  "muted-foreground",
  "border",
  "destructive",
] as const

// Which primitive scale each semantic token must alias, per theme.
// A string is a regex on the declared value. "QUESTION: ..." marks an open decision.
// REPLACE: these rows are examples of the format, not decisions.
const ALIASES: Record<(typeof SEMANTIC)[number], string> = {
  background: "^var\\(--(white|black|gray-\\d+)\\)$",
  foreground: "^var\\(--gray-\\d+\\)$",
  "muted-foreground": "^var\\(--gray-\\d+\\)$",
  border: "^var\\(--gray-\\d+\\)$",
  destructive: "^var\\(--red-\\d+\\)$",
}

type Block = Record<string, string>

/** Collects `--name: value;` declarations of every rule whose selector list contains `selector`. */
function declarations(css: string, selector: string): Block {
  const out: Block = {}
  const withoutComments = css.replace(/\/\*[\s\S]*?\*\//g, "")
  const rule = /([^{}]+)\{([^{}]*)\}/g
  for (const [, selectors, body] of withoutComments.matchAll(rule)) {
    const list = selectors.split(",").map((s) => s.trim())
    if (!list.includes(selector)) continue
    for (const [, name, value] of body.matchAll(/--([\w-]+)\s*:\s*([^;]+);/g)) {
      out[name] = value.trim()
    }
  }
  return out
}

const css = readFileSync(SOURCE, "utf8")
const blocks = Object.fromEntries(
  Object.entries(THEMES).map(([theme, selector]) => [theme, declarations(css, selector)]),
) as Record<keyof typeof THEMES, Block>

describe("token contract", () => {
  for (const [theme, block] of Object.entries(blocks)) {
    test(`${theme}: theme block exists in ${SOURCE}`, () => {
      expect(Object.keys(block).length, `no declarations found for ${THEMES[theme as keyof typeof THEMES]}`).toBeGreaterThan(0)
    })

    for (const token of SEMANTIC) {
      test(`${theme}: --${token} is defined`, () => {
        expect(block[token], `--${token} missing in ${theme}. Add it to ${SOURCE}.`).toBeDefined()
      })

      test(`${theme}: --${token} aliases its contracted scale`, () => {
        const contract = ALIASES[token]
        if (contract.startsWith("QUESTION:")) throw new Error(`Open team decision for --${token}: ${contract}`)
        expect(block[token], `--${token} in ${theme} breaks its contract ${contract}`).toMatch(new RegExp(contract))
      })
    }
  }

  test("semantic tokens hold aliases, never literals", () => {
    const literal = /#[0-9a-f]{3,8}\b|\b(rgb|hsl|oklch|oklab)a?\(/i
    for (const [theme, block] of Object.entries(blocks)) {
      for (const token of SEMANTIC) {
        expect(block[token] ?? "", `--${token} in ${theme} holds a literal. Point it at a primitive.`).not.toMatch(literal)
      }
    }
  })
})
