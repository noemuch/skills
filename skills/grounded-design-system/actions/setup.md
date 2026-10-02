# Action: setup

Purpose: build the answers the audit found missing, one phase per run, in the team's stack and conventions. Each phase ends with a readiness test and stops for human approval before the next one starts.

## Inputs

- The phase: `week1`, `week2` or `week3`. With no phase, follow the routing rule in [SKILL.md](../SKILL.md#route-the-request).
- `design-system-audit.md` at the repository root. When it is absent, run [audit](audit.md) and stop.

## Phases

| Phase | Closes | Areas | Question | Produces, adapted to the stack and the scope |
| --- | --- | --- | --- | --- |
| `week1` | Describe the catalog | 1, 2, 3, 4, 7, 15 (canonical forms recorded) | What am I using here? | Agent files where the audit's `Scope:` line says they live (root `AGENTS.md` and `CLAUDE.md` as `@AGENTS.md` for contributors; for consumers of a published package, a guidance file the package ships), `.agents/` layout with symlinks, `DESIGN.md`, metadata sidecar type and generator, sidecars for the first directory of components, the team's canonical form for each intent the consistency area found, stale pages marked or removed per the team's answer |
| `week2` | Enforce it in CI | 5, 6, 8, 9, 10, 11, 13, 15 (canonical forms enforced) | What am I not allowed to do? | Semantic token gaps listed as questions, palette audit, token contract test, lint messages written for the agent, installed design rules turned on, exceptions test, agent hooks, a regeneration diff on committed output, one merge-blocking check (visual regression or registry diff) |
| `week3` | Log what's missing | 12, 14 | What happens when the answer doesn't exist? | Flag instruction in the agent files, `GAPS.md` or a gaps section, the gap label the team chose (created only on its approval), raw-element warnings with the gap obligation, change types, blast radius, changelog check, learning-loop routing |

The Phase column of the area table in [audit.md](audit.md#areas-and-probes) is the same mapping, read from the audit side. Each phase only builds what the audit scored below `answered` for its areas. An area already `answered` is left untouched and named in the report as kept.

## Steps

1. Read `design-system-audit.md`, including its `Scope:` line. List the areas of this phase that are not `answered`, with their evidence. When none remain, report that the phase is complete and stop. When the `Scope:` line holds an unanswered assumption, ask it first.
2. Run `sh scripts/detect-stack.sh "$ROOT"` again. Load the stack references it lists, and the references this phase needs:
   - `week1`: [agent-files.md](../references/agent-files.md), [catalog.md](../references/catalog.md), [tokens.md](../references/tokens.md)
   - `week2`: [tokens.md](../references/tokens.md), [enforcement.md](../references/enforcement.md), [change-types.md](../references/change-types.md#visual-regression)
   - `week3`: [doctrine.md](../references/doctrine.md#the-gap-loop), [enforcement.md](../references/enforcement.md#raw-elements-nudge-not-ban), [change-types.md](../references/change-types.md)
3. Collect the team decisions this phase depends on, from the audit's questions and from what you find now: names, canonical forms, the gap label, the exception marker, the themes in scope. Ask them in one message, numbered, each with the options the repository suggests and the evidence. Wait for answers. A decision left unanswered becomes a placeholder that fails loudly (`QUESTION: ...` in a test, a CI step that prints the open question), never a default you chose.
4. Write the plan: every file to create or change, its purpose in one line, the template it comes from, and the command that verifies it. Prefer the team's existing file and format over a template. Show the plan and wait for an explicit yes.
5. For each new file, adapt the template from [templates/](../templates/): replace `@acme/ui` with the real package, paths with the real paths, commands with the real package manager scripts, and every `<placeholder>` (`<gap-label>`, `<exception-marker>`, theme names) with the team's answer. Remove template sections the stack does not need.
6. For each existing file, show the unified diff and wait for an explicit yes before writing it. Merge into the existing structure; never replace a file wholesale.
7. Run the banned-word check from [agent-files.md](../references/agent-files.md#lint-the-rules-themselves) on every file you wrote. Rewrite each hit into a mechanical form, or turn it into a question.
8. Run each verification command from the plan. A check that fails on existing code is reported with its count; make it a warning or scope it to clean directories, and say which. Never weaken a check silently.
9. Run the readiness test for this phase from [readiness-tests.md](../references/readiness-tests.md): `catalog` and `tokens` for `week1`, `enforcement` and `ci` for `week2`, `gaps` for `week3`.
10. Update the scored areas in `design-system-audit.md` with the new evidence, after showing the diff.
11. Report in the format below and stop. The next phase starts on a new request.

## Stop conditions

- The user declines the plan or a diff: stop, keep what was approved, list what was not written.
- A decision blocks a file and the user cannot answer now: write the file with the failing placeholder from step 3 only if the user approves that; otherwise skip the file and log the decision with [gap](gap.md).
- A command would install a dependency: list it in the plan with the exact install command, and run it only after explicit approval.
- A verification command fails for a reason unrelated to this phase (broken build, failing unrelated tests): stop and report it. Do not fix unrelated code.

## Completion criteria

The phase is complete when all of these hold:

- Every file in the approved plan exists, and no other file changed (`git status --porcelain` matches the plan).
- Every generated rule names its condition, pattern, number or list, and its verification command ran.
- The banned-word check returns nothing on generated files.
- Every team decision is answered by the team, or present as a failing placeholder or a logged gap.
- The phase's readiness test ran and its report is included.

## Output format

```markdown
## Setup <phase>: report

### Written
| File | Purpose | Template | Verified by | Result |
| --- | --- | --- | --- | --- |

### Kept as is
- `<path>`: already answered, <evidence>

### Decisions
| Question | Answer | Source |
| --- | --- | --- |
| Canonical dialog | `Dialog`; `Modal` deprecated | user, this session |
| Value of `--warning` in each theme | open | placeholder fails in `tests/tokens.test.ts:41` |

### Readiness test
<report from readiness-tests.md>

### Next
<the next phase and the areas it closes, or "all phases complete">
```
