/**
 * Template from grounded-design-system: the metadata sidecar type and its validator.
 * Put this file in the UI package (e.g. packages/ui/src/meta.ts). Each component or
 * pattern gets a sibling `<name>.meta.ts` exporting `defineMeta({...})`.
 * The status list is the article's default; the team may change it, and the
 * generator must validate whatever list it keeps.
 */

export const STATUSES = [
  "missing",
  "experimental",
  "needs-review",
  "needs-rework",
  "stable",
  "deprecated",
] as const

export type Status = (typeof STATUSES)[number]

type Base = {
  /** What do I search for? */
  name: string
  /** Do I import it or compose it? */
  type: "component" | "pattern" | "block"
}

type Missing = Base & {
  status: "missing"
  /** Required: the system acknowledges the gap and tracks it. */
  issue: number | string
}

type Present = Base & {
  status: Exclude<Status, "missing">
  /** When to use it, and what to use instead when not. "Filter a list over a period. One date: DatePicker." */
  usage: string
  /** What it does, in one sentence. */
  description: string
  /** The merge that made this entry current. */
  introduced: { pr: number; date: `${number}-${number}-${number}` }
  /** Required when status is needs-rework or deprecated. */
  issue?: number | string
  /** Required when status is deprecated. */
  replacedBy?: string
}

export type Meta = Missing | Present

export function defineMeta<const M extends Meta>(meta: M): M {
  return meta
}

/** Returns one message per problem. The registry generator fails when any entry returns a message. */
export function validateMeta(file: string, meta: Meta): string[] {
  const problems: string[] = []
  const at = (msg: string) => problems.push(`${file}: ${msg}`)

  if (!STATUSES.includes(meta.status)) at(`status "${meta.status}" is not one of ${STATUSES.join(", ")}`)
  if (meta.status === "missing") {
    if (!meta.issue) at("status missing requires issue")
    return problems
  }
  if (meta.usage.trim().length < 20) at("usage must name the situation and the alternative (20 characters minimum)")
  if (meta.usage.trim().toLowerCase() === `use for ${meta.name.toLowerCase()}`) at("usage restates the name")
  if ((meta.status === "needs-rework" || meta.status === "deprecated") && !meta.issue) at(`status ${meta.status} requires issue`)
  if (meta.status === "deprecated" && !meta.replacedBy) at("status deprecated requires replacedBy")
  return problems
}

/* Example sidecars

// filters/date-range.meta.ts
export default defineMeta({
  name: "Date range filter",
  type: "pattern",
  usage: "Filter a list over a period. One date: DatePicker.",
  description: "Two linked date inputs with presets, emitting an inclusive range.",
  status: "stable",
  introduced: { pr: 1182, date: "2026-03-14" },
})

// filters/saved-views.meta.ts
export default defineMeta({
  name: "Saved views",
  type: "pattern",
  status: "missing",
  issue: 412,
})
*/
