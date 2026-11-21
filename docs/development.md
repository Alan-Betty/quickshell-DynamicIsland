# Development

## The layout

```
shared/        the island: every QML file both builds use, and the glass shader
standalone/    shell.qml, Platform.qml, qmldir, plus synced copies of shared/
ryostore/
  barstyles/dynamic-island/   Scene.qml, Platform.qml, ShellShortcut.qml, plus synced copies
  notifications/island/       Card.qml, plus GlassControl and the shader
  launchers/island/           Main.qml, Preview.qml, plus GlassControl and the shader
  osds/island/                Osd.qml, plus GlassControl and the shader
tools/
  sync.sh               copy shared/ into every package, write each qmldir
  build-shaders.sh      compile shared/shaders/*.frag to .qsb
  stage-ryostore.sh     copy the store items into a Ryostore checkout and validate
```

Edit in `shared/` or in a package's own files, never in a synced copy. Store items have to be self-contained folders, so the copies are real files and are committed. `tools/sync.sh --check` fails if any copy has drifted.

## The platform seam

Everything that depends on the compositor or the desktop sits behind one singleton, `Platform`, with a file per build:

| | `standalone/Platform.qml` | `ryostore/barstyles/dynamic-island/Platform.qml` |
|---|---|---|
| Focused output, fullscreen, workspaces | `Quickshell.Hyprland` | `Wm` facade |
| Notifications | its own `NotificationServer`, with takeover | wraps `shell.services` `Notifs` |
| Do Not Disturb | `settings.json` | the shell's Focus |
| Night Shift, Caffeine | `hyprsunset`, `systemd-inhibit` | `Nightlight`, `Flags.keepAwake` |
| Session, screenshot, recording | `ryoku-shell` or systemd, `grim`, `pgrep` | `SessionActions`, `Capture`, `Recorder` |
| Launching | `DesktopEntry.execute()` | `AppLaunch.run()` |
| Shortcuts | `GlobalShortcut` | `ShellShortcut` (the global-shortcut protocol) |
| Accent | Hyprland border colour, last | Ryoku palette, first |
| Settings file | `standalone/settings.json` | `~/.config/ryoku/dynamic-island/settings.json` |

Both files expose the same members. Shared code only ever says `Platform.something`. Adding a capability means adding it to both files.

## The shared singletons

- **Hub**: live state (media, audio, battery, Bluetooth, Wi-Fi, weather, timers, the tray) and the IPC handler.
- **Notifs**: banners, expiry, holds, grouping and the Notification Center.
- **Theme**: palette, accent sources, fonts, motion.
- **Config**: settings. `Config.base` is the single list of defaults, and a platform can override entries through `Platform.configDefaults`.

## Keeping it light

Work that only matters when something is on screen asks for it. `Demand { kind: "viz"; active: visible }` keeps cava running only while a visualizer is visible, and `kind: "position"` does the same for the media position tick. Timers that poll the system are tied to the tab that shows their data. When you add something that polls, gate it the same way.

## Running the standalone build from the checkout

```bash
qs -p standalone
```

To try it next to another island without it taking over notifications, write a `standalone/settings.json` first:

```json
{ "notifications": false, "takeover": false, "reserveSpace": false, "topMargin": 60 }
```

`settings.json` and `launcher-history.json` are ignored by git.

## Releasing

1. Bump `Config.version` in `shared/Config.qml` and the `VERSION` file.
2. Add a section to `CHANGELOG.md`.
3. `tools/build-shaders.sh` if the shader changed, then `tools/sync.sh`.
4. For Ryostore, bump each changed item's version and run `tools/stage-ryostore.sh` (see `docs/ryostore.md`).
