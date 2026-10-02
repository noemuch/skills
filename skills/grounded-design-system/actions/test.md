# Action: test

Purpose: find out whether the system speaks in one area, by giving an agent a real decision, only the written context and the instruction to flag what is missing. The result says `speaks`, `partial` or `silent`, with the rules the agent applied set against the gaps it named, and the missing context classified.

Plugin users also reach this action through the `/readiness-check` command, which loads this file.

## Inputs

- `<area>`: one of `catalog`, `tokens`, `enforcement`, `gaps`, `ci`, `workflow`. With no area, ask which one, listing the areas `design-system-audit.md` scored lowest.
- A real decision the team argued about recently, with its known answer. Ask the user for it.

## Steps

1. Load [references/readiness-tests.md](../references/readiness-tests.md).
2. Ask the user for a real decision in this area and the answer the team reached. When the user has none, use the stand-in from the area table and state it in the report.
3. List the context files an agent would load for this decision: `AGENTS.md`, `DESIGN.md`, rules whose `paths` or `globs` match the files involved, catalog entries, the source files. Read them only to list them; do not summarize them for the test agent.
4. Run the test in a fresh subagent or session, with the file paths, the decision and the instruction from the protocol, verbatim. Give nothing else.
5. Check every citation in the output by opening the file at the cited line.
6. Compare the output to the team's answer. Score `speaks`, `partial` or `silent`.
7. Classify each "could not determine" item and each invention as `missing`, `disconnected`, `stale` or `violated`, per [doctrine.md](../references/doctrine.md#scores-and-gap-classes).
8. Write the report in the format from the protocol. Offer to log each `missing` item with [gap](gap.md); log only on a yes.

## Stop conditions

- The area is not one of the six: stop and list the six.
- No context files exist for the area (no `AGENTS.md`, no `DESIGN.md`, no rules): stop. The result is `silent` without running; report it and point to `setup week1`.

## Completion criteria

- The test agent received only file paths, the decision and the protocol instruction.
- Every citation was checked against the file.
- The report contains the verbatim output, the score and a classified list of unknowns.
- No file in the repository changed, except gap entries the user approved.

## Output format

The report format in [readiness-tests.md](../references/readiness-tests.md#report-format).
