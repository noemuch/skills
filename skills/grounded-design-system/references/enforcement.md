# Enforcement

This file covers the mechanisms that hold when the agent did not read, misread or decided it knew better: the palette audit, lint messages written for the agent, exception allowlists and agent hooks. It answers "What am I not allowed to do?" in a form a machine has to respect.

Propose each mechanism in the team's existing tool. A repository on Biome gets Biome rules, not an ESLint config.

## Palette and hardcoded-value audit

A CI step scans component code and fails on:

- Hex, `rgb()`, `hsl()`, `oklch()` literals and named colors outside the token source.
- Raw palette steps from palettes the system does not use (`bg-pink-500` when pink is not in the system).
- Arbitrary values without the team's exception marker on the same or previous line.

Two values come from the team, never from this skill: the token source paths (start from `token-source:` in the inventory) and the exception marker, the comment prefix that says "this literal is deliberate". Ask both before writing the gate.

Start from the measurement, then turn it into a gate:

```bash
sh scripts/count-hardcoded.sh .   # baseline per directory
```

```bash
# scripts/palette-audit.sh: fails on a color literal in component code without the exception marker
TOKEN_SOURCES='<ERE matching the token source paths>'   # REPLACE, from detect-stack.sh token-source:
EXCEPTION_MARKER='<exception-marker>'                    # REPLACE, the team's comment prefix
SOURCES='<component globs>'                              # REPLACE, e.g. 'src/*.tsx' (git pathspec, any depth)
files=$(git ls-files "$SOURCES" | grep -Ev "$TOKEN_SOURCES")
[ -n "$files" ] || exit 0
hits=$(printf '%s\n' "$files" | xargs grep -nE '(^|[^0-9A-Za-z&/])#([0-9A-Fa-f]{3,4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})([^0-9A-Za-z_-]|$)|(rgba?|hsla?|oklch)\([[:space:]]*[0-9.]' \
  | grep -vF "$EXCEPTION_MARKER" || true)
if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  echo "Hardcoded color. Use a semantic token from DESIGN.md. No token fits? Log a gap, do not add a literal."
  exit 1
fi
```

The marker check here reads the same line only. To accept a marker on the previous line, run the scan in `awk` and keep the previous line. Extend the pattern with the named colors and units `count-hardcoded.sh` reports for this repository.

Adopt the gate per directory: directories at zero become blocking first, the rest join as they reach zero. A gate that fails on day one gets disabled on day two.

## Lint messages written for the agent

A lint error is a message to whoever reads it next, and today that is usually an agent. Every message states what to do instead and where to go when the right answer does not exist.

```js
// What most configs say
message: "Do not import lucide-react.",

// What a grounded config says
message:
  "Use an approved glyph from @acme/icons. " +
  "No match? Log the gap in GAPS.md, do not substitute.",
```

The first version produces an agent that swaps one forbidden icon library for another. The second produces the right icon or a logged gap.

Message shape, every time:

```text
<What to use instead, with its import path>. <What to do when it does not fit: log a gap, with where>.
```

Ready-made messages for ESLint, Biome and Stylelint are in [templates/lint-messages.md](../templates/lint-messages.md). Run lint with warnings as errors in CI (`eslint --max-warnings=0`, `biome ci`, `stylelint --max-warnings=0`).

### Raw elements: nudge, not ban

The system prefers its components over raw HTML. A raw `<button>` is sometimes right because the component does not exist. Make the rule a warning that carries the obligation, not an error that forces a workaround:

```js
"no-restricted-syntax": ["warn", {
  selector: "JSXOpeningElement[name.name='button']",
  message:
    "Use Button from @acme/ui. If Button cannot do this, keep the raw element " +
    "and log a gap: gh issue create --label <gap-label>, plus one line in GAPS.md.",
}]
```

With warnings as errors in CI, the raw element merges only with an inline disable that names the gap:

```tsx
{/* eslint-disable-next-line no-restricted-syntax -- gap #412 saved views toolbar */}
<button ...>
```

## Exception allowlists live in a test

When an exception is real, it lives in a test file, one entry per file, each with its reason. An exception without a reason is a precedent waiting to be copied.

```ts
// tests/design-system-exceptions.test.ts
const HEX_ALLOWED: Record<string, string> = {
  "src/charts/series-colors.ts": "Series colors come from the data contract, gap #377",
  "src/email/templates/base.tsx": "Email clients ignore CSS variables",
}

test("every allowlisted file still contains a hex literal", () => {
  for (const file of Object.keys(HEX_ALLOWED)) {
    expect(readFileSync(file, "utf8")).toMatch(/#[0-9a-f]{3,8}/i)
  }
})

test("every exception has a reason of at least 20 characters", () => {
  for (const [file, reason] of Object.entries(HEX_ALLOWED)) {
    expect(reason.length, file).toBeGreaterThanOrEqual(20)
  }
})
```

The first test removes entries that no longer need the exception. The audit script reads the same table to skip those files. The reason text is the team's: the skill writes the entry with `reason: "QUESTION: why is this allowed?"` and the test fails until someone answers.

## Agent hooks

Agents run tools, which gives one more place to enforce: the moment before the call. A hook refuses a handful of actions outright and says what to do instead, because the agent reads the refusal and acts on it.

Block these by default, adapted to the repository:

| Action | Detection | Message |
| --- | --- | --- |
| Edit a generated file | `file_path` matches the generated list (`registry.json`, `src/tokens.generated.ts`) | "Generated by `npm run registry:build`. Edit the `.meta.ts` source, then rerun the command." |
| Skip validation | Bash command contains `--no-verify` | "--no-verify skips the checks that protect main. Fix the failing validation, then commit again." |
| Commit on main | Bash `git commit` while the current branch is `main` or `master` | "Create a branch first: git switch -c <type>/<topic>." |
| Write outside the worktree | `file_path` does not start with the project directory | "This path is outside the current worktree. Work in the worktree for this branch." |
| Real skill under a tool folder | `file_path` under `.claude/skills/` and not a symlink target | "Skills live in .agents/skills/ and are symlinked into .claude/skills/. Other agents never see this file." |

A refusal with a next step costs the agent one turn. A bare "denied" costs ten turns of creative workarounds, which can be worse than not blocking.

[templates/hooks/](../templates/hooks/) holds a Claude Code `PreToolUse` script and its settings snippet. For other tools, put the same checks in git hooks (`pre-commit`, `pre-push`) and in CI, so every agent hits the same wall.

## Pitfalls

- A restricted import with no alternative in the message makes the agent pick another forbidden library.
- An error-level raw-element ban produces a styled `<div role="button">`, which is worse. Keep it a warning with the gap obligation.
- A hex pattern also matches anchors made of hex letters (`href="#add"`). Read the first run of hits before making the gate blocking, and tighten the pattern to the contexts that hold colors in this codebase.
- An allowlist in a lint config comment has no reason field. Move it to the test.
- A hook that blocks on a regex over the whole command line blocks `git log --grep=--no-verify`. Match the command and its flags, not substrings anywhere.
