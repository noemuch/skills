# Stack: Figma variables

This file maps the token layer onto a team whose design source of truth is Figma variables. Load it when `detect-stack.sh` lists `figma-variables` in `stack-refs`, or when the team says tokens originate in Figma.

## Detect

| Signal | Meaning |
| --- | --- |
| A JSON file with `$value` and `$type` and Figma collection names (`Primitives`, `Semantic`, mode names like `Light`, `Dark`) | DTCG export from Figma variables |
| Tokens Studio files (`$themes.json`, `$metadata.json`) | Tokens Studio plugin sync |
| A script calling `api.figma.com/v1/files/*/variables` | REST export, requires an Enterprise plan for the variables endpoints |
| A Figma MCP server in the agent config | The agent can read selections and variables at design intake |

## Where each mechanism lives

| Mechanism | Location |
| --- | --- |
| Source | Figma collections and modes. One collection per layer (primitives, semantic), one mode per theme |
| Repository copy | DTCG JSON committed to the repository, then built to CSS by Style Dictionary or a script. See [style-dictionary.md](style-dictionary.md) |
| Usage | Figma variable descriptions. Export them into `$description`, then into DESIGN.md's usage column |
| Drift check | CI rebuilds CSS from the committed JSON and diffs. A separate scheduled job compares the JSON against a fresh Figma export and opens an issue on drift |
| Design intake | The agent maps every value from a selection to an existing token, or stops and logs a gap. Never a literal |

## Pitfalls

- A decision recorded only in a Figma comment or a variable description that never reaches the repository is `disconnected`. The agent in the code cannot read it.
- Figma variable names use `/` as the group separator (`color/text/muted`). Decide the CSS name mapping once and record it; ask the team, never invent the mapping.
- Aliases in Figma resolve to the mode of the referenced collection. An export that flattens aliases to raw values destroys the semantic layer. Export with references kept.
- A design value that matches a primitive exactly is not a reason to use that primitive. Match on usage.
