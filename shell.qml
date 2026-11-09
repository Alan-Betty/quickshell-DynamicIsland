//@ pragma UseQApplication
import QtQuick
import Quickshell

// Dynamic Island — standalone Quickshell instance that runs next to your bar.
//   qs -c island
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
    Component.onCompleted: { Hub.armed; Notifs.ready; Theme.dark; }
}
