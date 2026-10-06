#!/usr/bin/env bash
# Window thumbnails for the dock hover preview.
#
# niri's only window-pixel API is `niri msg action screenshot-window`, which
# always places the result on the clipboard. Capture through it, but put the
# user's previous selection back afterwards so merely hovering the dock never
# eats the clipboard.
#
# Usage: window_thumbs.sh <cache-dir> <window-id>...
# Prints one line per window that produced a fresh PNG: "<id>"

set -uo pipefail

dir=${1-}
shift || true

if [ -z "$dir" ] || [ "$#" -eq 0 ]; then
    echo "usage: window_thumbs.sh <cache-dir> <window-id>..." >&2
    exit 2
fi

mkdir -p "$dir" || exit 1

# --- keep the user's clipboard -------------------------------------------
clip_type=""
clip_tmp=""
if command -v wl-paste >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then
    clip_type=$(timeout 1 wl-paste --list-types 2>/dev/null | head -n1 || true)
    if [ -n "$clip_type" ]; then
        clip_tmp=$(mktemp 2>/dev/null || true)
        if [ -n "$clip_tmp" ]; then
            if ! timeout 2 wl-paste --no-newline --type "$clip_type" >"$clip_tmp" 2>/dev/null; then
                rm -f "$clip_tmp"
                clip_tmp=""
                clip_type=""
            fi
        else
            clip_type=""
        fi
    fi
fi

restore_clipboard() {
    if [ -n "$clip_tmp" ] && [ -s "$clip_tmp" ]; then
        # No --trim-newline: the saved bytes are the selection verbatim.
        timeout 2 wl-copy --type "$clip_type" <"$clip_tmp" >/dev/null 2>&1 || true
    fi
    [ -n "$clip_tmp" ] && rm -f "$clip_tmp"
    clip_tmp=""
}
trap restore_clipboard EXIT

# --- capture each window --------------------------------------------------
status=0
# Cards are small: shrinking here keeps the cache and the decode size down.
shrink() {
    command -v magick >/dev/null 2>&1 || return 0
    magick "$1" -resize '800x800>' -strip "$1.tmp" 2>/dev/null || return 0
    if [ -s "$1.tmp" ]; then
        mv -f "$1.tmp" "$1"
    else
        rm -f "$1.tmp"
    fi
}

for id in "$@"; do
    case $id in
        '' | *[!0-9]*) continue ;;
    esac

    out="$dir/$id.png"
    rm -f "$out"

    if ! timeout 5 niri msg action screenshot-window --id "$id" --path "$out" --write-to-disk true >/dev/null 2>&1; then
        status=1
        continue
    fi

    # The action answers before the PNG lands on disk.
    for _ in $(seq 1 40); do
        [ -s "$out" ] && break
        sleep 0.03
    done

    if [ -s "$out" ]; then
        shrink "$out"
        printf '%s\n' "$id"
    else
        rm -f "$out"
        status=1
    fi
done

# Thumbnails are re-captured on demand; keep the cache bounded.
find "$dir" -maxdepth 1 -name '*.png' -mmin +30 -delete 2>/dev/null

exit $status
