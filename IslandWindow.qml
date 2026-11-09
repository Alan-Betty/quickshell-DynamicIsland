import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

// One transparent full-screen overlay per screen holding the island, its bubbles,
// banners and the Notification Center. Only those items take input (mask).
PanelWindow {
    id: win
    required property ShellScreen modelData
    screen: modelData
    readonly property string screenName: screen ? screen.name : ""
    readonly property bool focusedHere: !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === screenName

    // Hide everything while this monitor's workspace has a fullscreen window
    // (videos, games). Opening the island (Super+I) or the Notification Center
    // still works and brings it back until it is closed again.
    readonly property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(screen)
    readonly property bool fullscreenHere: !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)
    readonly property bool hiddenForFullscreen: fullscreenHere && !island.isExpanded && !island.isLauncher && !centerShown
    visible: !hiddenForFullscreen

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    // the island itself always floats; space is reserved by `reserver` below
    exclusionMode: (Config.s.overlayBar || Config.s.reserveSpace) ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"

    readonly property bool centerShown: Notifs.centerOpen && Notifs.centerScreen === screenName
    readonly property bool interactive: island.isExpanded || island.isLauncher || centerShown || Notifs.replying || banners.hovered

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:island"
    WlrLayershell.keyboardFocus: interactive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: island
        Region { item: island.bubble }
        Region { item: island.clockBubble }
        Region { item: banners.visible ? banners : null }
        Region { item: scrim.visible ? scrim : null }
    }

    // ── Reserve a strip at the top (like a bar) so windows tile below the island ──
    // Invisible, takes no input. Zone = island bottom + 6px − (frame edge + gaps_out),
    // because Hyprland already adds gaps_out on top of the reserved area.
    property int gapsTop: 18
    Process {
        id: gapsProc
        running: true
        command: ["hyprctl", "getoption", "general:gaps_out", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    const v = parseInt(String(j.css !== undefined ? j.css : j.int).trim().split(/\s+/)[0]);
                    if (!isNaN(v)) win.gapsTop = v;
                } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") gapsProc.running = true; }
    }
    PanelWindow {
        id: reserver
        screen: win.screen
        visible: Config.s.reserveSpace
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: Math.max(0, Config.s.topMargin + 38 + 6 - win.gapsTop)
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:island-reserve"
    }

    HyprlandFocusGrab {
        windows: [win]
        active: island.isExpanded || island.isLauncher || win.centerShown
        onCleared: { Hub.expanded = false; Notifs.centerOpen = false; Hub.launcherOpen = false; }
    }

    // ── Notification Center backdrop: dims + (via the blur layerrule) frosts the desktop ──
    Rectangle {
        id: scrim
        anchors.fill: parent
        z: 1
        // above the 0.35 ignore_alpha threshold → Hyprland blurs the whole screen behind it
        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.46) : Qt.rgba(0.08, 0.08, 0.1, 0.40)
        opacity: win.centerShown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.reduced ? 1 : 220; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: Notifs.centerOpen = false }
    }

    NotificationCenter {
        id: center
        z: 2
        shown: win.centerShown
        screenName: win.screenName
        maxHeight: win.height - y - 16
        x: Math.round((win.width - width) / 2)
        y: Config.s.topMargin + 52
    }

    // Banners sit *under* the island so they appear to drop out of it
    BannerStack {
        id: banners
        z: 5
        active: Config.s.notifStyle !== "island" && win.focusedHere && !win.centerShown
        readonly property bool corner: Config.s.notifStyle === "corner"
        width: corner ? 370 : 400
        x: corner ? win.width - width - 14 : Math.round((win.width - width) / 2)
        y: corner ? (Config.s.overlayBar ? 48 : 10) : island.y + island.height + 10
        originY: corner ? 0 : -(island.height + 10)
        Behavior on y { enabled: !banners.corner; SpringAnimation { spring: Theme.spring; damping: Math.min(1, Theme.damping + 0.15) } }
    }

    Island {
        id: island
        z: 10
        screenName: win.screenName
        x: Math.round((win.width - width) / 2)
        y: Config.s.topMargin
    }
}
