<!--
Template from grounded-design-system. Generate the token tables from the token
source; write the Usage column from the team's answers only. A usage you cannot
source is a question, not a sentence. The rows below are examples of the
format; replace every one. Delete this comment.
-->

# DESIGN.md

**Agents: read this file before writing any UI code.** It is the design language of this repository: every token with its light value, its dark value and its usage. A value without a usage is a palette. A value with a usage is a decision.

## Quick rules

- Never write hex, `rgb()`, `hsl()` or `oklch()` in component code. Use a token from the tables below.
- Never use a raw palette step (`gray-500`) where a semantic token exists.
- Match on usage, never on the nearest number. A design value of `#6B7280` maps to the token whose usage fits, even when another token has that exact value.
- When no token fits the usage, stop and log a gap (see `AGENTS.md`). Never write a literal.
- Token source: `<path to the CSS, JSON or config file>`. This file's tables are generated from it by `<command>`.

## Color

| Token | Light | Dark | Usage |
| --- | --- | --- | --- |
| `background` | `#FFFFFF` | `#0A0A0A` | Page background. Never for raised surfaces. |
| `foreground` | `#0A0A0A` | `#FAFAFA` | Body text and icons on `background`. |
| `muted-foreground` | `#6B7280` | `#9CA3AF` | Secondary text: captions, metadata, helper text. Never for disabled states. |
| `border` | `#E5E7EB` | `#262626` | Dividers and input borders. Never for focus. |
| `destructive` | `#DC2626` | `#EF4444` | Irreversible actions and error text. Never for warnings. |

## Spacing

| Step | Value | Usage |
| --- | --- | --- |
| `1` | `4px` | Icon to label inside a control. |
| `2` | `8px` | Between controls in a group. |
| `4` | `16px` | Card padding. Gap between form fields. |
| `6` | `24px` | Between sections inside a page. |

## Radius

| Token | Value | Usage |
| --- | --- | --- |
| `radius-sm` | `4px` | Badges, checkboxes. |
| `radius-md` | `8px` | Buttons, inputs. |
| `radius-lg` | `12px` | Cards, dialogs. A nested surface uses outer radius minus padding. |

## Typography

| Token | Size / line height | Usage |
| --- | --- | --- |
| `text-sm` | `14px / 20px` | Body text in dense UI: tables, forms. |
| `text-base` | `16px / 24px` | Body text in reading surfaces. |

## Warnings agents need

- <A mistake agents make in this repository by default, written as a mechanical rule.>
