# Readiness tests

This file defines the test that tells whether the system speaks in an area: give an agent a real decision, only the written context, and one instruction. `test` runs it on demand, and every `setup` phase ends with it.

## The protocol

1. **Pick a real decision.** One the team argued about in the last quarter, with a known answer. Ask the user for it. A decision you invent tests your invention, not the system. When the user has none, use a decision from the area table below and state that it is a stand-in.
2. **Assemble only the written context.** The files an agent would load for this task: `AGENTS.md`, `DESIGN.md`, the matching path-scoped rules, the catalog entries, the relevant source. List them by path. Nothing from this conversation, nothing from memory.
3. **Run it fresh.** Use a subagent or a new session with no access to this conversation. Give it the context paths, the decision, and this instruction verbatim:

   ```text
   Flag missing context. Do not invent it.
   For each part of your answer, cite the file and line that supports it.
   List separately what you could not determine from these files.
   ```

4. **Score the output** against the table below.
5. **Record the result** in the report: decision, context paths, the agent's output verbatim, score, the rules it applied with their citations, and each "could not determine" item classified `missing`, `disconnected`, `stale` or `violated`.

When no subagent or fresh session is available, say so in the report, run the test in the current context, and mark the result `contaminated: ran with conversation context`.

## Reliable or unreliable

| Signal | Reliable | Unreliable |
| --- | --- | --- |
| Rule application | Applies the team's rule and cites `path:line` | Applies a generic best practice with no citation |
| Tokens and components | Names tokens and components that exist in the repository | Names plausible ones that do not exist, or raw values |
| Unknowns | Lists what it could not determine, specifically | Lists nothing, or lists generic caveats ("depends on your brand") |
| Tone | Short, specific, sometimes "the files do not say" | Fluent, complete, generic |

**If the answer applies your rule and names what it could not determine, the system is speaking. If it is fluent and generic, the system is still silent there.**

Score each area:

- `speaks`: every claim cited, every unknown named.
- `partial`: some claims cited, some invented or unflagged.
- `silent`: fluent and generic, or invents tokens or components.

Verify every citation: open the file at the cited line. A citation to a line that does not say what the agent claims counts as an invention.

## Area table

Use these stand-in decisions only when the user has no real one.

| Area | Question it probes | Stand-in decision |
| --- | --- | --- |
| `catalog` | What am I using here? | "Build a filter bar for the orders list with a date range and a status select." |
| `tokens` | What am I using here? | "A design shows secondary text in `#6B7280` and a warning banner. Which tokens?" |
| `enforcement` | What am I not allowed to do? | "Add a new icon to the settings page. Which import, and what if it does not exist?" |
| `gaps` | What happens when the answer doesn't exist? | "Build a saved-views toolbar for a table." (pick a pattern the catalog does not hold) |
| `ci` | What am I not allowed to do? | "Change the padding of Button. What must the PR contain before merge?" |
| `workflow` | What am I not allowed to do? | "Rename a prop on Dialog. Walk through the steps from spec to merge." |

The `gaps` test passes only when the agent refuses to build the missing pattern and produces a gap entry (issue text or `GAPS.md` line). Building it, even well, scores `silent`.

## Report format

```markdown
## Readiness test: <area>

- Decision: <the decision, and whether it is real or a stand-in>
- Context given: `AGENTS.md`, `DESIGN.md`, `.agents/rules/components.md`, ...
- Run: fresh subagent | contaminated: ran with conversation context
- Score: speaks | partial | silent

### Output (verbatim)
<the agent's answer>

### Rules applied
| Claim | Cited | Holds |
| --- | --- | --- |

### Could not determine
| Item | Class | Next step |
| --- | --- | --- |
| Value of `--warning` in each theme | missing | Question for the team |
```
