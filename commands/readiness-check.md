---
description: Readiness test for a design system. Give a fresh agent one real decision, only the written context and the instruction to flag missing context, then report the rules it applied against the gaps it named.
argument-hint: "[catalog | tokens | enforcement | gaps | ci | workflow]"
---

Run the `test` action of the `grounded-design-system` skill on the area `$ARGUMENTS`.

1. Load the `grounded-design-system` skill and read its `actions/test.md` and `references/readiness-tests.md` (in this plugin: `skills/grounded-design-system/`). Follow `actions/test.md` step by step; this command adds nothing to it.
2. With no area, ask which one, listing the six and the ones `design-system-audit.md` scored lowest when it exists.
3. Ask the user for a real decision the team argued about recently, with the answer the team reached. Use the stand-in from the area table only when the user has none, and say so in the report.
4. Give a fresh subagent only the paths of the written context (`AGENTS.md`, `DESIGN.md`, matching rules, catalog entries, the source files), the decision, and this instruction verbatim:

   ```text
   Flag missing context. Do not invent it.
   For each part of your answer, cite the file and line that supports it.
   List separately what you could not determine from these files.
   ```

5. Check every citation against the file. Report, in the format of `references/readiness-tests.md`: the score (`speaks`, `partial` or `silent`), the rules the agent applied with their citations, and the gaps it named, each classified `missing`, `disconnected`, `stale` or `violated`.
6. Change no file in the repository. Offer to log each `missing` item with the skill's `gap` action, and log only on a yes.
