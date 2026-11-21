//@ pragma UseQApplication
import QtQuick
import Quickshell

// Dynamic Island, standalone build. Runs next to whatever bar you use:
//   qs -c island            (this folder linked to ~/.config/quickshell/island)
//   qs -p /path/to/standalone
ShellRoot {
    Variants {
        model: Quickshell.screens
        IslandWindow {}
    }

    LazyLoader {
        active: Hub.settingsOpen
        SettingsWindow {}
    }

    // touch the singletons so the services start immediately
    Component.onCompleted: { Platform.kind; Hub.armed; Notifs.count; Theme.accent; }
}
