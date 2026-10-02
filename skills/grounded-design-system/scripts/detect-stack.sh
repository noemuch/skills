#!/bin/sh
# detect-stack.sh: deterministic, read-only inventory of a repository for the
# grounded-design-system skill. Prints `key: value` lines: what kind of repository
# this is, framework, styling, CSS-in-JS, primitives, docs tool, generated output,
# token sources and themes, catalog, lint, tests, CI, agent files, hooks and the
# stack references to load. Writes nothing.
#
# Usage: sh detect-stack.sh [repo-root]
# Requires: POSIX sh, grep, sed, awk, sort, comm. Uses git, node and gh when present.
# Exit 0 on any directory; exit 2 when the path is not a directory.
# Environment: see lib.sh (DS_EXCLUDE, DS_GENERATED, DS_TOKEN_SOURCES, DS_OFFLINE).

set -u
LIB=$(dirname "$0")/lib.sh
# shellcheck source=lib.sh
. "$LIB"
ds_init "${1:-.}" detect-stack
ds_tailwind
ds_tokens

dep_line() { v=$(dep "$1"); [ -n "$v" ] && printf '%s %s' "$1" "$v"; }
exists() { [ -e "$1" ] && echo yes || echo no; }
token_kind() { awk -F '\t' -v k="$1" '$2 ~ "^(" k ")$" { f = 1 } END { exit !f }' "$TMP/tokens"; }

# ---------- header ----------
echo "root: $ROOT"
slug=""
if [ "$IS_GIT" = yes ]; then
  branch=$(git branch --show-current 2>/dev/null)
  remote=$(git remote get-url origin 2>/dev/null | sed -E 's#^(https://|git@)##; s#\.git$##; s#:#/#')
  echo "git: yes (branch ${branch:-detached}, origin ${remote:-none})"
  case "$remote" in github.com/*) slug=${remote#github.com/} ;; esac
else
  echo "git: no"
fi

# gh-cli describes the machine; the repo part describes access to this repository.
if have gh; then
  if gh auth status >/dev/null 2>&1; then
    ghl="installed, authenticated"
    if [ -n "$slug" ] && [ "${DS_OFFLINE:-0}" != 1 ]; then
      info=$(gh repo view "$slug" --json isArchived,viewerPermission,defaultBranchRef \
        --jq '[.viewerPermission, (.isArchived | tostring), .defaultBranchRef.name] | join(" ")' 2>/dev/null)
      if [ -n "$info" ]; then
        # shellcheck disable=SC2086
        set -- $info
        prot=$(gh api "repos/$slug/branches/$3" --jq '.protected' 2>/dev/null)
        ghl="$ghl; repo $slug: permission $1, archived $2, default branch $3 protected ${prot:-not determined}"
      else
        ghl="$ghl; repo $slug: not determined (gh repo view failed)"
      fi
    elif [ -z "$slug" ]; then
      ghl="$ghl; repo: no GitHub origin"
    else
      ghl="$ghl; repo: not checked (DS_OFFLINE=1)"
    fi
  else
    ghl="installed, not authenticated"
  fi
else
  ghl="not installed"
fi
echo "gh-cli: $ghl"

notice=$(for r in README.md readme.md README README.rst; do
  [ -f "$r" ] && head -n 15 "$r" | grep -n -i -E 'archived|deprecated|no longer (maintained|supported|receive)|unmaintained|not maintained' \
    | head -n 1 | sed -E "s#^([0-9]+):[[:space:]]*#$r:\1 #" | cut -c1-120
done | head -n 1)
echo "archived-notice: ${notice:-none}"

# ---------- package manager, workspace, repository kind ----------
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
[ "$(pkgmeta workspaces)" = yes ] && mono="$mono package.json#workspaces"
echo "monorepo: $(printf '%s' "$mono" | sed 's/^ //' | list_or_none)"
echo "package-files: $(wc -l < "$TMP/pkgs" | tr -d ' ') ($(list_or_none 8 < "$TMP/pkgs"))"

APP_DEPS='next|nuxt|@remix-run/react|@remix-run/node|@sveltejs/kit|astro|gatsby|react-scripts|@angular/cli|expo|react-native|@redwoodjs/core|@solidjs/start'
# One line per package.json: published or private, app signals, what ships to consumers.
: > "$TMP/kinds"
while IFS= read -r p; do
  d=$(dirname "$p")
  name=$(pkgmeta name "$p")
  priv=$(pkgmeta private "$p")
  entry=""
  for k in main module style sass types exports; do v=$(pkgmeta "$k" "$p"); [ -n "$v" ] && entry="$entry $k=$v"; done
  entry=$(printf '%s' "$entry" | sed 's/^ //')
  app=$(grep -oE "\"($APP_DEPS)\"[[:space:]]*:" "$p" 2>/dev/null | tr -d '": ' | sort -u | tr '\n' ' ' | sed 's/ $//')
  [ -n "$app" ] && app="app framework $app"
  if [ "$d" = . ]; then pre=""; else pre="$d/"; fi
  { [ -f "${pre}index.html" ] || [ -f "${pre}public/index.html" ] || [ -f "${pre}src/index.html" ]; } && app="${app:+$app, }index.html"
  ships=""
  if [ "$priv" != yes ] && [ -n "$name" ] && [ -n "$entry" ]; then
    pub="published as $name ($entry)"
    files=$(pkgmeta files "$p")
    if [ -n "$files" ]; then ships="ships files [$files] plus README, LICENSE, package.json"
    else ships="ships everything not ignored by .npmignore or .gitignore (no files field)"; fi
  else
    pub="not published"
  fi
  printf '%s: %s%s%s\n' "$p" "$pub" "${app:+; $app}" "${ships:+; $ships}" >> "$TMP/kinds"
done < "$TMP/pkgs"
pubs=$(grep -c 'published as' "$TMP/kinds")
apps=$(grep -cE 'app framework|index\.html' "$TMP/kinds")
if [ "$pubs" -gt 0 ] && [ "$apps" -gt 0 ]; then kind="app and library (ask which agents work here)"
elif [ "$pubs" -gt 0 ]; then kind="library (the repository publishes a package; ask whether it is the design system)"
elif [ "$apps" -gt 0 ]; then kind="app (consumes a design system, in this repository or from a package)"
else kind="undetermined (ask the team)"; fi
echo "repo-kind: $kind"
head -n 8 "$TMP/kinds" | sed 's/^/package: /'

# ---------- framework ----------
fw=""
for d in next @remix-run/react react-router nuxt vue @sveltejs/kit svelte astro solid-js @angular/core react react-native; do
  l=$(dep_line "$d") && fw="$fw, $l"
done
echo "framework: $(printf '%s' "$fw" | sed 's/^, //' | list_or_none 12)"

# ---------- styling ----------
styling=""
[ -n "$TW" ] && styling="tailwind v${TW_MAJOR:-?} (${TW_VER:-no dependency}; entry ${TW_ENTRY:-none}; config ${TW_CFG:-none})"
cssmod=$(count_matching '\.module\.(css|scss|sass|less)$')
scss=$(count_matching '\.(scss|sass)$')
less=$(count_matching '\.less$')
css=$(count_matching '\.(css|pcss)$')
styl=$(count_matching '\.styl$')
styling="${styling:+$styling; }css $css, scss/sass $scss, less $less, stylus $styl, css-modules $cssmod"
sassc=$(deps_like 'sass|sass-embedded|node-sass')
[ -n "$sassc" ] && styling="$styling; compiler $sassc"
echo "styling: $styling"

# CSS-in-JS, by import, so re-exports such as @storybook/theming and @mui/system count.
CIJ='styled-components|@emotion/(react|styled|css)|@storybook/theming|@stitches/react|@vanilla-extract/css|@vanilla-extract/recipes|@pandacss/dev|styled-system/(css|jsx|patterns|recipes)|goober|@linaria/(core|react)|@mui/material/styles|@mui/system|@mui/styled-engine|theme-ui|styled-jsx'
files_matching '\.(ts|tsx|js|jsx|mjs|cjs|mts|cts)$' | tr '\n' '\0' \
  | xargs -0 grep -oHE "from[[:space:]]+['\"]($CIJ)['\"/]|require\(['\"]($CIJ)['\"]" /dev/null 2>/dev/null \
  | sed -E "s#^([^:]+):.*['\"](($CIJ))['\"/]?\$#\1 \2#" | sort -u \
  | awk '{ c[$2]++ } END { for (k in c) print c[k] " " k }' | sort -rn > "$TMP/cij"
cijl=$(awk '{ note = ""; if ($2 == "@storybook/theming") note = " (emotion re-export)"; if ($2 ~ /^@mui\//) note = " (emotion by default)"; printf "%s%s in %s files%s", (NR > 1 ? ", " : ""), $2, $1, note }' "$TMP/cij")
cijd=$(deps_like 'styled-components|@emotion/[a-z-]+|@storybook/theming|@stitches/react|@vanilla-extract/[a-z-]+|@pandacss/dev|goober|@linaria/[a-z-]+|theme-ui|styled-system|polished')
echo "css-in-js: ${cijl:-none by import}; dependencies ${cijd:-none}"

# ---------- primitives ----------
prims=$(deps_like '@radix-ui/[a-z-]+|radix-ui|@base-ui/react|@base-ui-components/react|@headlessui/react|@headlessui/vue|@ark-ui/react|react-aria-components|react-aria|@react-aria/[a-z-]+|@mui/base|reka-ui|bits-ui|@kobalte/core|@chakra-ui/react|@mantine/core|@mui/material' | tr ' ' '\n' | sed -E 's#^(@radix-ui)/react-.*#\1/react-*#; s#^(@react-aria)/.*#\1/*#' | sort -u | list_or_none 10)
echo "primitives: $prims"

# ---------- shadcn: components.json, or installed by hand ----------
uidir=""
if [ -f components.json ]; then
  style=$(grep -oE '"style"[[:space:]]*:[[:space:]]*"[^"]*"' components.json | sed -E 's/.*"([^"]*)"$/\1/')
  ui=$(grep -oE '"ui"[[:space:]]*:[[:space:]]*"[^"]*"' components.json | sed -E 's/.*"([^"]*)"$/\1/')
  twfile=$(grep -oE '"css"[[:space:]]*:[[:space:]]*"[^"]*"' components.json | sed -E 's/.*"([^"]*)"$/\1/')
  echo "shadcn: components.json (style ${style:-unset}, aliases.ui ${ui:-unset}, css ${twfile:-unset})"
else
  # A ui/ directory of components using cva or a primitive library, beside a cn() helper on tailwind-merge.
  uidir=$(files_matching '(^|/)ui/[^/]+\.(tsx|jsx)$' | grep -Ev '\.(stories|test|spec)\.' | sed -E 's#/[^/]+$##' | sort | uniq -c | sort -rn | awk '$1 >= 3 { print $2; exit }')
  if [ -n "$uidir" ] && grep -lE 'class-variance-authority|@radix-ui/|@base-ui' "$uidir"/*.tsx "$uidir"/*.jsx 2>/dev/null | grep -q .; then
    n=$(files_matching "^$(ds_ere_escape "$uidir")/[^/]+\.(tsx|jsx)$" | wc -l | tr -d ' ')
    sig=$(deps_like 'class-variance-authority|tailwind-merge|clsx')
    cnf=$(grep_l 'twMerge\(' '\.(ts|tsx|js)$' | head -n 1)
    echo "shadcn: installed by hand, no components.json: $uidir ($n files); ${sig:-no cva or tailwind-merge dependency}; cn() ${cnf:-not found}"
  else
    uidir=""
    echo "shadcn: no"
  fi
fi

# ---------- docs tool ----------
sb=no
{ [ -d .storybook ] || [ -n "$(dep storybook)" ] || [ -n "$(deps_like '@storybook/[a-z-]+')" ]; } && sb="yes ($(dep storybook | list_or_none))"
stories=$(count_matching '\.stories\.(ts|tsx|js|jsx|mdx|svelte|vue)$')
mdx=$(count_matching '\.mdx$')
docs=$(deps_like '@docusaurus/core|nextra|fumadocs-core|vitepress|@ladle/react|histoire|@astrojs/starlight|contentlayer|contentlayer2')
autodocs=$(grep -l "autodocs" .storybook/main.* 2>/dev/null | head -n 1)
echo "docs: storybook $sb${autodocs:+, autodocs in $autodocs}, stories $stories, mdx files $mdx (read them: docs or app content), docs frameworks ${docs:-none}"

# ---------- generated output ----------
gen=$(awk -F '\t' '{ printf "%s%s (%s)", (NR > 1 ? "; " : ""), $1, $2 }' "$TMP/genwhy" | cut -c1-400)
echo "generated: ${gen:-none detected}; $(wc -l < "$TMP/genmarked" | tr -d ' ') files carry a generated marker; $(wc -l < "$TMP/gen" | tr -d ' ') files excluded from every count"

# ---------- token sources ----------
echo "token-source: $(list_or_none 8 < "$TMP/tokenfiles")"
for k in css sass less js tailwind-config dtcg style-dictionary declared; do
  awk -F '\t' -v k="$k" '$2 == k { print $1 " (" $3 ")" }' "$TMP/tokens" > "$TMP/tk"
  [ -s "$TMP/tk" ] && echo "tokens-$k: $(list_or_none 5 < "$TMP/tk")"
done
sd=$(deps_like 'style-dictionary|@tokens-studio/sd-transforms|@cobalt-ui/cli|@terrazzo/cli')
sdcfg=$(first_matching '(^|/)(sd\.config\.[a-z]+|style-dictionary\.config\.[a-z]+)$' 3)
# shellcheck disable=SC2016
tstudio=$(first_matching '(^|/)\$themes\.json$' 2)
echo "tokens-pipeline: ${sd:-none}${sdcfg:+ $sdcfg}; tokens-studio ${tstudio:-none}"
# Theme selectors in CSS and Sass token sources: the set of themes the system defines.
themes=$(grep -v -E '\.(json|ts|tsx|js|jsx|mjs|cjs|mts|cts)$' "$TMP/tokenfiles" | tr '\n' '\0' \
  | xargs -0 grep -ohE ':root|\.dark([^A-Za-z0-9_-]|$)|\.light([^A-Za-z0-9_-]|$)|\[data-theme[^]]*\]|\[data-mode[^]]*\]|\[data-color-scheme[^]]*\]|prefers-color-scheme:[[:space:]]*(dark|light)|color-scheme:[[:space:]]*(dark|light)' /dev/null 2>/dev/null \
  | sed -E 's/[^A-Za-z0-9_)\]-]$//; s/[[:space:]]+/ /g' | sort | uniq -c | sort -rn \
  | awk '{ c = $1; $1 = ""; sub(/^ /, ""); printf "%s%s (%s)", (NR > 1 ? ", " : ""), $0, c }')
other=""
token_kind 'js|dtcg|style-dictionary' && other="; JS, config or JSON token sources: read them for the theme set"
echo "themes: ${themes:-no theme selector in CSS or Sass token sources}$other"

# ---------- catalog ----------
meta=$(count_matching '\.meta\.(ts|tsx|js|json)$')
reg=""
[ -f registry.json ] && reg="registry.json"
[ -d public/r ] && reg="$reg public/r/"
echo "catalog: metadata sidecars $meta, registry ${reg:-none}, stories $stories"

# ---------- lint and format ----------
eslint=$(first_matching '(^|/)(eslint\.config\.(js|mjs|cjs|ts|mts)|\.eslintrc(\.(js|cjs|json|yml|yaml))?)$' 4)
biome=$(first_matching '(^|/)biome\.jsonc?$' 2)
stylelint=$(first_matching '(^|/)(\.stylelintrc(\.(js|cjs|json|yml|yaml))?|stylelint\.config\.(js|mjs|cjs))$' 2)
restricted=0
for f in $eslint $biome; do
  n=$(grep -cE 'no-restricted-(imports|syntax)|noRestrictedImports' "$f" 2>/dev/null)
  restricted=$((restricted + ${n:-0}))
done
echo "lint: eslint ${eslint:-none}; biome ${biome:-none}; stylelint ${stylelint:-none}; restricted-import/syntax rules $restricted"
# shellcheck disable=SC2086
ext=$(awk '/extends/ { on = 1 } on { s = $0; while (match(s, /"[^"]+"|'"'"'[^'"'"']+'"'"'/)) { v = substr(s, RSTART + 1, RLENGTH - 2); if (v != "extends") print v; s = substr(s, RSTART + RLENGTH) } } on && /\]/ { on = 0 }' $eslint /dev/null 2>/dev/null | sort -u | list_or_none 8)
echo "lint-extends: $ext (a shared config is readable only with node_modules installed)"
echo "lint-plugins: $(grep -oE '^(eslint-plugin-[a-z0-9-]+|@[a-z0-9-]+/eslint-plugin[a-z0-9-]*|eslint-config-[a-z0-9-]+|@[a-z0-9-]+/eslint-config[a-z0-9-]*|@[a-z0-9-]+/linter-config|stylelint-[a-z0-9-]+|@[a-z0-9-]+/stylelint[a-z0-9-]*|prettier-plugin-[a-z0-9-]+|postcss-scss|postcss-styled-syntax|postcss-html|@biomejs/biome) ' "$TMP/deps" | tr -d ' ' | list_or_none 12)"
# shellcheck disable=SC2086
drules=$(grep -ohE '"?(tailwindcss|better-tailwindcss|readable-tailwind|storybook|jsx-a11y)/[a-z-]+"?[[:space:]]*:[[:space:]]*\[?[[:space:]]*"?(error|warn|off|[012])|"(color-no-hex|color-named|function-disallowed-list|declaration-property-value-allowed-list|declaration-property-value-disallowed-list|scale-unlimited/declaration-strict-value|scss/[a-z-]+)"[[:space:]]*:' $eslint $stylelint $biome /dev/null 2>/dev/null \
  | tr -d '"[' | sed -E 's/[[:space:]]*:[[:space:]]*/ /; s/ $//' | sort -u | list_or_none 10)
echo "lint-design-rules: $drules"
fmt=""
pr=$(first_matching '(^|/)(\.prettierrc(\.(js|cjs|mjs|json|yml|yaml|toml))?|prettier\.config\.(js|cjs|mjs|ts))$' 2)
[ -n "$pr" ] && fmt="prettier $pr"
pc=$(first_matching '(^|/)(postcss\.config\.(js|cjs|mjs|ts)|\.postcssrc(\.(js|json|yml))?)$' 3)
[ -n "$pc" ] && fmt="${fmt:+$fmt; }postcss $pc"
echo "format: ${fmt:-none}"

# ---------- tests ----------
tests=$(deps_like 'vitest|jest|@playwright/test|cypress|@testing-library/react|chromatic|@chromatic-com/storybook|@storybook/test-runner|@storybook/addon-a11y|backstopjs|loki|@percy/cli|@argos-ci/cli|lost-pixel')
shots=$(grep_l 'toHaveScreenshot|toMatchSnapshot|matchImageSnapshot|toMatchImageSnapshot' '\.(ts|tsx|js|jsx|mjs)$' | wc -l | tr -d ' ')
typecheck=$(awk -F '\t' '$2 ~ /^(typecheck|type-check|typescript:check|tsc|check-types|types|lint:types)$/ || $3 ~ /(^| )tsc( |$).*--noEmit/ { print $2 }' "$TMP/scripts" | sort -u | list_or_none 3)
echo "tests: ${tests:-none}; files with screenshot or snapshot assertions $shots; typecheck scripts $typecheck"

# ---------- CI ----------
grep -iE '^(\.github/workflows/[^/]+\.ya?ml|\.gitlab-ci\.ya?ml|\.circleci/config\.ya?ml|azure-pipelines\.ya?ml|bitbucket-pipelines\.ya?ml|\.buildkite/[^/]+\.ya?ml|\.travis\.ya?ml|jenkinsfile|\.drone\.ya?ml|\.woodpecker(\.ya?ml|/[^/]+\.ya?ml))$' "$TMP/all" > "$TMP/ci"
echo "ci: $(list_or_none 12 < "$TMP/ci")"
if [ -s "$TMP/ci" ]; then
  gates=$(while IFS= read -r f; do
    k=$(grep -oiE 'chromatic|chromaui|percy|argos|lost-pixel|backstop|loki|playwright|tohavescreenshot|max-warnings[= ]?0|biome ci|git diff --exit-code|stylelint|changeset status|auto pr-check|danger|test-storybook' "$f" 2>/dev/null \
      | tr '[:upper:]' '[:lower:]' | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g')
    [ -n "$k" ] && printf '%s (%s)\n' "$f" "$k"
  done < "$TMP/ci" | list_or_none 8)
  echo "ci-design-gates: $gates; a gate blocks merge only under branch protection (see gh-cli)"
fi

# ---------- agent files ----------
agent=""
add() { agent="$agent; $1"; }
if [ -f AGENTS.md ]; then add "AGENTS.md ($(wc -l < AGENTS.md | tr -d ' ') lines)"; fi
nested=$(grep -E '/AGENTS\.md$' "$TMP/all" | head -n 5 | tr '\n' ' ' | sed 's/ $//')
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
for f in .cursorrules .windsurfrules .github/copilot-instructions.md GEMINI.md llms.txt; do
  [ -f "$f" ] && add "$f"
done
echo "agent-files: $(printf '%s' "$agent" | sed 's/^; //' | list_or_none)"
echo "design-files: DESIGN.md $(exists DESIGN.md), GAPS.md $(exists GAPS.md), gap sections $(grep_l '^#+[[:space:]].*[Gg]aps' '(^|/)README\.md$' | list_or_none)"

# ---------- hooks ----------
ch="no"
for s in .claude/settings.json .claude/settings.local.json; do
  [ -f "$s" ] && grep -q '"PreToolUse"' "$s" && ch="yes ($s)"
done
gh_hooks=""
if [ -d .husky ]; then
  hk=$(for h in .husky/*; do
    [ -f "$h" ] || continue
    c=$(grep -vE '^[[:space:]]*(#|$)|husky\.sh' "$h" | head -n 1 | cut -c1-50)
    printf '%s: %s\n' "${h#.husky/}" "$c"
  done | awk '{ printf "%s%s", (NR > 1 ? "; " : ""), $0 }')
  gh_hooks="$gh_hooks husky .husky (${hk:-no hook files})"
fi
hv4=$(pkgmeta husky-hooks)
[ -n "$hv4" ] && gh_hooks="$gh_hooks husky (package.json: $hv4)"
{ [ -n "$(pkgmeta lint-staged)" ] || [ -n "$(dep lint-staged)" ] || ls .lintstagedrc* lint-staged.config.* >/dev/null 2>&1; } && gh_hooks="$gh_hooks lint-staged"
for f in lefthook.yml lefthook.yaml .lefthook.yml .lefthook.yaml; do [ -f "$f" ] && gh_hooks="$gh_hooks lefthook ($f)"; done
[ -f .pre-commit-config.yaml ] && gh_hooks="$gh_hooks pre-commit (.pre-commit-config.yaml)"
{ [ -n "$(dep simple-git-hooks)" ] || [ -n "$(pkgmeta simple-git-hooks)" ]; } && gh_hooks="$gh_hooks simple-git-hooks"
hp=$(git config core.hooksPath 2>/dev/null)
[ -n "$hp" ] && gh_hooks="$gh_hooks core.hooksPath=$hp"
echo "hooks: claude PreToolUse $ch; git hooks $(printf '%s' "$gh_hooks" | sed 's/^ //;' | awk '{ print } END { if (NR == 0) print "none" }')"

# ---------- UI code ----------
ROUTES='(^|/)(page|layout|loading|error|global-error|not-found|template|default|route|head|opengraph-image|twitter-image|icon|apple-icon|_app|_document|\+page|\+layout|\+server)\.(tsx|jsx|ts|js|svelte)$'
files_matching '\.(tsx|jsx|vue|svelte|astro)$' > "$TMP/ui"
comp=$(grep -Ev '\.(stories|test|spec)\.' "$TMP/ui" | grep -Evc "$ROUTES")
routes=$(grep -Ec "$ROUTES" "$TMP/ui")
html=$(count_matching '\.html?$')
if [ "$comp" -eq 0 ] && [ "$routes" -eq 0 ] && [ "$html" -eq 0 ] && [ "$css" -eq 0 ] && [ "$scss" -eq 0 ] && [ "$less" -eq 0 ] && [ "$styl" -eq 0 ]; then
  echo "ui-code: none"
else
  echo "ui-code: components $comp (stories, tests and route files excluded), route files $routes, stories $stories, html $html, css $css, scss/sass $scss, less $less"
fi
echo "ui-dirs: $(files_matching '\.(tsx|jsx|vue|svelte|astro|scss|sass|less|css)$' | grep -Ev '\.(stories|test|spec)\.' | awk -F/ 'NF > 1 { d = $1; if (NF > 2) d = d "/" $2; c[d]++ } END { for (k in c) print c[k] " " k }' | sort -rn | head -n 8 | awk '{ printf "%s%s(%s)", (NR > 1 ? ", " : ""), $2, $1 } END { if (NR == 0) printf "none"; printf "\n" }')"

# ---------- stack references ----------
refs=""
{ [ -n "$TW" ] || [ -f components.json ] || [ -n "$uidir" ]; } && refs="$refs tailwind-shadcn"
printf '%s' "$prims" | grep -q '@radix-ui\|radix-ui' && refs="$refs radix"
printf '%s' "$prims" | grep -q '@base-ui' && refs="$refs base-ui"
[ "$sb" != no ] && refs="$refs storybook"
{ [ -s "$TMP/cij" ] || token_kind js; } && refs="$refs css-in-js"
{ [ "$scss" -gt 0 ] || [ "$less" -gt 0 ]; } && refs="$refs sass"
{ [ -n "$tstudio" ] || awk -F '\t' '$2 == "dtcg" { print $1 }' "$TMP/tokens" | tr '\n' '\0' | xargs -0 grep -lE '"(Light|Dark)"[[:space:]]*:' /dev/null 2>/dev/null | grep -q .; } && refs="$refs figma-variables"
{ [ -n "$sd" ] || [ -n "$sdcfg" ] || token_kind 'dtcg|style-dictionary'; } && refs="$refs style-dictionary"
printf '%s' "$refs" | grep -qE 'tailwind-shadcn|css-in-js|sass' || refs="$refs css-only"
echo "stack-refs: $(printf '%s' "$refs" | sed 's/^ //' | list_or_none 10)"

exit 0
