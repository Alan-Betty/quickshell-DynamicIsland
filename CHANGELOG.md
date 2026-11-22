# Changelog

## Unreleased

- New: `extras/ryoku/dynamic-island.service` starts the standalone build with a Ryoku session and lets it own notifications ahead of the Ryoku shell. See "The standalone build on Ryoku" in the README.
- Fixed: liquid glass over album art sampled the artwork with a zero size, so the controls on the Media tab and media peek didn't refract it.
- Fixed: a USB camera plugged in after the island started never lit the privacy indicator. The camera check now runs every time the island looks for camera use.
- Fixed: with many tray apps and a high Icons in the Header setting, the tray beads drew over the Home tab and took its clicks. Beads that don't fit now go behind the "+N" bead.
- Fixed: the launcher's maths answered `-2^2` with 4 instead of -4, and read a malformed number like `1.2.3` as 1.2 instead of giving no answer.
- Fixed: reopening the Ryostore launcher during its close animation kept the old search text while the results reset, so Enter could launch an unrelated app.
- Fixed: on Ryoku, notifications that were already there when you switched to the island showed "now" in the Notification Center forever. They now show when they really arrived.
- Fixed: a banner that arrived while another was hovered or being replied to stayed up longer than its timeout once the hold ended.

## 4.0.0

The island is black now, and the glass moved to the controls on it.

### Look

- The island, its bubbles, banners and the Notification Center are solid black surfaces with a faint hairline edge, like the hardware.
- Liquid glass is a fragment shader on the controls: Control Center toggles, power buttons, the tab switcher thumb, the play button, header buttons, tray beads, the switch knob while you hold it, notification buttons and the launcher's selection. Each one refracts what is under it through a curved rim, frosts it and catches a specular highlight. The old translucent surface tint is gone.
- New Appearance settings: Liquid Glass (on or off) and Glass Strength. The Material, Glass Tint, Specular Rim, Accent Tint and light/dark Appearance options are retired; the island is always dark.
- Album art behind the Media tab and the media peek is darker, so the island still reads as black.

### System tray

- Tray menus open inside the island instead of as separate popups, with submenus, check and radio items, and a back button. A menu can no longer be left floating, and opening one no longer collapses the island.
- Clicking a tray icon no longer collapses the island.
- A full tray sheet lists every tray app as a tile. Open it from the header, with `quickshell:islandTray`, or with `ipc call island tray`.
- `ipc call island trayMenu <app>` opens one app's menu directly.
- Settings → Island → System Tray sets how many icons sit in the header.

### Notifications

- Fixed: urgent notifications never went away. They now stay for Urgent Duration (12 s by default) and then tuck into the Notification Center. Keep Urgent Banners restores the old behaviour.
- Fixed: banners could stop expiring altogether after a banner disappeared while the pointer was on it, or while its reply field had focus. Hover, reply and expand holds are now released when their banner goes away, and no hold outlives two minutes.
- An app's own expire timeout is honoured, capped at a minute.
- Send Urgent Test in Settings → Notifications.

### Performance

- The clock ticks once a minute unless seconds are shown.
- The visualizer runs only while one is on screen, and cava runs at 30 fps instead of 60.
- The media position updates only while a scrubber is visible.
- Microphone-in-use comes from the Pipewire graph instead of polling `pactl` every three seconds. The camera probe runs only on machines that have a camera.
- System stats poll only while the Home tab is open, and network state only while Controls is open.
- The wallpaper probe runs only when the wallpaper is actually the accent source.
- The old glass surface rendered several offscreen layers per surface. The black surface is one rectangle and one shadow.
- Spinning album art is off by default. It kept the GPU awake for as long as music played.

### Structure

- The repository is split into `shared/` (the island), `standalone/` (the Hyprland build) and `ryostore/` (the Ryostore items). Everything compositor-specific is in one `Platform.qml` per build.
- The click-away is compositor-neutral, so the standalone build no longer needs a Hyprland focus grab.
- The launcher's maths no longer uses `Function()`.
- New Ryostore items: the Island notification card, the Island launcher and the Island on-screen display.

### Upgrading

Remove the old clone from `~/.config/quickshell/island` and link `standalone/` there instead (see the README). Copy `settings.json` across if you want to keep your settings; options that no longer exist are ignored.

## 3.0

The release before the split: liquid-glass surfaces, the launcher, the Notification Center with grouped stacks and inline reply, and the Settings window.
