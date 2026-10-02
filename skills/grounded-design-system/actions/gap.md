# Action: gap

Purpose: record that the design system has no answer for something an agent or a person needed, at the moment of need, so the gap closes once for everyone instead of being worked around. This action logs. It never builds.

## Inputs

- `<description>`: what is missing, in the words of the need. Example: `gap saved views toolbar for the orders table`.
- Context the agent already has: the screen or file that needed it, and the raw element or value it would otherwise use.

## Steps

1. Restate the gap as one capability line: the thing, a colon, what it must do. Example: `Saved views: list toolbar keeps filters`.
2. Search the catalog, `GAPS.md` and open issues for an existing entry:

   ```bash
   rg -n -i '<keyword>' GAPS.md $(git ls-files '*.meta.ts' '*.meta.json') 2>/dev/null
   gh issue list --label area:design-system --search '<keyword>' --state open 2>/dev/null
   ```

   When an entry exists, add the new need to it (a comment on the issue with the screen path) and go to step 6.
3. Classify the gap `missing`, `disconnected` or `stale` per [doctrine.md](../references/doctrine.md#gap-classes). A `disconnected` gap names where the answer lives today.
4. Create the issue when `gh auth status` succeeds and the repository has a GitHub remote:

   ```bash
   gh issue create \
     --title "Saved views: list toolbar keeps filters" \
     --label area:design-system \
     --body "$(cat <<'EOF'
   Class: missing
   Needed by: apps/web/src/orders/page.tsx
   Need: users reapply the same four filters on every visit to the orders list.
   Today: no saved-views pattern in the catalog. The screen ships without it.
   Logged by: agent, during <task>.
   EOF
   )"
   ```

   When the label does not exist, ask the user before creating it: labels are a team decision. Without approval, create the issue without the label and say so.
5. Add one line to the gap index. Use the location the repository already has (`GAPS.md`, a `## Component gaps` section in the UI package README). When none exists, propose `GAPS.md` at the root from [templates/GAPS.md](../templates/GAPS.md), show it, and create it after a yes.

   ```markdown
   - Saved views: list toolbar keeps filters (#412)
   ```

   Without `gh`, write the line with `(no issue yet)` in place of the number.
6. When a catalog exists, propose a sidecar with `status: "missing"` and the issue number, per [catalog.md](../references/catalog.md#status-vocabulary). Show it; write after a yes.
7. Return to the original task. Leave the screen without the missing piece, or keep the raw element with an inline disable naming the gap, per [enforcement.md](../references/enforcement.md#raw-elements-nudge-not-ban). Report the gap in the task's final message.

## Stop conditions

- The description is a preference, not a missing capability ("make buttons rounder"): stop and say it belongs to a design discussion, not the gap index.
- The search finds the capability exists in the catalog: stop, name the component and its usage, and use it.

## Completion criteria

- Exactly one new issue or one comment on an existing issue, when `gh` is available.
- Exactly one new line in the gap index, or none when the gap was already listed.
- No component, token, style or workaround was created by this action.

## Output format

```markdown
Gap logged: Saved views: list toolbar keeps filters
- Class: missing
- Issue: #412 (created) | #412 (comment added) | not created: gh unavailable
- Index: GAPS.md:14
- Original task: continues without the toolbar; raw element kept at `apps/web/src/orders/page.tsx:88` with `-- gap #412`
```
