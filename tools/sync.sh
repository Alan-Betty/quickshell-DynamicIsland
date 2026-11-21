#!/usr/bin/env bash
# Copy the shared island source into every package that carries it, and
# write each package's qmldir.
#
#   tools/sync.sh           copy
#   tools/sync.sh --check   exit 1 if any copy has drifted from shared/
#
# shared/ is the only place to edit these files. Store packages must be
# self-contained folders, so the copies are real files, committed with the
# rest; this script keeps them identical.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
check=0
[ "${1:-}" = "--check" ] && check=1
drift=0

singletons="Config Hub Notifs Theme Platform"

# full island targets: everything in shared/, plus a qmldir
island_targets=(
    "standalone"
    "ryostore/barstyles/dynamic-island"
)
# small store packages: only the glass control and its shader
glass_targets=(
    "ryostore/notifications/island"
    "ryostore/launchers/island"
    "ryostore/osds/island"
)

copy() {   # copy <src> <dst>
    local src="$1" dst="$2"
    if [ "$check" = 1 ]; then
        if ! cmp -s "$src" "$dst"; then
            echo "drift: ${dst#"$root"/}"
            drift=1
        fi
    else
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
    fi
}

qmldir_for() {   # qmldir_for <dir>
    local dir="$1"
    {
        for f in "$dir"/*.qml; do
            local name
            name="$(basename "$f" .qml)"
            [ "$name" = "shell" ] && continue
            if [[ " $singletons " == *" $name "* ]]; then
                echo "singleton $name 1.0 $name.qml"
            else
                echo "$name 1.0 $name.qml"
            fi
        done
    } | sort
}

for t in "${island_targets[@]}"; do
    dir="$root/$t"
    [ -d "$dir" ] || continue
    for f in "$root"/shared/*.qml; do
        copy "$f" "$dir/$(basename "$f")"
    done
    for f in "$root"/shared/shaders/*.qsb "$root"/shared/shaders/*.frag; do
        copy "$f" "$dir/shaders/$(basename "$f")"
    done
    if [ "$check" = 1 ]; then
        if ! diff -q <(qmldir_for "$dir") "$dir/qmldir" >/dev/null 2>&1; then
            echo "drift: $t/qmldir"
            drift=1
        fi
    else
        qmldir_for "$dir" > "$dir/qmldir"
    fi
done

for t in "${glass_targets[@]}"; do
    dir="$root/$t"
    [ -d "$dir" ] || continue
    copy "$root/shared/GlassControl.qml" "$dir/GlassControl.qml"
    for f in "$root"/shared/shaders/*.qsb "$root"/shared/shaders/*.frag; do
        copy "$f" "$dir/shaders/$(basename "$f")"
    done
done

if [ "$check" = 1 ]; then
    [ "$drift" = 0 ] && echo "in sync" || { echo "run tools/sync.sh"; exit 1; }
else
    echo "synced"
fi
