---
description: <One line: what this rule governs. Cursor shows it in the rule picker.>
paths:
  - "<glob, e.g. packages/ui/src/components/**>"
globs: <same glob, comma-separated for Cursor>
---

<!--
Template from grounded-design-system: one path-scoped rule. Save the real file in
.agents/rules/<name>.md and symlink it into .claude/rules/ and .cursor/rules/.
Claude Code reads `paths`, Cursor reads `globs`. Every bullet below must be one of:
a binary condition, a grep-able pattern, a number, an explicit list. Each bullet
names how it is verified. Delete this comment.
-->

# <Rule name, stating its point>

- <Binary condition>. Verified by: `<command>`.
  Example: A component file without a sibling `.meta.ts` fails `npm run registry:check`.
- <Grep-able pattern>. Verified by: `<command>`.
  Example: `rg -n 'text-\[#' packages/ui/src` returns nothing.
- <Number>. Verified by: `<command or review step>`.
  Example: Dialog width is at most `max-w-lg`.
- <Explicit list>. Verified by: `<command>`.
  Example: Icons come from `@acme/icons`. `lucide-react` and `react-icons` fail lint.

When this rule has no answer for the case at hand, log a gap (see `AGENTS.md`). Do not extend the rule on your own.
