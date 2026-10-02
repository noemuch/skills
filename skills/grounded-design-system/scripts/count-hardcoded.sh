#!/bin/sh
# count-hardcoded.sh: read-only count of hardcoded design values in a repository,
# per directory, for the grounded-design-system audit. Counts pattern matches:
# hex colors, color functions, Tailwind arbitrary values, px literals and raw
# palette steps. A match is not a violation: token definition files are listed
# separately, and comments and code samples are counted like any other line.
# Writes nothing.
#
# Usage: sh count-hardcoded.sh [repo-root] [top-n]
# Requires: POSIX sh, awk, sort, xargs -0. Uses rg when present, grep -E otherwise.

set -u

ROOT=${1:-.}
TOP=${2:-15}
if [ ! -d "$ROOT" ]; then
  echo "error: $ROOT is not a directory" >&2
  exit 1
fi
ROOT=$(cd "$ROOT" && pwd)
cd "$ROOT" || exit 1

TMP=$(mktemp -d 2>/dev/null || mktemp -d -t count-hardcoded)
trap 'rm -rf "$TMP"' EXIT INT TERM

have() { command -v "$1" >/dev/null 2>&1; }

EXT='\.(css|scss|sass|less|pcss|ts|tsx|js|jsx|mjs|cjs|vue|svelte|astro|html|mdx)$'

if have git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git ls-files --cached --others --exclude-standard 2>/dev/null
else
  find . \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .next \) -prune \
    -o -type f -print 2>/dev/null | sed 's#^\./##'
fi | grep -E "$EXT" \
  | grep -Ev '(^|/)(node_modules|dist|build|\.next|\.turbo|coverage|vendor|storybook-static|__snapshots__)/' \
  | grep -Ev '\.(min\.(js|css)|d\.ts)$' \
  | sort -u > "$TMP/files"

# Keep only files that still exist (git ls-files lists deleted-but-unstaged files).
while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done < "$TMP/files" > "$TMP/f"
mv "$TMP/f" "$TMP/files"

ENGINE=${COUNT_ENGINE:-}
if [ -z "$ENGINE" ]; then if have rg; then ENGINE="rg"; else ENGINE="grep"; fi; fi

# scan NAME PATTERN: writes "file<TAB>match" lines to $TMP/m.NAME
scan() {
  if [ "$ENGINE" = rg ]; then
    tr '\n' '\0' < "$TMP/files" | xargs -0 rg -o --no-heading --with-filename --no-line-number \
      --no-config --color never -e "$2" -- 2>/dev/null
  else
    tr '\n' '\0' < "$TMP/files" | xargs -0 grep -oHE "$2" /dev/null 2>/dev/null
  fi | awk '{ i = index($0, ":"); if (i > 0) print substr($0, 1, i - 1) "\t" substr($0, i + 1) }' > "$TMP/m.$1"
}

PALETTES='slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose'

scan hex '(^|[^0-9A-Za-z_&/])#([0-9A-Fa-f]{8}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{3})([^0-9A-Za-z_-]|$)'
scan colorfn '(^|[^0-9A-Za-z_-])(rgba?|hsla?|oklch|oklab|lch|lab|hwb)\('
scan arb '(^|[[:space:]"'"'"'`{:!])-?[a-z][a-z0-9-]*-\[[^]"'"'"'`[:space:]]+\]'
scan px '(^|[^0-9A-Za-z_.-])[0-9]+(\.[0-9]+)?px([^0-9A-Za-z_-]|$)'
scan palette "(^|[^0-9A-Za-z_-])(bg|text|border|border-[trblxyse]|ring|ring-offset|fill|stroke|from|via|to|outline|divide|placeholder|decoration|shadow|accent|caret)-($PALETTES)-[0-9]{2,3}([^0-9A-Za-z_-]|$)"

# Split arbitrary values: variant selectors (data-[...], aria-[...]) are not values.
awk -F '\t' '
  {
    m = $2; sub(/^[^a-z-]*/, "", m)
    if (m ~ /^(data|aria|supports|has|group|peer|not|in|nth|nth-last|min|max)-\[/) next
    v = m; sub(/^[^[]*\[/, "", v)
    if (v ~ /#[0-9A-Fa-f]|rgb|hsl|oklch|oklab/) c = "arbcolor"
    else if (v ~ /^var\(--/) c = "arbvar"
    else if (v ~ /[0-9](px|rem|em|vh|vw|%)/) c = "arblen"
    else c = "arbother"
    print $1 "\t" m > (T "/m." c)
  }' T="$TMP" "$TMP/m.arb"
for c in arbcolor arbvar arblen arbother; do [ -f "$TMP/m.$c" ] || : > "$TMP/m.$c"; done

CATS="hex colorfn arbcolor arbvar arblen arbother px palette"

# Token source files: matches there are definitions, not usage.
: > "$TMP/tokens"
while IFS= read -r f; do
  case "$f" in
    *.css|*.scss|*.sass|*.less|*.pcss)
      if grep -qE '^[[:space:]]*@theme' "$f" 2>/dev/null; then printf '%s\n' "$f" >> "$TMP/tokens"; continue; fi
      n=$(grep -cE '^[[:space:]]*--[a-zA-Z0-9-]+[[:space:]]*:' "$f" 2>/dev/null)
      [ "${n:-0}" -ge 10 ] && printf '%s\n' "$f" >> "$TMP/tokens"
      ;;
  esac
done < "$TMP/files"

count() { wc -l < "$TMP/m.$1" | tr -d ' '; }

echo "# count-hardcoded: pattern matches, not violations"
echo "root: $ROOT"
echo "engine: $ENGINE"
echo "files-scanned: $(wc -l < "$TMP/files" | tr -d ' ') (css, scss, sass, less, pcss, ts, tsx, js, jsx, mjs, cjs, vue, svelte, astro, html, mdx; generated and vendored trees excluded)"
echo "legend: hex = #rgb to #rrggbbaa; colorfn = rgb() hsl() oklch() oklab() lch() lab() hwb(); arbcolor/arbvar/arblen/arbother = Tailwind arbitrary values holding a color, a var(), a length, anything else; px = px literals anywhere, including inside arbitrary values; palette = raw Tailwind palette steps such as text-gray-500"
echo
echo "## totals"
for c in $CATS; do echo "$c: $(count "$c")"; done

echo
echo "## by directory (first two path segments; token source files excluded)"
for c in $CATS; do
  awk -F '\t' -v c="$c" -v tf="$TMP/tokens" '
    BEGIN { while ((getline l < tf) > 0) tok[l] = 1 }
    !($1 in tok) { n = split($1, p, "/"); d = (n > 2 ? p[1] "/" p[2] : (n == 2 ? p[1] : ".")); print d "\t" c }' "$TMP/m.$c"
done | awk -F '\t' -v cats="$CATS" '
  { cnt[$1, $2]++; dirs[$1] = 1; tot[$1]++ }
  END {
    nc = split(cats, C, " ")
    for (d in dirs) {
      line = sprintf("%-32s", d)
      for (i = 1; i <= nc; i++) line = line sprintf(" %8d", cnt[d, C[i]])
      print tot[d] "\t" line
    }
  }' | sort -t "$(printf '\t')" -k1,1nr -k2,2 | cut -f2- | head -n 40 > "$TMP/bydir"
if [ -s "$TMP/bydir" ]; then
  printf '%-32s' "dir"; for c in $CATS; do printf ' %8s' "$c"; done; printf '\n'
  cat "$TMP/bydir"
else
  echo "no matches outside token source files"
fi

echo
echo "## palettes used (palette matches per palette, all files)"
awk -F '\t' -v P="$PALETTES" '
  BEGIN { n = split(P, L, "|") }
  { for (i = 1; i <= n; i++) if (index($2, "-" L[i] "-")) { c[L[i]]++; break } }
  END { for (k in c) print c[k] " " k }' "$TMP/m.palette" | sort -k1,1nr -k2,2 | awk '{ printf "%s%s %s", (NR > 1 ? ", " : ""), $2, $1 } END { if (NR == 0) printf "none"; printf "\n" }'

echo
echo "## top $TOP files (all categories)"
for c in $CATS; do cut -f1 "$TMP/m.$c"; done | sort | uniq -c | sort -k1,1nr -k2,2 | head -n "$TOP" \
  | awk -v tf="$TMP/tokens" 'BEGIN { while ((getline l < tf) > 0) tok[l] = 1 } { f = $2; printf "%6d %s%s\n", $1, f, (f in tok ? "  (token source)" : "") }'

echo
echo "## token source files (matches here are definitions)"
if [ -s "$TMP/tokens" ]; then cat "$TMP/tokens"; else echo "none detected"; fi

exit 0
