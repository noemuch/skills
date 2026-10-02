#!/bin/sh
# Template from grounded-design-system: a Claude Code PreToolUse hook that refuses
# actions that are expensive to get wrong, each with a message containing the fix.
# Save as .claude/hooks/pre-tool-use.sh (chmod +x) and register it with
# settings.example.json. Exit 2 blocks the call and sends stderr to the agent.
# Edit GENERATED and the branch names to match the repository.

set -eu

GENERATED="registry.json src/tokens.generated.ts" # REPLACE: space-separated paths, relative to the project root
PROTECTED_BRANCHES="main master"

input=$(cat)

# Read a string field from the hook's JSON input. Uses jq when present, node otherwise.
field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1 // empty"
  else
    printf '%s' "$input" | node -e '
      let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
        const v = process.argv[1].split(".").filter(Boolean).reduce((o, k) => o == null ? o : o[k], JSON.parse(s));
        process.stdout.write(v == null ? "" : String(v));
      });' "$1"
  fi
}

block() {
  printf 'Blocked: %s\n' "$1" >&2
  exit 2
}

tool=$(field .tool_name)
project=${CLAUDE_PROJECT_DIR:-$(field .cwd)}

case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit)
    path=$(field .tool_input.file_path)
    [ -n "$path" ] || exit 0
    case "$path" in
      "$project"/*) rel=${path#"$project"/} ;;
      /*) block "$path is outside the current worktree ($project). Work in the worktree for this branch." ;;
      *) rel=$path ;;
    esac
    for g in $GENERATED; do
      [ "$rel" = "$g" ] && block "$rel is generated. Edit its source (the .meta.ts files or token JSON), then run the generator."
    done
    case "$rel" in
      .claude/skills/*)
        top=$(printf '%s' "$rel" | cut -d/ -f1-3)
        [ -L "$project/$top" ] || block "skills live in .agents/skills/ and are symlinked into .claude/skills/. Other agents never see $top. Create it under .agents/skills/, then: ln -s ../../.agents/skills/<name> .claude/skills/<name>"
        ;;
    esac
    ;;
  Bash)
    cmd=$(field .tool_input.command)
    # Match flags on git commands only, so `git log --grep=--no-verify` passes.
    if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+(commit|push|merge|rebase)([[:space:]][^;&|]*)?[[:space:]]--no-verify([[:space:]]|$)'; then
      block "--no-verify skips the checks that protect main. Fix the failing validation, then commit again."
    fi
    if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
      branch=$(git -C "$project" branch --show-current 2>/dev/null || true)
      for b in $PROTECTED_BRANCHES; do
        [ "$branch" = "$b" ] && block "commits on $b are refused. Create a branch first: git switch -c <type>/<topic>, then commit."
      done
    fi
    ;;
esac

exit 0
