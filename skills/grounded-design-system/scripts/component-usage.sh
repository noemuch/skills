#!/bin/sh
# component-usage.sh: read-only usage probe for the audit's consistency area.
# Prints importers per component of the UI directory, raw HTML elements written
# outside it, class strings repeated across files, and, with Tailwind, files that
# mix semantic color utilities with raw palette steps. Same file universe as
# detect-stack.sh: build output and generated files are excluded. Writes nothing.
#
# Usage: sh component-usage.sh [repo-root] [ui-dir]
# ui-dir defaults to components.json aliases.ui, then the first of components/ui,
# src/components/ui, packages/ui/src/components, packages/ui/src, src/components,
# components that holds 3 or more component files.
# Requires: POSIX sh, grep, sed, awk, sort, comm. Exit 0 on any directory; exit 2
# when the path is not a directory. Environment: see lib.sh.

# shellcheck disable=SC2016 # awk programs in single quotes
set -u
LIB=$(dirname "$0")/lib.sh
# shellcheck source=lib.sh
. "$LIB"
UIDIR=${2:-}
TOP=15
ds_init "${1:-.}" component-usage
ds_tailwind
ds_tokens

COMP='\.(tsx|jsx|vue|svelte|astro)$'
files_matching "$COMP" | grep -Ev '\.(stories|test|spec)\.' > "$TMP/comp-all"

how="argument"
if [ -z "$UIDIR" ] && [ -f components.json ]; then
  a=$(grep -oE '"ui"[[:space:]]*:[[:space:]]*"[^"]*"' components.json | sed -E 's/.*"([^"]*)"$/\1/; s#^[@~]/##')
  for c in "$a" "src/$a"; do [ -n "$a" ] && [ -d "$c" ] && { UIDIR=$c; how="components.json aliases.ui"; break; }; done
fi
if [ -z "$UIDIR" ]; then
  for c in components/ui src/components/ui app/components/ui packages/ui/src/components packages/ui/src src/components components; do
    n=$(grep -c "^$(ds_ere_escape "$c")/" "$TMP/comp-all")
    [ "$n" -ge 3 ] && { UIDIR=$c; how="first conventional directory with 3 or more component files"; break; }
  done
fi
UIDIR=${UIDIR%/}

echo "# component-usage: counts, not verdicts"
echo "root: $ROOT"
if [ -z "$UIDIR" ] || ! [ -d "$UIDIR" ]; then
  echo "ui-dir: none found (pass it as the second argument)"
  [ -s "$TMP/comp-all" ] || echo "note: no JSX, Vue, Svelte or Astro component files; import counts do not apply. For a Sass or CSS library, list modules from its entry file (@use, @forward, @import) instead."
  exit 0
fi
echo "ui-dir: $UIDIR ($how)"
U=$(ds_ere_escape "$UIDIR")
grep "^$U/" "$TMP/comp-all" | grep -Ev '(^|/)index\.[a-z]+$|\.meta\.' > "$TMP/comps"

# ---------- importers per component ----------
files_matching '\.(ts|tsx|js|jsx|mjs|cjs|mts|cts|vue|svelte|astro|mdx)$' | tr '\n' '\0' \
  | xargs -0 grep -oHE "(from|import)[[:space:]]*['\"][^'\"]+['\"]|(require|import)\(['\"][^'\"]+['\"]\)" /dev/null 2>/dev/null \
  | awk '{ i = index($0, ":"); f = substr($0, 1, i - 1); s = substr($0, i + 1)
      sub(/^[^'"'"'"]*['"'"'"]/, "", s); sub(/['"'"'"].*$/, "", s)
      n = split(s, p, "/"); b = p[n]; if (b == "index" && n > 1) b = p[n - 1]
      sub(/\.(tsx|jsx|ts|js|vue|svelte|astro)$/, "", b)
      if (f !~ /\.(stories|test|spec)\./) print tolower(b) "\t" f "\t" s }' | sort -u > "$TMP/imports"
uib=$(basename "$UIDIR" | tr '[:upper:]' '[:lower:]')
barrel=$(awk -F '\t' -v b="$uib" '$1 == b' "$TMP/imports" | cut -f2 | sort -u | wc -l | tr -d ' ')

echo
echo "## importers per component (distinct files, stories and tests excluded; inside = from $UIDIR itself)"
printf '%8s %8s  %s\n' outside inside component
while IFS= read -r c; do
  name=$(basename "$c" | sed -E 's/\.[a-z]+$//' | tr '[:upper:]' '[:lower:]')
  awk -F '\t' -v n="$name" -v self="$c" -v u="$UIDIR/" '
    $1 == n && $2 != self { if (index($2, u) == 1) i++; else o++ }
    END { printf "%8d %8d  %s\n", o, i, self }' "$TMP/imports"
done < "$TMP/comps" | sort -k1,1nr -k2,2nr -k3,3 > "$TMP/usage"
cat "$TMP/usage"
total=$(wc -l < "$TMP/usage" | tr -d ' ')
zero=$(awk '$1 == 0 && $2 == 0' "$TMP/usage" | wc -l | tr -d ' ')
echo "components: $total; imported nowhere: $zero; files importing $UIDIR as a barrel: $barrel (named imports through a barrel are not attributed to a component)"

# ---------- raw elements outside the UI directory ----------
echo
echo "## raw elements outside $UIDIR (component of the same name in $UIDIR: yes or no)"
grep -v "^$U/" "$TMP/comp-all" | grep -Ev '\.(stories|test|spec)\.' > "$TMP/outside"
files_matching '\.html?$' >> "$TMP/outside"
: > "$TMP/elout"
for el in button input select textarea dialog table a img; do
  tr '\n' '\0' < "$TMP/outside" | xargs -0 grep -nHE "<$el([[:space:]>/]|$)" /dev/null 2>/dev/null > "$TMP/el"
  n=$(wc -l < "$TMP/el" | tr -d ' ')
  [ "$n" -gt 0 ] || continue
  has=no
  grep -qiE "(^|/)$el\.(tsx|jsx|vue|svelte|astro)$" "$TMP/comps" && has=yes
  [ "$el" = a ] && grep -qiE '(^|/)link\.(tsx|jsx|vue|svelte|astro)$' "$TMP/comps" && has="yes (link)"
  [ "$el" = img ] && grep -qiE '(^|/)(image|img)\.(tsx|jsx|vue|svelte|astro)$' "$TMP/comps" && has="yes (image)"
  loc=$(cut -d: -f1,2 "$TMP/el" | head -n 3 | tr '\n' ' ' | sed 's/ $//')
  printf '<%s> %d in %d files; component: %s; first: %s\n' "$el" "$n" "$(cut -d: -f1 "$TMP/el" | sort -u | wc -l | tr -d ' ')" "$has" "$loc" >> "$TMP/elout"
done
if [ -s "$TMP/elout" ]; then cat "$TMP/elout"; else echo "none"; fi

# ---------- repeated class strings ----------
echo
echo "## class strings with 4 or more classes repeated in 2 or more places (top $TOP): a repeated string is a candidate component"
files_matching "$COMP" | tr '\n' '\0' \
  | xargs -0 grep -oHE "class(Name)?=[\"'][^\"'{}]+[\"']|(cn|clsx|cx|classNames|twMerge)\([[:space:]]*[\"'][^\"']+[\"']" /dev/null 2>/dev/null \
  | awk '{ i = index($0, ":"); f = substr($0, 1, i - 1); s = substr($0, i + 1)
      sub(/^[^"'"'"']*["'"'"']/, "", s); sub(/["'"'"']$/, "", s); gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s)
      if (split(s, w, " ") >= 4) print s "\t" f }' \
  | awk -F '\t' '{ n[$1]++; if (!(($1, $2) in seen)) { seen[$1, $2] = 1; nf[$1]++; if (nf[$1] <= 2) f[$1] = f[$1] (nf[$1] > 1 ? ", " : "") $2 } }
      END { for (k in n) if (n[k] >= 2) printf "%d\t%4d  \"%s\"  in %d file%s: %s%s\n", n[k], n[k], k, nf[k], (nf[k] > 1 ? "s" : ""), f[k], (nf[k] > 2 ? ", ..." : "") }' \
  | sort -t "$(printf '\t')" -k1,1nr | cut -f2- | head -n "$TOP" > "$TMP/rep"
if [ -s "$TMP/rep" ]; then cat "$TMP/rep"; else echo "none"; fi

# ---------- semantic utilities beside palette steps ----------
if [ -n "$TW" ]; then
  echo
  echo "## files mixing semantic color utilities with raw palette steps (top $TOP)"
  awk -F '\t' '$2 == "css" { print $1 }' "$TMP/tokens" | tr '\n' '\0' \
    | xargs -0 grep -ohE '^[[:space:]]*--[A-Za-z0-9-]+[[:space:]]*:' /dev/null 2>/dev/null \
    | sed -E 's/^[[:space:]]*--//; s/[[:space:]]*:$//; s/^color-//' | grep -vE '^(radius|font|spacing|text|shadow|breakpoint|container|ease|animate)' | sort -u > "$TMP/sem"
  if [ -s "$TMP/sem" ]; then
    sem=$(tr '\n' '|' < "$TMP/sem" | sed 's/|$//')
    PAL='slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose'
    tr '\n' '\0' < "$TMP/comp-all" | xargs -0 awk -v S="$sem" -v P="$PAL" '
      FNR == 1 { if (f != "" && s > 0 && p > 0) printf "%4d semantic, %3d palette  %s\n", s, p, f; f = FILENAME; s = p = 0 }
      { l = $0
        while (match(l, "(bg|text|border|ring|fill|stroke)-(" S ")([^A-Za-z0-9_-]|$)")) { s++; l = substr(l, RSTART + RLENGTH) }
        l = $0
        while (match(l, "(bg|text|border|ring|fill|stroke)-((" P ")-[0-9][0-9][0-9]?|white|black)([^A-Za-z0-9_-]|$)")) { p++; l = substr(l, RSTART + RLENGTH) } }
      END { if (f != "" && s > 0 && p > 0) printf "%4d semantic, %3d palette  %s\n", s, p, f }' 2>/dev/null \
      | sort -k3,3nr | head -n "$TOP" > "$TMP/mix"
    if [ -s "$TMP/mix" ]; then cat "$TMP/mix"; else echo "none"; fi
    echo "semantic names read from: $(awk -F '\t' '$2 == "css" { print $1 }' "$TMP/tokens" | list_or_none 3)"
  else
    echo "not determined: no CSS custom-property token source to read semantic names from"
  fi
fi

exit 0
