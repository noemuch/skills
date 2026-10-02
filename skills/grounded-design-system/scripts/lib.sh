# lib.sh: shared code for detect-stack.sh, count-hardcoded.sh and component-usage.sh.
# Sourced, never run. Builds one file universe so every script counts the same
# files: vendored trees, build output and generated files are excluded the same
# way everywhere. Read-only: writes only under its own temporary directory.
#
# Environment overrides, each optional:
#   DS_EXCLUDE        extra ERE on paths to exclude (e.g. '^legacy/')
#   DS_GENERATED      space-separated paths or directories to treat as generated
#   DS_TOKEN_SOURCES  space-separated files to treat as token sources
#   DS_OFFLINE=1      skip every network call (gh)
# shellcheck shell=sh disable=SC2034,SC2016
# SC2034: this file sets globals for the scripts that source it. SC2016: awk programs.

have() { command -v "$1" >/dev/null 2>&1; }

# ds_init ROOT NAME: cd into ROOT, create $TMP, build $TMP/all and $TMP/files.
ds_init() {
  ROOT=${1:-.}
  if [ ! -d "$ROOT" ]; then
    echo "error: $ROOT is not a directory" >&2
    exit 2
  fi
  ROOT=$(cd "$ROOT" && pwd)
  cd "$ROOT" || exit 2
  TMP=$(mktemp -d 2>/dev/null || mktemp -d -t "${2:-ds}")
  # shellcheck disable=SC2064
  trap "rm -rf '$TMP'" EXIT INT TERM
  ds_list_files
  ds_read_packages
  ds_find_generated
}

# Directories that are never source, wherever they sit.
DS_VENDORED='(^|/)(node_modules|bower_components|dist|build|out|\.next|\.nuxt|\.output|\.svelte-kit|\.turbo|\.vercel|\.cache|\.docusaurus|\.contentlayer|\.yarn|coverage|vendor|storybook-static|__snapshots__|\.git)/'
DS_BUILT='\.(min\.(js|mjs|css)|map|d\.ts|snap)$|(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?)$'

ds_list_files() {
  IS_GIT=no
  if have git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then IS_GIT=yes; fi
  if [ "$IS_GIT" = yes ]; then
    git ls-files --cached --others --exclude-standard 2>/dev/null
  else
    find . \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .next \
      -o -name .turbo -o -name coverage -o -name vendor -o -name .svelte-kit -o -name .nuxt \
      -o -name storybook-static \) -prune -o -type f -print 2>/dev/null | sed 's#^\./##'
  fi | grep -Ev "$DS_VENDORED" | grep -Ev "$DS_BUILT" | sort -u > "$TMP/raw"
  if [ -n "${DS_EXCLUDE:-}" ]; then
    grep -Ev "$DS_EXCLUDE" "$TMP/raw" > "$TMP/raw2"
    mv "$TMP/raw2" "$TMP/raw"
  fi
  # git ls-files lists deleted-but-unstaged files; keep what exists.
  while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done < "$TMP/raw" > "$TMP/all"
}

# Every package.json: dependencies, package fields, scripts, husky v4 hooks.
ds_read_packages() {
  grep -E '(^|/)package\.json$' "$TMP/all" > "$TMP/pkgs"
  : > "$TMP/deps"; : > "$TMP/pkgmeta"; : > "$TMP/scripts"
  [ -s "$TMP/pkgs" ] || return 0
  if have node; then
    node -e '
      const fs = require("fs"), path = require("path");
      const deps = new Map(), meta = [], scripts = [];
      for (const p of fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean)) {
        let j; try { j = JSON.parse(fs.readFileSync(p, "utf8")); } catch { continue; }
        const dir = path.dirname(p);
        for (const k of ["dependencies", "devDependencies", "peerDependencies"])
          for (const [n, v] of Object.entries(j[k] || {})) if (!deps.has(n)) deps.set(n, String(v));
        const put = (k, v) => meta.push([p, k, v].join("\t"));
        put("name", j.name || "");
        put("private", j.private === true ? "yes" : "no");
        for (const k of ["main", "module", "style", "sass", "types", "typings"]) if (j[k]) put(k, String(j[k]));
        if (j.exports) put("exports", "yes");
        if (Array.isArray(j.files)) put("files", j.files.join(" "));
        if (j.workspaces) put("workspaces", "yes");
        if (j.husky && j.husky.hooks) put("husky-hooks", Object.entries(j.husky.hooks).map(([h, c]) => h + ": " + c).join("; "));
        if (j["lint-staged"]) put("lint-staged", "yes");
        if (j["simple-git-hooks"]) put("simple-git-hooks", "yes");
        for (const [n, c] of Object.entries(j.scripts || {})) scripts.push([dir, n, String(c).replace(/\s+/g, " ")].join("\t"));
      }
      fs.writeFileSync(process.argv[2], [...deps].sort().map(([n, v]) => n + " " + v).join("\n") + (deps.size ? "\n" : ""));
      fs.writeFileSync(process.argv[3], meta.join("\n") + (meta.length ? "\n" : ""));
      fs.writeFileSync(process.argv[4], scripts.join("\n") + (scripts.length ? "\n" : ""));
    ' "$TMP/pkgs" "$TMP/deps" "$TMP/pkgmeta" "$TMP/scripts" 2>/dev/null
  else
    # Fallback: every "key": "value" pair is a candidate dependency. Over-matches, never misses.
    while IFS= read -r p; do
      grep -oE '"[@a-zA-Z0-9/._-]+"[[:space:]]*:[[:space:]]*"[^"]*"' "$p" 2>/dev/null
    done < "$TMP/pkgs" | sed -E 's/^"([^"]+)"[[:space:]]*:[[:space:]]*"([^"]*)"$/\1 \2/' | sort -u -k1,1 > "$TMP/deps"
    grep -oE '"(build|build:[^"]*|compile[^"]*|css[^"]*|icons[^"]*|images[^"]*)"[[:space:]]*:[[:space:]]*"[^"]*"' package.json 2>/dev/null \
      | sed -E 's/^"([^"]+)"[[:space:]]*:[[:space:]]*"([^"]*)"$/.\t\1\t\2/' > "$TMP/scripts"
    grep -q '"private"[[:space:]]*:[[:space:]]*true' package.json 2>/dev/null && printf 'package.json\tprivate\tyes\n' >> "$TMP/pkgmeta"
  fi
}

dep() { awk -v n="$1" '$1 == n { print $2; exit }' "$TMP/deps"; }
deps_like() { grep -E "^($1) " "$TMP/deps" 2>/dev/null | awk '{ print $1 }' | tr '\n' ' ' | sed 's/ $//'; }
pkgmeta() { awk -F '\t' -v p="${2:-package.json}" -v k="$1" '$1 == p && $2 == k { print $3; exit }' "$TMP/pkgmeta"; }

# Build output and generated files. Writes $TMP/genwhy ("path<TAB>reason"),
# $TMP/genpat (one ERE per line) and $TMP/files (source files only).
ds_find_generated() {
  : > "$TMP/genwhy"
  # 1. Outputs named in package.json scripts: sass in:out, --out-dir, --outDir, -d, -o.
  awk -F '\t' '
    function norm(p) { sub(/^\.\//, "", p); sub(/\/+$/, "", p); gsub(/["'"'"']/, "", p); return p }
    function emit(dir, p, why, svgr) {
      p = norm(p); if (p == "" || p == "." || p ~ /^-/ || p ~ /\*/) return
      if (dir != ".") p = dir "/" p
      print p "\t" (svgr ? "svgr" : "out") "\t" why
    }
    {
      n = split($3, seg, /&&|;|\|\|/)
      for (s = 1; s <= n; s++) {
        line = seg[s]
        if (line !~ /(^|[ \/])(sass|node-sass|postcss|svgr|babel|tsc|tailwindcss|lessc|stylus|style-dictionary|cleancss|esbuild|tsup|rollup)( |$)/) continue
        svgr = (line ~ /svgr/)
        w = split(line, word, / +/)
        for (i = 1; i <= w; i++) {
          if (line ~ /(^|[ \/])(sass|node-sass)( |$)/ && word[i] ~ /^[A-Za-z0-9_.\/-]+:[A-Za-z0-9_.\/-]+$/ && word[i] !~ /:\/\//) {
            split(word[i], io, ":"); emit($1, io[2], "scripts." $2 ": " $3, 0)
          }
          if (word[i] ~ /^(--out-dir|--outDir|--outdir|--output-dir|--dir|-d|-o|--output|--out-file)$/ && i < w) emit($1, word[i + 1], "scripts." $2 ": " $3, svgr)
          else if (word[i] ~ /^(--out-dir|--outDir|--outdir|--output-dir|--output)=/) { v = word[i]; sub(/^[^=]*=/, "", v); emit($1, v, "scripts." $2 ": " $3, svgr) }
        }
      }
    }' "$TMP/scripts" 2>/dev/null | sort -u > "$TMP/gen-scripts"
  while IFS="$(printf '\t')" read -r p kind why; do
    [ -n "$p" ] || continue
    why=$(printf '%s' "$why" | cut -c1-90)
    if [ "$kind" = svgr ]; then
      printf '%s/*.{tsx,jsx,ts,js}\t%s\n' "$p" "$why" >> "$TMP/genwhy"
      printf '^%s/.*\\.(tsx|jsx|ts|js)$\n' "$(ds_ere_escape "$p")" >> "$TMP/genpat"
    elif [ -d "$p" ]; then
      printf '%s/\t%s\n' "$p" "$why" >> "$TMP/genwhy"
      printf '^%s/\n' "$(ds_ere_escape "$p")" >> "$TMP/genpat"
    elif [ -f "$p" ]; then
      printf '%s\t%s\n' "$p" "$why" >> "$TMP/genwhy"
      printf '^%s$\n' "$(ds_ere_escape "$p")" >> "$TMP/genpat"
    fi
  done < "$TMP/gen-scripts"
  # 2. A css/ directory beside a scss/, sass/ or less/ source directory.
  grep -E '(^|/)css/[^/]+\.css$' "$TMP/all" | sed -E 's#(^|/)css/[^/]+$#\1css#' | sort -u | while IFS= read -r d; do
    parent=$(dirname "$d")
    for src in scss sass less styl; do
      if [ "$parent" = . ]; then s=$src; else s="$parent/$src"; fi
      if grep -q "^$(ds_ere_escape "$s")/" "$TMP/all"; then
        grep -qxF "^$(ds_ere_escape "$d")/" "$TMP/genpat" 2>/dev/null || {
          printf '%s/\tcompiled output beside %s/\n' "$d" "$s" >> "$TMP/genwhy"
          printf '^%s/\n' "$(ds_ere_escape "$d")" >> "$TMP/genpat"
        }
        break
      fi
    done
  done
  # 3. Files declared generated by the team.
  for p in ${DS_GENERATED:-}; do
    p=${p%/}
    printf '%s\tDS_GENERATED\n' "$p" >> "$TMP/genwhy"
    printf '^%s(/|$)\n' "$(ds_ere_escape "$p")" >> "$TMP/genpat"
  done
  touch "$TMP/genpat"
  # 4. Files whose first 15 lines say they are generated.
  grep -E '\.(tsx|jsx|ts|js|mjs|cjs|css|scss|json)$' "$TMP/all" | sed 's#^#./#' | tr '\n' '\0' \
    | xargs -0 awk 'FNR > 15 { nextfile } /@generated|DO NOT EDIT|[Dd]o not edit (this file|directly)|[Aa]uto-?generated|[Tt]his file (is|was) (automatically )?generated|SVGRProps/ { name = FILENAME; sub(/^\.\//, "", name); print name; nextfile }' 2>/dev/null \
    | sort -u > "$TMP/genmarked"
  if [ -s "$TMP/genpat" ]; then
    grep -E -f "$TMP/genpat" "$TMP/all" > "$TMP/genfiles"
  else
    : > "$TMP/genfiles"
  fi
  # Stories and tests are hand-written even inside an output directory.
  cat "$TMP/genfiles" "$TMP/genmarked" | grep -Ev '\.(stories|test|spec)\.' | sort -u > "$TMP/gen"
  comm -23 "$TMP/all" "$TMP/gen" > "$TMP/files"
}

ds_ere_escape() { printf '%s' "$1" | sed 's/[][\.*^$+?(){}|]/\\&/g'; }

files_matching() { grep -E "$1" "$TMP/files" 2>/dev/null; }
count_matching() { files_matching "$1" | wc -l | tr -d ' '; }
first_matching() { files_matching "$1" | head -n "${2:-5}" | tr '\n' ' ' | sed 's/ $//'; }
# grep_l PATTERN FILE_REGEX: files matching FILE_REGEX whose content matches PATTERN.
grep_l() { files_matching "$2" | tr '\n' '\0' | xargs -0 grep -lE "$1" /dev/null 2>/dev/null; }
# list_or_none: joins stdin lines with spaces, keeps the first N (default 6), says how many more.
list_or_none() {
  awk -v max="${1:-6}" 'NF { n++; if (n <= max) out = out (n > 1 ? " " : "") $0 }
    END { if (n == 0) print "none"; else if (n > max) print out " (and " n - max " more)"; else print out }'
}

# Tailwind: sets TW (yes or empty), TW_MAJOR, TW_VER, TW_CFG, TW_ENTRY.
ds_tailwind() {
  TW_VER=$(dep tailwindcss)
  TW_CFG=$(first_matching '(^|/)tailwind\.config\.(js|cjs|mjs|ts|cts|mts)$' 3)
  tw4=$(grep_l '@import[[:space:]]+["'"'"']tailwindcss' '\.(css|scss|pcss)$' | head -n 3 | tr '\n' ' ' | sed 's/ $//')
  tw3=$(grep_l '^[[:space:]]*@tailwind[[:space:]]+(base|components|utilities)' '\.(css|scss|pcss|sass|less)$' | head -n 3 | tr '\n' ' ' | sed 's/ $//')
  TW_ENTRY=${tw4:-$tw3}
  TW_MAJOR=$(printf '%s' "$TW_VER" | sed -E 's/^[^0-9]*([0-9]+).*/\1/')
  if [ -z "$TW_MAJOR" ]; then
    if [ -n "$tw4" ]; then TW_MAJOR=4; elif [ -n "$tw3" ] || [ -n "$TW_CFG" ]; then TW_MAJOR=3; fi
  fi
  TW=""
  { [ -n "$TW_VER" ] || [ -n "$TW_CFG" ] || [ -n "$TW_ENTRY" ]; } && TW=yes
  return 0
}

# Token sources. Writes $TMP/tokens: "file<TAB>kind<TAB>detail", one line per file.
ds_tokens() {
  : > "$TMP/tokens"
  # CSS, Sass, Less: @theme, custom properties (plain or Sass-interpolated), Sass and Less variables.
  files_matching '\.(css|pcss|scss|sass|less)$' | tr '\n' '\0' | xargs -0 awk '
    function flush() {
      if (f == "") return
      if (theme) printf "%s\tcss\t@theme, %d custom properties\n", f, decl
      else if (decl >= 10) { n = 0; for (k in names) n++; printf "%s\tcss\t%d names, %d declarations\n", f, n, decl }
      else if (interp >= 10) printf "%s\tsass\t%d interpolated custom properties holding values (#{$prefix}name)\n", f, interp
      else if (svar >= 10) printf "%s\tsass\t%d variables with design values\n", f, svar
      else if (mapent >= 10) printf "%s\tsass\t%d map entries with design values\n", f, mapent
      else if (lvar >= 10) printf "%s\tless\t%d variables with design values\n", f, lvar
    }
    FNR == 1 { flush(); f = FILENAME; theme = decl = interp = svar = lvar = mapent = 0; split("", names) }
    /^[ \t]*@theme/ { theme = 1 }
    /^[ \t]*--[A-Za-z0-9_-]+[ \t]*:/ { decl++; k = $0; sub(/^[ \t]*/, "", k); sub(/[ \t]*:.*/, "", k); names[k] = 1 }
    # Component-level custom properties that only point at other ones (var(...)) are not a source.
    /^[ \t]*#\{\$[A-Za-z0-9_-]+\}[A-Za-z0-9_-]+[ \t]*:/ && !/:[ \t]*var\(/ { interp++ }
    /^[ \t]*["'"'"']?[A-Za-z0-9_-]+["'"'"']?[ \t]*:[ \t]*(\$|#[0-9A-Fa-f]|rgba?\(|hsla?\(|[-.0-9])[^;{]*,[ \t]*$/ { mapent++ }
    /^[ \t]*\$[A-Za-z0-9_-]+[ \t]*:[ \t]*(#[0-9A-Fa-f]|rgba?\(|hsla?\(|oklch\(|[-.0-9]+(px|rem|em|%|ms|s)?[ \t;!]|\(|\$)/ { svar++ }
    /^[ \t]*@[A-Za-z0-9_-]+[ \t]*:[ \t]*(#[0-9A-Fa-f]|rgba?\(|hsla?\(|[-.0-9]+(px|rem|em|%))/ { lvar++ }
    END { flush() }' 2>/dev/null >> "$TMP/tokens"
  # JS and TS theme objects: a theme constructor, or an exported design-named object holding 8+ literals.
  files_matching '\.(ts|tsx|js|jsx|mjs|cjs|mts|cts)$' | grep -Ev '\.(stories|test|spec)\.|(^|/)tailwind\.config\.' | tr '\n' '\0' | xargs -0 awk '
    function flush() {
      if (f == "") return
      if (ctor != "") printf "%s\tjs\t%s, %d literals\n", f, ctor, lit
      else if (named != "" && lit >= 8) printf "%s\tjs\texports %s, %d literals\n", f, named, lit
    }
    FNR == 1 { flush(); f = FILENAME; ctor = ""; named = ""; lit = 0 }
    /(createTheme|createGlobalTheme|createThemeContract|createStitches|extendTheme|defineTokens|defineSemanticTokens|makeTheme)\(/ && ctor == "" {
      c = $0; sub(/\(.*/, "", c); sub(/.*[^A-Za-z]/, "", c); ctor = c "()" }
    /semanticTokens[ \t]*:|^[ \t]*tokens[ \t]*:[ \t]*\{/ && ctor == "" { ctor = "theme config with tokens" }
    /export[ \t]+(const|let|var)[ \t]+(colou?rs?|palette|backgrounds?|spacing|space|sizes|radii|radius|shadows|typography|fonts|fontSizes|fontWeights|lineHeights|breakpoints|zIndices|theme|themes|tokens|vars)[ \t]*(:[^=]*)?=/ {
      n = $0; sub(/.*export[ \t]+(const|let|var)[ \t]+/, "", n); sub(/[ \t:=].*/, "", n); named = named (named == "" ? "" : ",") n }
    { s = $0; while (match(s, /#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]|rgba?\([ \t]*[0-9]|hsla?\([ \t]*[0-9]|[0-9]px|[0-9]rem/)) { lit++; s = substr(s, RSTART + RLENGTH) } }
    END { flush() }' 2>/dev/null >> "$TMP/tokens"
  # Tailwind config with a theme: v3 tokens.
  for c in $(files_matching '(^|/)tailwind\.config\.(js|cjs|mjs|ts|cts|mts)$'); do
    keys=$(ds_tailwind_theme_keys "$c")
    [ -n "$keys" ] && printf '%s\ttailwind-config\t%s\n' "$c" "$keys" >> "$TMP/tokens"
  done
  # DTCG and Style Dictionary JSON.
  # shellcheck disable=SC2016
  grep_l '"\$value"[[:space:]]*:' '\.json$' > "$TMP/dtcg"
  awk '{ print $0 "\tdtcg\t$value entries" }' "$TMP/dtcg" >> "$TMP/tokens"
  grep_l '"value"[[:space:]]*:' '(^|/)tokens?/.*\.json$' | grep -v -x -F -f "$TMP/dtcg" 2>/dev/null \
    | awk '{ print $0 "\tstyle-dictionary\tvalue entries" }' >> "$TMP/tokens"
  for p in ${DS_TOKEN_SOURCES:-}; do printf '%s\tdeclared\tDS_TOKEN_SOURCES\n' "$p" >> "$TMP/tokens"; done
  sort -u -t "$(printf '\t')" -k1,1 "$TMP/tokens" -o "$TMP/tokens"
  cut -f1 "$TMP/tokens" > "$TMP/tokenfiles"
}

# Keys of `theme` and `theme.extend` in a Tailwind config, read as text (never executed).
ds_tailwind_theme_keys() {
  awk '
    {
      line = $0
      key = ""
      if (match(line, /^[ \t]*["'"'"']?[A-Za-z0-9_-]+["'"'"']?[ \t]*:/)) { key = substr(line, RSTART, RLENGTH); gsub(/[ \t"'"'"':]/, "", key) }
      if (!intheme && key == "theme" && line ~ /\{/) { intheme = 1; base = depth + 1 }
      else if (intheme && key != "" && depth == base) { top = top (top == "" ? "" : " ") key; if (key == "extend" && line ~ /\{/) inext = 1; else inext = 0 }
      else if (intheme && inext && key != "" && depth == base + 1) ext = ext (ext == "" ? "" : " ") key
      o = gsub(/\{/, "{", line); c = gsub(/\}/, "}", line); depth += o - c
      if (intheme && depth < base) intheme = 0
      if (inext && depth <= base) inext = 0
    }
    END {
      if (top == "") exit
      out = "theme: " top
      if (ext != "") out = out "; theme.extend: " ext
      print out
    }' "$1" 2>/dev/null
}
