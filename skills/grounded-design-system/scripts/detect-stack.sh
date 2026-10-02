#!/bin/sh
# detect-stack.sh: deterministic, read-only inventory of a repository for the
# grounded-design-system skill. Prints `key: value` lines: framework, styling,
# primitives library, docs tool, token source, catalog, lint, tests, CI, agent
# files, hooks and the stack references to load. Writes nothing.
#
# Usage: sh detect-stack.sh [repo-root]
# Requires: POSIX sh, grep, sed, awk, sort. Uses git, node and gh when present.

set -u

ROOT=${1:-.}
if [ ! -d "$ROOT" ]; then
  echo "error: $ROOT is not a directory" >&2
  exit 1
fi
ROOT=$(cd "$ROOT" && pwd)
cd "$ROOT" || exit 1

TMP=$(mktemp -d 2>/dev/null || mktemp -d -t detect-stack)
trap 'rm -rf "$TMP"' EXIT INT TERM

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- file list: tracked plus untracked-not-ignored, or a pruned find ----------
if have git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IS_GIT=yes
  git ls-files --cached --others --exclude-standard 2>/dev/null | sort -u > "$TMP/files"
else
  IS_GIT=no
  find . \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .next \
    -o -name .turbo -o -name coverage -o -name vendor -o -name .svelte-kit -o -name .nuxt \) -prune \
    -o -type f -print 2>/dev/null | sed 's#^\./##' | sort > "$TMP/files"
fi
# Exclude vendored and generated trees even when tracked.
grep -Ev '(^|/)(node_modules|dist|build|\.next|\.turbo|coverage|vendor|storybook-static)/' "$TMP/files" > "$TMP/f" 2>/dev/null
mv "$TMP/f" "$TMP/files"

files_matching() { grep -E "$1" "$TMP/files" 2>/dev/null; }
count_matching() { files_matching "$1" | wc -l | tr -d ' '; }
first_matching() { files_matching "$1" | head -n "${2:-5}" | tr '\n' ' ' | sed 's/ $//'; }
exists() { [ -e "$1" ] && echo yes || echo no; }
join_or_none() { v=$(cat); if [ -n "$v" ]; then printf '%s' "$v"; else printf 'none'; fi; }
# grep_l PATTERN FILE_REGEX: files matching FILE_REGEX whose content matches PATTERN.
grep_l() { files_matching "$2" | tr '\n' '\0' | xargs -0 grep -lE "$1" /dev/null 2>/dev/null; }

# ---------- dependencies from every package.json ----------
files_matching '(^|/)package\.json$' > "$TMP/pkgs"
: > "$TMP/deps"
if [ -s "$TMP/pkgs" ]; then
  if have node; then
    node -e '
      const fs = require("fs");
      const out = new Map();
      for (const p of fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean)) {
        let j; try { j = JSON.parse(fs.readFileSync(p, "utf8")); } catch { continue; }
        for (const k of ["dependencies", "devDependencies", "peerDependencies"]) {
          for (const [n, v] of Object.entries(j[k] || {})) if (!out.has(n)) out.set(n, String(v));
        }
      }
      for (const [n, v] of [...out].sort()) console.log(n + " " + v);
    ' "$TMP/pkgs" > "$TMP/deps" 2>/dev/null
  else
    # Fallback: every "key": "value" pair. Over-matches scripts, never misses a dependency.
    while IFS= read -r p; do
      grep -oE '"[@a-zA-Z0-9/._-]+"[[:space:]]*:[[:space:]]*"[^"]*"' "$p" 2>/dev/null
    done < "$TMP/pkgs" | sed -E 's/^"([^"]+)"[[:space:]]*:[[:space:]]*"([^"]*)"$/\1 \2/' | sort -u -k1,1 > "$TMP/deps"
  fi
fi

dep() { awk -v n="$1" '$1 == n { print $2; exit }' "$TMP/deps"; }
deps_like() { grep -E "^$1 " "$TMP/deps" 2>/dev/null | awk '{ print $1 }' | tr '\n' ' ' | sed 's/ $//'; }
dep_line() { v=$(dep "$1"); [ -n "$v" ] && printf '%s %s' "$1" "$v"; }

# ---------- header ----------
echo "root: $ROOT"
if [ "$IS_GIT" = yes ]; then
  branch=$(git branch --show-current 2>/dev/null)
  remote=$(git remote get-url origin 2>/dev/null | sed -E 's#^(https://|git@)##; s#\.git$##; s#:#/#')
  echo "git: yes (branch ${branch:-detached}, origin ${remote:-none})"
else
  echo "git: no"
fi

# ---------- package manager and workspace ----------
pm=none
[ -f package-lock.json ] && pm=npm
[ -f yarn.lock ] && pm=yarn
[ -f pnpm-lock.yaml ] && pm=pnpm
{ [ -f bun.lockb ] || [ -f bun.lock ]; } && pm=bun
echo "package-manager: $pm"

mono=""
[ -f pnpm-workspace.yaml ] && mono="$mono pnpm-workspace.yaml"
[ -f turbo.json ] && mono="$mono turbo.json"
[ -f nx.json ] && mono="$mono nx.json"
[ -f lerna.json ] && mono="$mono lerna.json"
grep -q '"workspaces"' package.json 2>/dev/null && mono="$mono package.json#workspaces"
echo "monorepo: $(printf '%s' "$mono" | sed 's/^ //' | join_or_none)"
echo "package-files: $(wc -l < "$TMP/pkgs" | tr -d ' ') ($(head -n 8 "$TMP/pkgs" | tr '\n' ' ' | sed 's/ $//'))"

# ---------- framework ----------
fw=""
for d in next @remix-run/react react-router nuxt vue @sveltejs/kit svelte astro solid-js @angular/core react; do
  l=$(dep_line "$d") && fw="$fw, $l"
done
echo "framework: $(printf '%s' "$fw" | sed 's/^, //' | join_or_none)"

# ---------- styling ----------
tw=$(dep tailwindcss)
twcss=$(grep_l '@import[[:space:]]+["'"'"']tailwindcss' '\.(css|scss|pcss)$' | head -n 3 | tr '\n' ' ' | sed 's/ $//')
twcfg=$(first_matching '(^|/)tailwind\.config\.(js|cjs|mjs|ts)$' 3)
styling=""
[ -n "$tw" ] && styling="tailwindcss $tw (entry: ${twcss:-none}; config: ${twcfg:-none})"
cssmod=$(count_matching '\.module\.(css|scss|sass|less)$')
scss=$(count_matching '\.(scss|sass)$')
css=$(count_matching '\.css$')
cij=$(deps_like '(styled-components|@emotion/react|@emotion/styled|@vanilla-extract/css|@stitches/react|@pandacss/dev|styled-jsx)')
styling="${styling:+$styling; }css files $css, css-modules $cssmod, sass files $scss, css-in-js ${cij:-none}"
echo "styling: $styling"

# ---------- primitives ----------
prims=$(deps_like '(@radix-ui/[a-z-]+|radix-ui|@base-ui/react|@base-ui-components/react|@headlessui/react|@headlessui/vue|@ark-ui/react|react-aria-components|react-aria|@react-aria/[a-z-]+|@mui/base|reka-ui|bits-ui|@kobalte/core|@chakra-ui/react|@mantine/core|@mui/material)' | tr ' ' '\n' | sed -E 's#^(@radix-ui)/react-.*#\1/react-*#; s#^(@react-aria)/.*#\1/*#' | sort -u | tr '\n' ' ' | sed 's/ $//')
echo "primitives: ${prims:-none}"

if [ -f components.json ]; then
  style=$(grep -oE '"style"[[:space:]]*:[[:space:]]*"[^"]*"' components.json | sed -E 's/.*"([^"]*)"$/\1/')
  ui=$(grep -oE '"ui"[[:space:]]*:[[:space:]]*"[^"]*"' components.json | sed -E 's/.*"([^"]*)"$/\1/')
  twfile=$(grep -oE '"css"[[:space:]]*:[[:space:]]*"[^"]*"' components.json | sed -E 's/.*"([^"]*)"$/\1/')
  echo "shadcn: components.json (style ${style:-unset}, aliases.ui ${ui:-unset}, css ${twfile:-unset})"
else
  echo "shadcn: no"
fi

# ---------- docs tool ----------
sb=no
{ [ -d .storybook ] || [ -n "$(dep storybook)" ] || [ -n "$(deps_like '@storybook/[a-z-]+')" ]; } && sb="yes ($(dep storybook | join_or_none))"
stories=$(count_matching '\.stories\.(ts|tsx|js|jsx|mdx|svelte|vue)$')
mdx=$(count_matching '\.mdx$')
docs=$(deps_like '(@docusaurus/core|nextra|fumadocs-core|vitepress|@ladle/react|histoire|@astrojs/starlight)')
echo "docs: storybook $sb, stories $stories, mdx files $mdx, docs frameworks ${docs:-none}"

# ---------- token source ----------
theme_files=$(grep_l '^[[:space:]]*@theme' '\.(css|scss|pcss)$' | tr '\n' ' ' | sed 's/ $//')
root_vars=""
while IFS= read -r f; do
  n=$(grep -cE '^[[:space:]]*--[a-zA-Z0-9-]+[[:space:]]*:' "$f" 2>/dev/null)
  [ "${n:-0}" -ge 10 ] && root_vars="$root_vars $f($n)"
done <<EOT
$(files_matching '\.(css|scss|pcss)$')
EOT
# shellcheck disable=SC2016
grep_l '"\$value"' '\.json$' > "$TMP/dtcg"
dtcg=$(head -n 5 "$TMP/dtcg" | tr '\n' ' ' | sed 's/ $//')
sd=$(deps_like '(style-dictionary|@tokens-studio/sd-transforms|@cobalt-ui/cli|@terrazzo/cli)')
sdcfg=$(first_matching '(^|/)(sd\.config\.[a-z]+|style-dictionary\.config\.[a-z]+)$' 3)
# shellcheck disable=SC2016
tstudio=$(first_matching '(^|/)\$themes\.json$' 2)
echo "token-source: @theme in ${theme_files:-none}; custom-property files (10+ vars)$(printf '%s' "$root_vars" | join_or_none | sed 's/^none$/ none/'); dtcg json ${dtcg:-none}; pipeline ${sd:-none}${sdcfg:+ $sdcfg}; tokens-studio ${tstudio:-none}"

# ---------- catalog ----------
meta=$(count_matching '\.meta\.(ts|tsx|js|json)$')
reg=""
[ -f registry.json ] && reg="registry.json"
[ -d public/r ] && reg="$reg public/r/"
echo "catalog: metadata sidecars $meta, registry ${reg:-none}, stories $stories"

# ---------- lint ----------
eslint=$(first_matching '(^|/)(eslint\.config\.(js|mjs|cjs|ts)|\.eslintrc(\.(js|cjs|json|yml|yaml))?)$' 3)
biome=$(first_matching '(^|/)biome\.jsonc?$' 2)
stylelint=$(first_matching '(^|/)(\.stylelintrc(\.(js|cjs|json|yml|yaml))?|stylelint\.config\.(js|mjs|cjs))$' 2)
restricted=0
for f in $eslint $biome; do
  n=$(grep -cE 'no-restricted-(imports|syntax)|noRestrictedImports' "$f" 2>/dev/null)
  restricted=$((restricted + ${n:-0}))
done
echo "lint: eslint ${eslint:-none}; biome ${biome:-none}; stylelint ${stylelint:-none}; restricted-import/syntax rules $restricted"

# ---------- tests ----------
tests=$(deps_like '(vitest|jest|@playwright/test|cypress|@testing-library/react|chromatic|@chromatic-com/storybook|@storybook/test-runner|backstopjs|loki)')
shots=$(grep_l 'toHaveScreenshot|toMatchSnapshot|matchImageSnapshot' '\.(ts|tsx|js|jsx|mjs)$' | wc -l | tr -d ' ')
echo "tests: ${tests:-none}; files with screenshot or snapshot assertions $shots"

# ---------- CI ----------
ci=$(first_matching '^(\.github/workflows/[^/]+\.ya?ml|\.gitlab-ci\.yml|\.circleci/config\.yml|azure-pipelines\.yml|bitbucket-pipelines\.yml|\.buildkite/[^/]+\.ya?ml)$' 12)
echo "ci: ${ci:-none}"
if [ -n "$ci" ]; then
  # shellcheck disable=SC2086
  gate=$(grep -lE 'git diff --exit-code|max-warnings[= ]0|playwright|chromatic|biome ci' $ci 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
  echo "ci-design-gates: ${gate:-none}"
fi

# ---------- agent files ----------
agent=""
add() { agent="$agent; $1"; }
if [ -f AGENTS.md ]; then add "AGENTS.md ($(wc -l < AGENTS.md | tr -d ' ') lines)"; fi
nested=$(files_matching '/AGENTS\.md$' | head -n 5 | tr '\n' ' ' | sed 's/ $//')
[ -n "$nested" ] && add "nested AGENTS.md: $nested"
if [ -f CLAUDE.md ]; then
  if grep -q '^@AGENTS\.md' CLAUDE.md; then add "CLAUDE.md (imports @AGENTS.md, $(wc -l < CLAUDE.md | tr -d ' ') lines)"
  else add "CLAUDE.md ($(wc -l < CLAUDE.md | tr -d ' ') lines, no @AGENTS.md import)"; fi
fi
for d in .agents/skills .agents/rules .claude/skills .claude/rules .claude/commands .claude/agents .cursor/rules .codex .github/instructions; do
  if [ -d "$d" ]; then
    total=$(find "$d" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
    links=$(find "$d" -mindepth 1 -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')
    add "$d ($total entries, $links symlinks)"
  fi
done
for f in .cursorrules .windsurfrules .github/copilot-instructions.md GEMINI.md; do
  [ -f "$f" ] && add "$f"
done
echo "agent-files: $(printf '%s' "$agent" | sed 's/^; //' | join_or_none)"
echo "design-files: DESIGN.md $(exists DESIGN.md), GAPS.md $(exists GAPS.md), gap sections $(grep_l '^#+[[:space:]].*[Gg]aps' '(^|/)README\.md$' | tr '\n' ' ' | sed 's/ $//' | join_or_none)"

# ---------- hooks ----------
ch="no"
for s in .claude/settings.json .claude/settings.local.json; do
  [ -f "$s" ] && grep -q '"PreToolUse"' "$s" && ch="yes ($s)"
done
gh_hooks=""
[ -d .husky ] && gh_hooks="$gh_hooks .husky"
[ -f lefthook.yml ] && gh_hooks="$gh_hooks lefthook.yml"
[ -f .pre-commit-config.yaml ] && gh_hooks="$gh_hooks .pre-commit-config.yaml"
[ -n "$(dep simple-git-hooks)" ] && gh_hooks="$gh_hooks simple-git-hooks"
echo "hooks: claude PreToolUse $ch; git hooks $(printf '%s' "$gh_hooks" | sed 's/^ //' | join_or_none)"

# ---------- gh ----------
if have gh; then
  if gh auth status >/dev/null 2>&1; then echo "gh: installed, authenticated"; else echo "gh: installed, not authenticated"; fi
else
  echo "gh: not installed"
fi

# ---------- UI code ----------
ui=$(count_matching '\.(tsx|jsx|vue|svelte|astro)$')
html=$(count_matching '\.html$')
if [ "$ui" -eq 0 ] && [ "$html" -eq 0 ] && [ "$css" -eq 0 ]; then
  echo "ui-code: none"
else
  echo "ui-code: $ui component files, $html html files, $css css files"
fi
echo "ui-dirs: $(files_matching '\.(tsx|jsx|vue|svelte|astro)$' | awk -F/ 'NF > 1 { d = $1; if (NF > 2) d = d "/" $2; c[d]++ } END { for (k in c) print c[k] " " k }' | sort -rn | head -n 8 | awk '{ printf "%s%s(%s)", (NR > 1 ? ", " : ""), $2, $1 }' | join_or_none)"

# ---------- stack references ----------
refs=""
{ [ -n "$tw" ] || [ -f components.json ]; } && refs="$refs tailwind-shadcn"
printf '%s' "$prims" | grep -q '@radix-ui\|radix-ui' && refs="$refs radix"
printf '%s' "$prims" | grep -q '@base-ui' && refs="$refs base-ui"
[ "$sb" != no ] && refs="$refs storybook"
{ [ -n "$tstudio" ] || tr '\n' '\0' < "$TMP/dtcg" | xargs -0 grep -lE '"(Light|Dark)"[[:space:]]*:' /dev/null 2>/dev/null | grep -q .; } && refs="$refs figma-variables"
{ [ -n "$sd" ] || [ -n "$sdcfg" ] || [ -n "$dtcg" ]; } && refs="$refs style-dictionary"
[ -z "$tw" ] && refs="$refs css-only"
echo "stack-refs: $(printf '%s' "$refs" | sed 's/^ //' | join_or_none)"

exit 0
