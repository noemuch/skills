# Action: gap

Purpose: record that the design system has no answer for something an agent or a person needed, at the moment of need, so the gap closes once for everyone instead of being worked around. This action logs. It never builds.

## Inputs

- `<description>`: what is missing, in the words of the need. Example: `gap saved views toolbar for the orders table`.
- Context the agent already has: the screen or file that needed it, and the raw element or value it would otherwise use.

## Steps

1. Restate the gap as one capability line: the thing, a colon, what it must do. Example: `Saved views: list toolbar keeps filters`.
2. Find where gaps go in this repository. Read `AGENTS.md`, `GAPS.md` and the UI package README for the gap index location and the gap label the team recorded. When no label is recorded and `gh auth status` succeeds, list the labels and ask the user which one marks a design-system gap:

   ```bash
   gh label list --limit 200
   ```

   Never create a label: it is a team decision. When the user names a label that does not exist, give them `gh label create '<gap-label>'` to run, and continue without a label until it exists. Offer to record the answer in `AGENTS.md` so the next run reads it; write it only after showing the diff and getting a yes.
3. Search the catalog, the gap index and open issues for an existing entry:

   ```bash
   rg -n -i '<keyword>' GAPS.md $(git ls-files '*.meta.ts' '*.meta.json') 2>/dev/null
   gh issue list --label '<gap-label>' --search '<keyword>' --state open 2>/dev/null   # without a label: drop --label
   ```

   When an entry exists, add the new need to it (a comment on the issue with the screen path) and go to step 7.
4. Classify the gap `missing`, `disconnected`, `stale` or `violated` per [doctrine.md](../references/doctrine.md#scores-and-gap-classes). A `disconnected` gap names where the answer lives today. A `violated` gap names the rule the code bypasses.
5. Create the issue when `gh auth status` succeeds and the repository has a GitHub remote. Pass `--label` only with the label from step 2:

   ```bash
   gh issue create \
     --title "Saved views: list toolbar keeps filters" \
     --label '<gap-label>' \
     --body "$(cat <<'EOF'
   Class: missing
   Needed by: apps/web/src/orders/page.tsx
   Need: users reapply the same four filters on every visit to the orders list.
   Today: no saved-views pattern in the catalog. The screen ships without it.
   Logged by: agent, during <task>.
   EOF
   )"
   ```

6. Add one line to the gap index. Use the location the repository already has (`GAPS.md`, a gaps section in the UI package README). When none exists, propose `GAPS.md` at the root from [templates/GAPS.md](../templates/GAPS.md), show it, and create it after a yes.

   ```markdown
   - Saved views: list toolbar keeps filters (#412)
   ```

   Without `gh`, write the line with `(no issue yet)` in place of the number.
7. When a catalog exists, propose a sidecar with `status: "missing"` and the issue number, per [catalog.md](../references/catalog.md#status-vocabulary). Show it; write after a yes.
8. Return to the original task. Leave the screen without the missing piece, or keep the raw element with an inline disable naming the gap, per [enforcement.md](../references/enforcement.md#raw-elements-nudge-not-ban). Report the gap in the task's final message.

## Stop conditions

- The description is a preference, not a missing capability ("make buttons rounder"): stop and say it belongs to a design discussion, not the gap index.
- The search finds the capability exists in the catalog: stop, name the component and its usage, and use it.

## Completion criteria

- Exactly one new issue or one comment on an existing issue, when `gh` is available.
- Exactly one new line in the gap index, or none when the gap was already listed.
- No component, token, style, label or workaround was created by this action.

## Output format

```markdown
Gap logged: Saved views: list toolbar keeps filters
- Class: missing
- Issue: #412 (created, label <gap-label>) | #412 (created, no label: none chosen yet) | #412 (comment added) | not created: gh unavailable
- Index: GAPS.md:14
- Original task: continues without the toolbar; raw element kept at `apps/web/src/orders/page.tsx:88` with `-- gap #412`
```
