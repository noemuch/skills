#!/bin/sh
# count-hardcoded.sh: read-only count of hardcoded design values in a repository,
# per directory, for the grounded-design-system audit. Counts pattern matches:
# hex colors, color functions with literal arguments, named colors, px and rem
# literals, and, when Tailwind is detected, raw palette steps and arbitrary values.
# Comments and Markdown code fences are stripped before matching. Matches inside
# token sources are definitions and are reported apart from usage. Build output
# and generated files are excluded (same rules as detect-stack.sh). Writes nothing.
#
# Usage: sh count-hardcoded.sh [repo-root] [top-n]
# Requires: POSIX sh, awk, sort, comm, xargs -0. Uses rg when present, grep -E otherwise
# (COUNT_ENGINE=grep forces grep). Exit 0 on any directory; exit 2 when the path is
# not a directory. Environment: see lib.sh.

# shellcheck disable=SC2016 # awk programs and literal $ in single quotes
set -u
LIB=$(dirname "$0")/lib.sh
# shellcheck source=lib.sh
. "$LIB"
TOP=${2:-15}
ds_init "${1:-.}" count-hardcoded
ds_tailwind
ds_tokens

EXT='\.(css|scss|sass|less|pcss|styl|ts|tsx|js|jsx|mjs|cjs|mts|cts|vue|svelte|astro|html|mdx)$'
grep -E "$EXT" "$TMP/files" > "$TMP/scan"
grep -E "$EXT" "$TMP/gen" > "$TMP/genscan"

ENGINE=${COUNT_ENGINE:-}
if [ -z "$ENGINE" ]; then if have rg; then ENGINE="rg"; else ENGINE="grep"; fi; fi

# ---------- mirror with comments stripped; definition lines set apart ----------
M="$TMP/m"
mkdir -p "$M"
sed -n 's#/[^/]*$##p' "$TMP/scan" | sort -u | tr '\n' '\0' | (cd "$M" && xargs -0 mkdir -p 2>/dev/null)
: > "$TMP/defs"
sed 's#^#./#' "$TMP/scan" | tr '\n' '\0' | xargs -0 awk -v M="$M" -v D="$TMP/defs" -v TF="$TMP/tokenfiles" '
  BEGIN { while ((getline l < TF) > 0) tok[l] = 1 }
  function emit(l) {
    if (!istok && l ~ /^[ \t]*(\$[A-Za-z0-9_-]+|--[A-Za-z0-9_-]+|#\{\$[A-Za-z0-9_-]+\}[A-Za-z0-9_-]+|@[A-Za-z0-9_-]+)[ \t]*:/) { print l >> D; print "" > out }
    else print l > out
  }
  FNR == 1 {
    if (out != "") close(out)
    name = FILENAME; sub(/^\.\//, "", name); out = M "/" name; istok = (name in tok)
    inblock = 0; inhtml = 0; fence = 0
    slash = (name ~ /\.(scss|sass|less|styl|ts|tsx|js|jsx|mjs|cjs|mts|cts|vue|svelte|astro|mdx)$/)
    html = (name ~ /\.(html|vue|svelte|astro|mdx)$/)
    md = (name ~ /\.mdx$/)
  }
  {
    line = $0
    if (md && line ~ /^[ \t]*(```|~~~)/) { fence = !fence; print "" > out; next }
    if (fence) { print "" > out; next }
    if (!inblock && !inhtml && index(line, "/") == 0 && index(line, "<!--") == 0) { emit(line); next }
    res = ""; i = 1; n = length(line); q = ""
    while (i <= n) {
      c = substr(line, i, 1); c2 = substr(line, i, 2)
      if (inblock) { if (c2 == "*/") { inblock = 0; i += 2 } else i++; continue }
      if (inhtml) { if (substr(line, i, 3) == "-->") { inhtml = 0; i += 3 } else i++; continue }
      if (q != "") {
        res = res c
        if (c == "\\") { res = res substr(line, i + 1, 1); i += 2; continue }
        if (c == q) q = ""
        i++; continue
      }
      if ((c == "\"" || c == "'"'"'") && (i == 1 || substr(line, i - 1, 1) !~ /[A-Za-z0-9]/)) { q = c; res = res c; i++; continue }
      if (c2 == "/*") { inblock = 1; i += 2; continue }
      if (slash && c2 == "//" && (i == 1 || substr(line, i - 1, 1) != ":")) break
      if (html && substr(line, i, 4) == "<!--") { inhtml = 1; i += 4; continue }
      res = res c; i++
    }
    emit(res)
  }' 2>/dev/null

# scan NAME PATTERN DIR LIST: writes "file<TAB>match" lines to $TMP/m.NAME
scan() {
  (
    cd "$3" || exit 0
    if [ "$ENGINE" = rg ]; then
      tr '\n' '\0' < "$4" | xargs -0 rg -o --no-heading --with-filename --no-line-number \
        --no-config --color never -e "$2" -- 2>/dev/null
    else
      tr '\n' '\0' < "$4" | xargs -0 grep -oHE "$2" /dev/null 2>/dev/null
    fi
  ) | awk '{ i = index($0, ":"); if (i > 0) print substr($0, 1, i - 1) "\t" substr($0, i + 1) }' | LC_ALL=C sort > "$TMP/m.$1"
}

PALETTES='slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|mauve|olive|mist|taupe'
PREFIX='bg|text|border|border-[trblxyse]|ring|ring-offset|fill|stroke|from|via|to|outline|divide|placeholder|decoration|shadow|inset-shadow|drop-shadow|accent|caret'
NAMED='white|black|gray|grey|silver|red|maroon|orange|yellow|olive|lime|green|teal|aqua|cyan|blue|navy|purple|fuchsia|magenta|pink|brown|gold|indigo|violet|crimson|coral|tomato|salmon|khaki|beige|ivory|lavender|plum|orchid|tan|chocolate|darkgray|darkgrey|lightgray|lightgrey|whitesmoke|gainsboro'
PROPS='color|background(-color|Color)?|border(-(top|right|bottom|left|block|inline))?(-color|Color)?|outline(-color|Color)?|fill|stroke|box-?[sS]hadow|text-?[sS]hadow|caret-?[cC]olor|accent-?[cC]olor|column-rule(-color)?'

run_scans() { # run_scans SUFFIX DIR LIST
  scan "hex$1" '(^|[^0-9A-Za-z_&/#])#[0-9A-Fa-f]{3,8}[0-9A-Za-z_-]*' "$2" "$3"
  scan "colorfn$1" '(^|[^0-9A-Za-z_-])(rgba?|hsla?|oklch|oklab|lch|lab|hwb)\([[:space:]]*[-+.0-9][^)]*\)' "$2" "$3"
  scan "named$1" "(^|[^A-Za-z0-9_-])($PROPS)[\"']?[[:space:]]*:[[:space:]]*[^;{}]*" "$2" "$3"
  scan "px$1" '(^|[^0-9A-Za-z_.$#-])[0-9]*\.?[0-9]+px[0-9A-Za-z_-]*' "$2" "$3"
  scan "rem$1" '(^|[^0-9A-Za-z_.$#-])[0-9]*\.?[0-9]+r?em[0-9A-Za-z_-]*' "$2" "$3"
  if [ -n "$TW" ]; then
    scan "palette$1" "(^|[^0-9A-Za-z_-])($PREFIX)-(($PALETTES)-[0-9]{2,3}|white|black)[0-9A-Za-z_-]*" "$2" "$3"
    scan "arb$1" '(^|[[:space:]"'"'"'`{:!(,])-?[a-z][a-z0-9-]*-\[[^]"'"'"'`[:space:]]+\]' "$2" "$3"
  fi
}

# normalize SUFFIX: validates each raw match and writes "file<TAB>value" per category.
normalize() {
  s=$1
  awk -F '\t' '{ v = $2; sub(/^[^#]*/, "", v); h = v; sub(/^#/, "", h); l = length(h)
    if (h ~ /^[0-9A-Fa-f]+$/ && (l == 3 || l == 4 || l == 6 || l == 8)) print $1 "\t" tolower(v) }' "$TMP/m.hex$s" > "$TMP/c.hex$s"
  awk -F '\t' '{ v = $2; sub(/^[^a-z]*/, "", v); gsub(/[ \t]+/, " ", v); print $1 "\t" tolower(v) }' "$TMP/m.colorfn$s" > "$TMP/c.colorfn$s"
  awk -F '\t' -v N="$NAMED" '
    BEGIN { n = split(N, L, "|") }
    { v = $2; sub(/^[^:]*:/, "", v)
      for (i = 1; i <= n; i++) if (match(v, "(^|[^A-Za-z0-9_.$-])" L[i] "([^A-Za-z0-9_-]|$)")) print $1 "\t" L[i] }' "$TMP/m.named$s" > "$TMP/c.named$s"
  for u in px rem; do
    awk -F '\t' -v u="$u" '{ v = $2; sub(/^[^0-9.]/, "", v)
      ok = (u == "px") ? (v ~ /^[0-9]*\.?[0-9]+px$/) : (v ~ /^[0-9]*\.?[0-9]+r?em$/)
      if (!ok) next
      num = v; sub(/[a-z]+$/, "", num); if (num + 0 == 0) next
      print $1 "\t" v }' "$TMP/m.$u$s" > "$TMP/c.$u$s"
  done
  if [ -n "$TW" ]; then
    awk -F '\t' -v P="$PALETTES" -v X="$PREFIX" '{ v = $2; sub(/^[^a-z]/, "", v)
      if (v ~ ("^(" X ")-((" P ")-[0-9][0-9][0-9]?|white|black)$")) print $1 "\t" v }' "$TMP/m.palette$s" > "$TMP/c.palette$s"
    : > "$TMP/c.arbcolor$s"; : > "$TMP/c.arbvar$s"; : > "$TMP/c.arblen$s"; : > "$TMP/c.arbother$s"
    : > "$TMP/c.runtime$s"; : > "$TMP/c.keyword$s"
    awk -F '\t' -v T="$TMP" -v s="$s" '
      { m = $2; sub(/^[^a-z-]*/, "", m)
        if (m ~ /^(data|aria|supports|has|group|peer|not|in|nth|nth-last|min|max)-\[/) next
        v = m; sub(/^[^[]*\[/, "", v); sub(/\]$/, "", v)
        if (v ~ /^var\(--(radix|base-ui|reka|bits|headlessui|kb|ark|floating|tw)-/) c = "runtime"
        else if (v ~ /^(inherit|initial|unset|auto|none|revert|revert-layer|currentColor|currentcolor|transparent)$/) c = "keyword"
        else if (v ~ /#[0-9A-Fa-f]|rgb|hsl|oklch|oklab/) c = "arbcolor"
        else if (v ~ /^var\(--/) c = "arbvar"
        else if (v ~ /[0-9](px|rem|em|vh|vw|dvh|svh|ch|%)/) c = "arblen"
        else c = "arbother"
        print $1 "\t" m > (T "/c." c s) }' "$TMP/m.arb$s"
  fi
}

run_scans "" "$M" "$TMP/scan"
normalize ""
# Literals on local definition lines ($var:, --var:, @var:) outside token sources.
printf 'defs\n' > "$TMP/defslist"
cp "$TMP/defs" "$TMP/defsdir.defs" 2>/dev/null
mkdir -p "$TMP/d" && mv "$TMP/defsdir.defs" "$TMP/d/defs"
run_scans ".d" "$TMP/d" "$TMP/defslist"
normalize ".d"

CATS="hex colorfn named px rem"
[ -n "$TW" ] && CATS="$CATS palette arbcolor arbvar arblen arbother"

# Split usage from definitions in token sources.
for c in $CATS; do
  awk -F '\t' -v tf="$TMP/tokenfiles" -v U="$TMP/u.$c" -v T="$TMP/t.$c" '
    BEGIN { while ((getline l < tf) > 0) tok[l] = 1 }
    { if ($1 in tok) print > T; else print > U }' "$TMP/c.$c"
  touch "$TMP/u.$c" "$TMP/t.$c"
done
cnt() { wc -l < "$1" | tr -d ' '; }

# Files rendered outside the DOM, where CSS variables do not exist.
tr '\n' '\0' < "$TMP/scan" | xargs -0 grep -lE "@vercel/og|next/og|ImageResponse|from ['\"]satori['\"]|@react-email/|react-email|@react-pdf/renderer|mjml" /dev/null 2>/dev/null > "$TMP/nondom"

echo "# count-hardcoded: pattern matches, not violations"
echo "root: $ROOT"
echo "engine: $ENGINE"
echo "files-scanned: $(cnt "$TMP/scan") source files; excluded: $(cnt "$TMP/genscan") generated files (detect-stack.sh generated:), vendored trees, minified files"
if [ -n "$TW" ]; then echo "tailwind: v${TW_MAJOR:-?} detected; palette and arbitrary-value columns shown"
else echo "tailwind: not detected; Tailwind columns omitted"; fi
echo "token-sources: $(list_or_none 6 < "$TMP/tokenfiles")"
printf 'legend: hex = #rgb to #rrggbbaa; colorfn = rgb() hsl() oklch() lab() lch() hwb() with a literal first argument (rgba($token, .5) and hsl(var(--x)) are not counted); named = CSS named colors in color properties; px, rem = non-zero literals; hex, px and rem also count values inside Tailwind arbitrary values'
[ -n "$TW" ] && printf '; palette = raw Tailwind palette steps and white/black (text-gray-500, bg-white); arbcolor/arbvar/arblen/arbother = Tailwind arbitrary values holding a color, a var(), a length, anything else'
printf '. Comments, Markdown code fences and lines defining a variable ($x:, --x:, @x:) are excluded from usage.\n'
echo
echo "## totals"
printf '%-10s %8s %16s %18s\n' category usage in-token-sources on-local-definitions
for c in $CATS; do printf '%-10s %8s %16s %18s\n' "$c" "$(cnt "$TMP/u.$c")" "$(cnt "$TMP/t.$c")" "$(cnt "$TMP/c.$c.d" 2>/dev/null || echo 0)"; done

echo
echo "## by directory (usage only, first two path segments)"
for c in $CATS; do
  awk -F '\t' -v c="$c" '{ n = split($1, p, "/"); d = (n > 2 ? p[1] "/" p[2] : (n == 2 ? p[1] : ".")); print d "\t" c }' "$TMP/u.$c"
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
  echo "no usage matches"
fi

if [ -n "$TW" ]; then
  echo
  echo "## palettes used (usage)"
  awk -F '\t' -v P="$PALETTES|white|black" '
    BEGIN { n = split(P, L, "|") }
    { for (i = 1; i <= n; i++) if ($2 ~ ("-" L[i] "(-|$)")) { c[L[i]]++; break } }
    END { for (k in c) print c[k] " " k }' "$TMP/u.palette" | sort -k1,1nr -k2,2 | awk '{ printf "%s%s %s", (NR > 1 ? ", " : ""), $2, $1 } END { if (NR == 0) printf "none"; printf "\n" }'
fi

echo
echo "## repeated values (usage, 2 or more uses, top $TOP): a repeated literal is a candidate missing token"
for c in $CATS; do awk -F '\t' -v c="$c" '{ print c "\t" $2 "\t" $1 }' "$TMP/u.$c"; done \
  | awk -F '\t' '{ k = $1 "\t" $2; n[k]++; if (!((k, $3) in seen)) { seen[k, $3] = 1; nf[k]++; if (nf[k] <= 2) f[k] = f[k] (nf[k] > 1 ? ", " : "") $3 } }
    END { for (k in n) if (n[k] >= 2) { split(k, a, "\t"); printf "%d\t%6d  %-9s %-28s in %d file%s: %s%s\n", n[k], n[k], a[1], a[2], nf[k], (nf[k] > 1 ? "s" : ""), f[k], (nf[k] > 2 ? ", ..." : "") } }' \
  | sort -t "$(printf '\t')" -k1,1nr -k2,2 | cut -f2- | head -n "$TOP" > "$TMP/rep"
if [ -s "$TMP/rep" ]; then cat "$TMP/rep"; else echo "none"; fi

echo
echo "## top $TOP files (usage, all categories)"
for c in $CATS; do cut -f1 "$TMP/u.$c"; done | sort | uniq -c | sort -k1,1nr -k2,2 | head -n "$TOP" \
  | awk -v nd="$TMP/nondom" 'BEGIN { while ((getline l < nd) > 0) x[l] = 1 } { f = $2; for (i = 3; i <= NF; i++) f = f " " $i; printf "%6d %s%s\n", $1, f, (f in x ? "  (rendered outside the DOM)" : "") }'

echo
echo "## token sources (matches here are definitions)"
if [ -s "$TMP/tokens" ]; then
  for c in $CATS; do cut -f1 "$TMP/t.$c"; done | sort | uniq -c > "$TMP/tcount"
  awk -F '\t' -v tc="$TMP/tcount" 'BEGIN { while ((getline l < tc) > 0) { n = l; sub(/^ *[0-9]+ /, "", n); c = l; sub(/^ */, "", c); sub(/ .*/, "", c); m[n] = c } }
    { printf "%6d %s (%s: %s)\n", m[$1] + 0, $1, $2, $3 }' "$TMP/tokens" | sort -k1,1nr | head -n 20
else
  echo "none detected (set DS_TOKEN_SOURCES to name them)"
fi

echo
echo "## notes"
[ -n "$TW" ] && echo "arbitrary values reading runtime variables (--radix-*, --base-ui-*, --tw-*), not counted: $(cnt "$TMP/c.runtime")$(cut -f2 "$TMP/c.runtime" | sed -E 's/.*var\(--([a-z]+(-ui)?)-.*/\1/' | sort | uniq -c | awk '{ printf "%s%s %s", (NR > 1 ? ", " : " ("), $2, $1 } END { if (NR) printf ")" }')"
[ -n "$TW" ] && echo "arbitrary values holding a CSS keyword (inherit, auto, none...), not counted: $(cnt "$TMP/c.keyword")"
echo "files rendered outside the DOM (CSS variables unavailable, literals may be required): $(list_or_none 5 < "$TMP/nondom")"
echo "not counted by design: unitless numbers in JS style objects (fontSize: 13), spacing keys in JS size maps, values built at runtime"

exit 0
