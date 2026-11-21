#!/usr/bin/env bash
# Compile the GLSL sources in shared/shaders to Qt shader packs (.qsb).
# Needs qsb from qt6-shadertools. Run tools/sync.sh afterwards to copy the
# results into every package.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
qsb="$(command -v qsb || true)"
[ -z "$qsb" ] && [ -x /usr/lib/qt6/bin/qsb ] && qsb=/usr/lib/qt6/bin/qsb
if [ -z "$qsb" ]; then
    echo "qsb not found: install qt6-shadertools" >&2
    exit 1
fi

for src in "$root"/shared/shaders/*.frag "$root"/shared/shaders/*.vert; do
    [ -e "$src" ] || continue
    "$qsb" --qt6 -o "$src.qsb" "$src"
    echo "built ${src#"$root"/}.qsb"
done
