# Dynamic Island on Ryostore

Ryostore is the catalogue behind Ryoku's in-desktop store. Each top-level folder is its own catalogue, each item is one self-contained folder listed in that catalogue's `registry.json`, and every item must keep to the store's rules: no window manager in the code, no files reached outside its own folder, every command and network host declared.

The island isn't one kind of thing, so it ships as four items.

| Item | Catalogue | Folder here | Entry point | Picked in |
|---|---|---|---|---|
| Dynamic Island | `barstyles/` | `ryostore/barstyles/dynamic-island` | `Scene.qml` | Settings → Bar |
| Island | `notifications/` | `ryostore/notifications/island` | `Card.qml` | Settings → Overlays |
| Island | `launchers/` | `ryostore/launchers/island` | `Main.qml` | Settings → App Launcher |
| Island | `osds/` | `ryostore/osds/island` | `Osd.qml` | Settings → Overlays |

## Why these four

**The bar style is the island.** It needs its own surfaces (the island, banners, the Notification Center, the Settings window), its own shortcuts and its own take on the launcher and notifications. A bar style is the store's slot for that. Strictly it's a subshell: a coordinated set of surfaces rather than just a bar. The store activates subshells through the bar style machinery and reviews them with the subshell form.

**The other three are the parts people ask for on their own.** Someone happy with their bar can still want the island's notification card, its launcher or its volume pill. Each fits an existing Ryoku host contract exactly:

- a notification design draws one card; the shell keeps the server, timers, history and Do Not Disturb;
- a launcher is a `Scope` with `show`, `hide` and `shown`; it launches through `AppLaunch`;
- an OSD design draws the values it's given; the shell keeps the window and the timing.

The live activities, the dashboard and the tray have no standalone host contract, so they stay in the bar style. A plugin was the other candidate, but plugins can't import the shell's services, own a top-centre overlay, or take over notifications, so a plugin version would lose most of what makes the island the island.

## What each item depends on

| Item | Imports | Runs | Network |
|---|---|---|---|
| Bar style | Quickshell, `shell.services`, `Ryoku.Ui.Singletons` | `nmcli`, `brightnessctl`, `cava`, `paplay`, `wl-copy`, `hyprpicker` (optional), `curl` for weather | Open-Meteo, ipinfo.io / ipapi.co, BigDataCloud, only when Weather is on (off by default) |
| Notification card | Quickshell, `shell.services`, `Ryoku.Ui.Singletons` | nothing | none |
| Launcher | Quickshell, `shell.services`, `Ryoku.Ui.Singletons` | the app or command you choose; `wl-copy` for maths | none |
| OSD | `Ryoku.Ui.Singletons` | nothing | none |

All four carry `GlassControl.qml` and its shader (`shaders/liquidglass.frag` and the compiled `.qsb`). The `.qsb` is a Qt shader pack, not an executable. The GLSL source sits next to it so it can be reviewed.

None of them call a compositor. Workspaces, the focused output and fullscreen state come from the `Wm` facade, session actions from `SessionActions`, recording from `Recorder`, Night Shift from `Nightlight`, and screenshots from `Capture`.

## Submitting

The store's own guides are the reference: `CONTRIBUTING.md`, `DEVELOP.md` and each catalogue's `AUTHORING.md` in the Ryostore repository. `tools/stage-ryostore.sh` does the mechanical part against a local Ryostore checkout:

```bash
tools/sync.sh --check                    # every copy matches shared/
tools/stage-ryostore.sh ~/Documents/GitHub/ryostore
```

It copies the four folders in, writes or updates their `registry.json` entries, regenerates each manifest with `tools/pack-product.py`, and runs `tests/validate-catalogue.sh` and the security screen. It doesn't commit, push or open a pull request.

Before submitting:

1. Point the store at the checkout and install each item from it (`DEVELOP.md`, "Test the whole store against your local copy").
2. Work through each catalogue's checklist: Super+Space on two outputs, notifications with and without images and actions, every OSD kind, and the bar style's activation, disable and reactivation.
3. Bump the version in the registry entry for any item you changed. Installed copies only update when the version moves.
4. Open the pull request. Use the subshell form for the bar style.

Community items are maintained by their author. When Ryoku changes, the items here need updating from this repository, then restaging.
