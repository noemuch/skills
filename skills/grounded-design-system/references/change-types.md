# Change types and the CI gate

This file covers CI as the last reader: the four change types, blast radius tiers, what runs on every pull request, and the workflow that moves work through those checks. Everything upstream can be skipped by an agent or a person in a hurry. CI runs every time, on every change, whoever wrote it.

## Every change has a type

A change to the system has exactly one type, declared in the spec before code is written.

| Type | Definition | Evidence required |
| --- | --- | --- |
| `create` | A new component or pattern | Sidecar with status, example, snapshots in light and dark |
| `refine` | Visual only, no API change | Before and after screenshots of the component and of sampled consumers |
| `extend` | Additive API change, nothing removed or renamed | Public API diff shows additions only; existing snapshots unchanged |
| `refactor` | Identical rendered DOM, identical public API | Rendered HTML diff is empty; API diff is empty |

When the work drifts from its declared type, a `refine` that starts touching props, it returns to the spec instead of becoming something else. This is the defense against an agent improving things nobody asked it to touch.

Declare the type where CI can read it: a PR title prefix (`refine(button): ...`), a label (`change:refine`) or a field in the spec file. Which one is a team decision.

### Prove a refactor

Render every example to static HTML on the base branch and on the PR branch, then diff:

```bash
git worktree add --detach /tmp/base origin/main
(cd /tmp/base && npm ci && npm run render:examples -- --out /tmp/dom-before)
npm run render:examples -- --out /tmp/dom-after
git worktree remove /tmp/base
diff -r /tmp/dom-before /tmp/dom-after \
  && echo "refactor: DOM identical" \
  || { echo "DOM changed. This is not a refactor. Return to the spec and redeclare the type."; exit 1; }
```

`render:examples` is a small script calling `renderToStaticMarkup` (React), `renderToString` (Vue, Svelte) or the framework's equivalent on each example. Normalize generated ids before diffing.

### Prove an extend

Diff the public API surface. With TypeScript, `api-extractor` or a `tsc --declaration` output diffed against the base: every changed line starts with `+`.

## Blast radius

A change to a component used twice and a change to one used three hundred times are different changes. A script counts consumers before anything merges, and the count sets the evidence.

```text
consumers    evidence required
0 to 10      standard checks
11 to 50     + screenshots of 3 consumers
over 50      + 5 consumers and a human note in the PR
```

Count consumers by import, not by name match:

```bash
rg -l --glob '!**/*.test.*' --glob '!**/*.stories.*' \
  "from ['\"]@acme/ui/button['\"]|from ['\"]@acme/ui['\"].*\bButton\b" src apps \
  | sort > /tmp/consumers.txt
wc -l < /tmp/consumers.txt
```

Sample deterministically, first, middle and last by path, so nobody, human or agent, picks the three that happen to look right:

```bash
n=$(wc -l < /tmp/consumers.txt)
sed -n "1p;$(( (n + 1) / 2 ))p;${n}p" /tmp/consumers.txt          # 3 consumers
sed -n "1p;$(( n / 4 + 1 ))p;$(( (n + 1) / 2 ))p;$(( 3 * n / 4 ))p;${n}p" /tmp/consumers.txt  # 5 consumers
```

The tier thresholds are the article's defaults. The team can move them; record the numbers in `AGENTS.md` so the agent reads the same ones CI uses.

## What runs on every pull request

| Check | Fails when |
| --- | --- |
| Registry regen | `git diff --exit-code` on the registry after regeneration is non-empty |
| Palette audit | A hex, color function or arbitrary value without a reason comment appears outside the token source |
| Lint | Any warning (`--max-warnings=0`) |
| Token contract | A semantic token is missing in a theme or aliases the wrong scale |
| Visual regression | A documented example differs from main, in light or dark, beyond the threshold |
| Changelog | A touched component has no changelog entry (warning first, blocking once adopted) |
| Change type | A declared `refactor` changes DOM, a declared `extend` removes API |
| Blast radius | The tier's evidence is missing from the PR body |

[templates/ci-design-system.yml](../templates/ci-design-system.yml) wires these as GitHub Actions jobs. Translate to the CI provider `detect-stack.sh` reports.

None of these checks is clever. Their value is that they run every time.

### Visual regression

Render every documented example in light and dark and pixel-diff against main. Playwright's `toHaveScreenshot` is enough to start:

```ts
for (const theme of ["light", "dark"] as const) {
  test(`${slug} ${theme}`, async ({ page }) => {
    await page.goto(`/examples/${slug}?theme=${theme}`)
    await expect(page).toHaveScreenshot(`${slug}-${theme}.png`, { maxDiffPixelRatio: 0.001 })
  })
}
```

Generate snapshots in the CI container, never on a laptop: font rendering differs per OS and every run fails otherwise.

### Changelog check

```bash
changed=$(git diff --name-only origin/main...HEAD -- 'packages/ui/src/components/*' \
  | sed -E 's#packages/ui/src/components/([^/]+)/.*#\1#' | sort -u)
for c in $changed; do
  git diff --name-only origin/main...HEAD | grep -q "packages/ui/src/components/$c/CHANGELOG.md" \
    || echo "::warning::$c changed without a CHANGELOG.md entry. Add one line: type, what, why."
done
```

## Workflow

- **Spec, then tasks.** Every system change starts as a written spec: its type, its API delta, the decision it implements. The spec becomes a plan of small tasks, 2 to 5 minutes each.
- **Three passes per task.** One agent implements, one checks compliance with the spec, one reviews quality. A blocked task is reported, never silently retried.
- **One sanctioned path to a pull request.** A single command or script reviews the diff (framework rules, interface guidelines, accessibility, design system conformance) in report-only mode, applies fixes one at a time, sweeps for raw elements that should be system components and writes the changelog entry. Every PR goes through it.
- **Isolation.** Every branch gets its own worktree, dev server port and data. Hooks refuse edits that escape the current worktree. Parallel agents help only when they cannot step on each other.
- **Learning without drift.** When a session reveals something, route it: an actionable fix becomes an issue, a recurring convention becomes a rule, a story becomes a note. A `learn` step proposes each edit for approval one by one, and writes only to reference files. Instructions, prompts and the policy governing the skill stay read-only, because a skill that edits its own rules can widen its own permissions.

## Pitfalls

- Snapshot thresholds loose enough to never fail prove nothing. Start strict and raise per example with a reason.
- Counting consumers with a bare name search counts comments and unrelated identifiers. Count imports.
- A changelog check that blocks on day one gets bypassed. Ship it as a warning for one cycle.
