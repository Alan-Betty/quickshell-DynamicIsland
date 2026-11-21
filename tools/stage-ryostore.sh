#!/usr/bin/env bash
# Stage the Ryostore items into a local Ryostore checkout and validate them.
#
#   tools/stage-ryostore.sh ~/path/to/ryostore
#
# Copies ryostore/<catalogue>/<id> into the checkout, adds or refreshes each
# item's registry.json entry, regenerates its manifest with the store's own
# packer, then runs the catalogue check and the security screen.
# It never commits, pushes or opens a pull request.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
store="${1:-}"
if [ -z "$store" ] || [ ! -f "$store/tools/pack-product.py" ]; then
    echo "usage: tools/stage-ryostore.sh <ryostore checkout>" >&2
    exit 2
fi
store="$(cd "$store" && pwd)"

"$root/tools/sync.sh" --check

items=(
    "barstyles/dynamic-island"
    "notifications/island"
    "launchers/island"
    "osds/island"
)

for item in "${items[@]}"; do
    rm -rf "${store:?}/$item"
    mkdir -p "$store/$item"
    cp -r "$root/ryostore/$item/." "$store/$item/"
    find "$store/$item" -name '__pycache__' -prune -exec rm -rf {} +
done

python3 - "$store" <<'PY'
import json, sys, datetime, pathlib
store = pathlib.Path(sys.argv[1])
today = datetime.date.today().isoformat()
up = "https://github.com/Alan-Betty/quickshell-DynamicIsland"

entries = {
    "barstyles": {
        "id": "dynamic-island",
        "name": "Dynamic Island",
        "version": "4.0.0",
        "path": "barstyles/dynamic-island",
        "author": "Alan Betty",
        "upstream": up,
        "summary": "A black island with liquid-glass controls",
        "description": "A black island at the top of the screen that grows for live activities (music, timers, recording), opens into a dashboard with Home, Media, Controls and Timer tabs, draws the banners and the Notification Center over the shell's daemon, morphs into a Spotlight-style launcher, and keeps the system tray and its menus inside the island. Every control on it is refracting liquid glass.",
        "tags": ["top", "island", "subshell", "liquid-glass", "notifications", "launcher", "media", "tray"],
        "accent": "#0a84ff",
        "surface": "#000000",
        "preview": "assets/preview.webp",
        "screenshots": [],
        "manifest": "manifest.json",
        "manifestSha256": "",
        "lastUpdated": today,
        "official": False,
        "license": "MIT",
    },
    "notifications": {
        "id": "island",
        "name": "Island",
        "version": "1.0.0",
        "path": "notifications/island",
        "author": "Alan Betty",
        "upstream": up + "/tree/main/ryostore/notifications/island",
        "summary": "The Dynamic Island's notification card",
        "description": "A black card with the app icon or the sender's picture, the summary, body and time, and liquid glass only where your hand goes: a close bead on hover and glass action pills. Urgent notifications carry a Time Sensitive line and a red halo; timed cards drain a hairline along the foot.",
        "tags": ["black", "island", "liquid-glass"],
        "accent": "#0a84ff",
        "surface": "#000000",
        "preview": "assets/preview.webp",
        "screenshots": [],
        "manifest": "manifest.json",
        "manifestSha256": "",
        "lastUpdated": today,
        "official": False,
        "license": "MIT",
    },
    "launchers": {
        "id": "island",
        "name": "Island",
        "version": "1.0.0",
        "path": "launchers/island",
        "author": "Alan Betty",
        "upstream": up + "/tree/main/ryostore/launchers/island",
        "summary": "A pill that stretches into a search field",
        "description": "Super+Space drops a black pill from the top edge that stretches into a search field. Apps you open most rise to the top, sums are answered as you type, and > runs a command (Ctrl+Enter in a terminal). The selected row is a gliding slab of liquid glass.",
        "tags": ["spotlight", "island", "liquid-glass"],
        "accent": "#0a84ff",
        "surface": "#000000",
        "preview": "assets/preview.webp",
        "screenshots": [],
        "manifest": "manifest.json",
        "manifestSha256": "",
        "lastUpdated": today,
        "official": False,
        "license": "MIT",
    },
    "osds": {
        "id": "island",
        "name": "Island",
        "version": "1.0.0",
        "path": "osds/island",
        "author": "Alan Betty",
        "upstream": up + "/tree/main/ryostore/osds/island",
        "summary": "A black pill that springs from the top edge",
        "description": "Volume, microphone, brightness and keyboard changes spring out from the top edge as a black pill, the glyph in a well of liquid glass and the level as a white bar that greys out when muted; past full volume the overflow shows in your accent.",
        "tags": ["island", "top", "liquid-glass"],
        "accent": "#0a84ff",
        "surface": "#000000",
        "preview": "assets/preview.webp",
        "screenshots": [],
        "manifest": "manifest.json",
        "manifestSha256": "",
        "lastUpdated": today,
        "official": False,
        "license": "MIT",
    },
}

for cat, entry in entries.items():
    reg_path = store / cat / "registry.json"
    reg = json.loads(reg_path.read_text())
    items = reg[cat]
    for i, old in enumerate(items):
        if old.get("id") == entry["id"]:
            # keep anything the store added that this script doesn't manage
            merged = dict(old)
            merged.update(entry)
            items[i] = merged
            break
    else:
        items.append(entry)
    reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n")
    print(f"registry: {cat}/{entry['id']} {entry['version']}")
PY

cd "$store"
for item in "${items[@]}"; do
    python3 tools/pack-product.py "$item"
done

echo
echo "== catalogue check"
tests/validate-catalogue.sh
echo
echo "== security screen"
python3 tools/security-screen.py --root . --format text || true
