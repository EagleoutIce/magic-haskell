#!/usr/bin/env bash
# Generates the link database of magic-haskell from the documentation on Hackage.
#
#   tools/generate-links.sh [--pin] [-o magic-haskell-links.cfg] [tools/packages.txt]
#   tools/generate-links.sh --verify [magic-haskell-links.cfg]
#
# Every line of the package list names a package, its version, and the
# modules to link. The version 'latest' is the newest version with
# documentation on Hackage; --pin writes the versions used back into the
# list. The module '*' stands for all remaining modules of the package.
# A name exported by several modules links to the first of them that is
# active in the document, so 'base 4.22.0.0 Prelude *' prefers the Prelude.
# The names are read from the anchors of the module pages.
#
# The generated file is verified right away, --verify does so again later:
# every link is recomputed exactly as magic-haskell does and its page and anchor
# must exist on Hackage.
#
# Requires bash, curl, jq, and awk. Pages are cached in $MHS_CACHE.
set -euo pipefail -o noglob   # noglob: the module lists contain a literal '*'
unset -f grep 2>/dev/null || true
export LC_ALL=C

HACKAGE="https://hackage.haskell.org/package"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${MHS_CACHE:-${TMPDIR:-/tmp}/magic-haskell-cache}"
mkdir -p "$CACHE"

die() { echo "error: $*" >&2; exit 1; }

# LABEL DONE TOTAL: a line on stderr whenever another tenth of TOTAL is done
progress() {
    local tenth=$(( $2 * 10 / $3 ))
    if [ "$2" -eq 1 ] || [ "$tenth" != "${PROGRESS_TENTH:-}" ]; then
        PROGRESS_TENTH=$tenth
        printf '  %s: %3d%% (%d/%d)\n' "$1" $(( $2 * 100 / $3 )) "$2" "$3" >&2
    fi
}

# fetch URL: print the path of the cached page. Redirects may change the
# host (Hackage serves documentation from hackage-content), but not the
# path, which would mean another version.
fetch() {
    local file="$CACHE/$(echo "$1" | tr -c 'A-Za-z0-9.\n' '_')" out
    if [ ! -s "$file" ]; then
        out="$(curl -sL -o "$file.part" -w '%{http_code} %{url_effective}' "$1")" || out="000 -"
        if [ "${out%% *}" != 200 ] || [ "${out#* https://*/}" != "${1#https://*/}" ]; then
            rm -f "$file.part"; return 1
        fi
        mv "$file.part" "$file"
    fi
    echo "$file"
}
docs() { local m="${3:-}"; echo "$HACKAGE/$1-$2/docs/${m//./-}${m:+.html}"; }   # PKG VER [MODULE]

newest_version() {
    local v
    for v in $(curl -sf -H 'Accept: application/json' "$HACKAGE/$1/preferred" \
            | jq -r '."normal-version"[]' | head -n 10); do
        fetch "$(docs "$1" "$v")" >/dev/null && { echo "$v"; return; }
    done
    return 1
}

# the listed modules, '*' expanded to the remaining modules of the package
modules() {
    local all mod
    all="$(grep -o 'href="[A-Z][A-Za-z0-9_-]*\.html"' "$(fetch "$(docs "$1" "$2")")" \
        | sed 's/^href="//; s/\.html"$//; s/-/./g')"
    for mod in "${@:3}"; do
        if [ "$mod" = "*" ]; then echo "$all"; else echo "$mod"; fi
    done | awk '!seen[$0]++'
}

# The haddock anchor of a name, as \mhs@encode computes it ('.' and ':' stay),
# and the names magic-haskell can take (no '#', '%', '^', '~', '\', braces, or
# commas; no reserved syntax; single characters except '$' would break numbers).
AWK_LIB='
BEGIN { for (i = 32; i < 127; i++) ORD[sprintf("%c", i)] = i }
function encode(s,   out, i, c) {
    for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); out = out (c ~ /[A-Za-z0-9_.:]/ ? c : "-" ORD[c] "-") }
    return out
}
function decode(s,   out) {
    while (match(s, /-[0-9]+-/)) {
        out = out substr(s, 1, RSTART - 1) sprintf("%c", substr(s, RSTART + 1, RLENGTH - 2) + 0)
        s = substr(s, RSTART + RLENGTH)
    }
    return out s
}
function usable(s) {
    if (s ~ /^[A-Za-z_][A-Za-z0-9_'"'"']*$/) return 1
    if (s !~ /^[-!$&*+.\/<=>?@|:]+$/ || s ~ /--/ || s ~ /^(=|@|\||\.\.|::|->|<-|=>|:)$/) return 0
    return length(s) > 1 || s == "$"
}
function tex(s) { gsub(/\$/, "\\$", s); gsub(/&/, "\\\\&", s); return s }
function kind(s, constructors) { return (!constructors && s ~ /^[A-Z]/) ? "t" : "v" }  # as \mhs@kind
'

# PKG MODULE PAGE: the \mhsLinks and \mhsConstructors of one module. A name
# may appear in many modules, magic-haskell picks the first active one; within a
# module it appears once (the type IO, not its constructor).
module_entries() {
    { grep -o 'id="[tv]:[^"]*"' "$3" || true; } | sed 's/^id="//; s/"$//' \
    | awk -v pkg="$1" -v mod="$2" "$AWK_LIB"'
    {
        name = decode(substr($0, 3))
        if (name in seen || !usable(name) || encode(name) != substr($0, 3)) next
        if ($0 ~ /^t:/ && name !~ /^[A-Z]/) next          # type operators
        seen[name] = 1
        if ($0 ~ /^v:[A-Z]/) cons[++nc] = name; else links[++nl] = name
    }
    function block(cmd, names, n,   i, line) {
        if (!n) return
        printf "\\%s[%s]{%s}{%%\n", cmd, pkg, mod
        for (i = 1; i <= n; i++) {
            line = line tex(names[i]) ","
            if (length(line) > 72 || i == n) { print line "%"; line = "" }
        }
        print "}%"
    }
    END { block("mhsLinks", links, nl); block("mhsConstructors", cons, nc) }'
}

generate() { # LIST OUT
    local tmp pinned line pkg ver mod mods page n i=0 k all
    n="$(grep -cv '^[[:space:]]*\(#\|$\)' "$1")"
    tmp="$(mktemp)"; pinned="$(mktemp)"
    printf '%% magic-haskell-links.cfg -- generated by tools/generate-links.sh on %s.\n%% Do not edit, regenerate it from tools/packages.txt.\n' \
        "$(date -u +%Y-%m-%d)" > "$tmp"
    while IFS= read -r line; do
        read -r pkg ver mods <<< "$line" || true
        if [[ -z "$pkg" || "$pkg" == \#* ]]; then echo "$line" >> "$pinned"; continue; fi
        if [ "$ver" = latest ]; then
            ver="$(newest_version "$pkg")" || die "no version of '$pkg' with documentation on Hackage"
        else
            fetch "$(docs "$pkg" "$ver")" >/dev/null || die "$pkg-$ver has no documentation on Hackage"
        fi
        echo "$pkg $ver $mods" >> "$pinned"
        i=$((i + 1)); echo "[$i/$n] $pkg-$ver" >&2
        echo "\\mhsPackage{$pkg}{$ver}{%" >> "$tmp"
        all=($(modules "$pkg" "$ver" $mods)); k=0
        for mod in "${all[@]}"; do
            page="$(fetch "$(docs "$pkg" "$ver" "$mod")")" || die "$pkg-$ver has no module '$mod'"
            module_entries "$pkg" "$mod" "$page" >> "$tmp"
            k=$((k + 1)); progress modules "$k" "${#all[@]}"
        done
        echo "}" >> "$tmp"
    done < "$1"
    mv "$tmp" "$2"
    if [ "$PIN" = 1 ]; then sed 's/ *$//' "$pinned" > "$1"; fi
    rm -f "$pinned"
}

verify() { # FILE
    local total=0 failed=0 pkg ver mod anchor page links
    mapfile -t links < <(awk "$AWK_LIB"'
        /^\\mhsPackage\{/ { split($0, p, /[{}]/); pkg = p[2]; ver = p[4] }
        /^\\mhs(Links|Constructors)\[/ { cons = /Constructors/; split($0, p, /[{}]/); mod = p[2]; next }
        /^\}/ { mod = "" }
        mod != "" {
            sub(/%$/, ""); n = split($0, names, ",")
            for (i = 1; i <= n; i++) if (names[i] != "") {
                gsub(/\\/, "", names[i])
                printf "%s\t%s\t%s\t%s:%s\n", pkg, ver, mod, kind(names[i], cons), encode(names[i])
            }
        }' "$1")
    echo "verifying ${#links[@]} links" >&2
    for line in "${links[@]}"; do
        IFS=$'\t' read -r pkg ver mod anchor <<< "$line"
        total=$((total + 1)); progress links "$total" "${#links[@]}"
        page="$(fetch "$(docs "$pkg" "$ver" "$mod")")" && grep -qF "id=\"$anchor\"" "$page" && continue
        echo "FAIL $(docs "$pkg" "$ver" "$mod")#$anchor"; failed=$((failed + 1))
    done
    echo "verified $total links, $failed failed" >&2
    [ "$failed" -eq 0 ]
}

case "${1:-}" in
    --verify) verify "${2:-$ROOT/magic-haskell-links.cfg}" ;;
    -h|--help) sed -n '2,18p' "$0" | cut -c3- ;;
    *)
        out="$ROOT/magic-haskell-links.cfg" PIN=0
        if [ "${1:-}" = "--pin" ]; then PIN=1; shift; fi
        if [ "${1:-}" = "-o" ]; then out="$2"; shift 2; fi
        generate "${1:-$ROOT/tools/packages.txt}" "$out"
        verify "$out"
        ;;
esac
