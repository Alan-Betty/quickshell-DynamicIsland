pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Standalone build: everything the island needs from the desktop, on Hyprland.
//
// This is the only file that knows which compositor is running. The Ryoku
// bar style ships its own Platform.qml with the same members, backed by the
// Ryoku shell's services, and every other file is shared between the two.
Singleton {
    id: root

    readonly property string kind: "standalone"
    readonly property string buildLabel: "Standalone (Hyprland)"
    readonly property string configDir: String(Quickshell.shellDir || "").replace(/^file:\/\//, "").replace(/\/$/, "")
        || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/island")
    readonly property var configDefaults: ({})
    readonly property bool canReload: true
    function reload() { Quickshell.reload(true); }

    // ═══════════════════════ OUTPUTS + WORKSPACES ════════════════
    readonly property string focusedOutput: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    function outputHasFullscreen(name) {
        const ms = Hyprland.monitors.values;
        for (let i = 0; i < ms.length; i++)
            if (ms[i].name === name) return !!(ms[i].activeWorkspace && ms[i].activeWorkspace.hasFullscreen);
        return false;
    }
    readonly property int wsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property var occupied: Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id)

    // Outer gaps, so the reserved strip lines windows up under the island.
    property int outerGaps: Config.s.outerGaps
    Process {
        id: gapsProc
        running: true
        command: ["hyprctl", "getoption", "general:gaps_out", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    const v = parseInt(String(j.css !== undefined ? j.css : j.int).trim().split(/\s+/)[0]);
                    if (!isNaN(v)) root.outerGaps = v;
                } catch (e) {}
            }
        }
    }

    // ═════════════════════════ ACCENT ════════════════════════════
    // Hyprland's active border colour, as the last automatic accent source.
    property string accent: ""
    readonly property string accentLabel: "Hyprland border"
    readonly property bool accentFirst: false
    readonly property string wallpaperProbe: "hyprctl hyprpaper listactive 2>/dev/null | grep '=' | head -1 | sed -E 's/^[^=]*= *//'"
    Process {
        id: borderProc
        running: true
        command: ["hyprctl", "-j", "getoption", "general:col.active_border"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    const m = String(j.custom || j.str || "").match(/[0-9a-fA-F]{8}/);
                    root.accent = m ? "#" + m[0].slice(2) : "";
                } catch (e) { root.accent = ""; }
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "configreloaded") return;
            borderProc.running = true;
            gapsProc.running = true;
        }
    }

    // ═══════════════════════ NOTIFICATIONS ═══════════════════════
    // The island is the notification daemon here. On start it stops the
    // usual ones so it can own org.freedesktop.Notifications.
    readonly property bool ownsDaemon: true
    property bool ready: false
    property bool serverOn: true
    readonly property string killCmd:
        "for d in mako dunst swaync fnott xfce4-notifyd notify-osd mate-notification-daemon; do pkill -x \"$d\"; done; " +
        "systemctl --user stop mako.service dunst.service swaync.service fnott.service 2>/dev/null; sleep 0.5; true"
    Process {
        id: takeoverProc
        command: ["sh", "-c", root.killCmd]
        onExited: { root.ready = true; ownerCheck.restart(); }
    }
    Component.onCompleted: {
        if (Config.s.notifications && Config.s.takeover) takeoverProc.running = true;
        else { ready = true; ownerCheck.restart(); }
    }
    function takeOver() {
        serverOn = false;
        takeoverProc.running = true;
        restartTimer.start();
    }
    Timer { id: restartTimer; interval: 900; onTriggered: { root.serverOn = true; ownerCheck.restart(); } }

    property string ownerStatus: "unknown"   // ours | other | none | unknown
    property string ownerName: ""
    property int ownerPid: 0
    Process {
        id: ownerProc
        command: ["sh", "-c", "busctl --user status org.freedesktop.Notifications 2>/dev/null | grep -E '^(PID|Comm)='"]
        stdout: StdioCollector {
            onStreamFinished: {
                let pid = 0, comm = "";
                const ls = this.text.split("\n");
                for (let i = 0; i < ls.length; i++) {
                    if (ls[i].startsWith("PID=")) pid = parseInt(ls[i].slice(4)) || 0;
                    else if (ls[i].startsWith("Comm=")) comm = ls[i].slice(5).trim();
                }
                root.ownerPid = pid;
                root.ownerName = comm;
                root.ownerStatus = pid === 0 ? "none" : pid === Quickshell.processId ? "ours" : "other";
            }
        }
    }
    Timer { id: ownerCheck; interval: 1500; onTriggered: ownerProc.running = true }
    Timer { interval: 8000; repeat: true; running: Hub.settingsOpen; onTriggered: ownerProc.running = true }
    function checkOwner() { ownerProc.running = true; }

    LazyLoader {
        id: serverLoader
        active: Config.s.notifications && root.ready && root.serverOn
        NotificationServer {
            keepOnReload: false
            actionsSupported: true
            actionIconsSupported: false
            bodySupported: true
            bodyMarkupSupported: false
            bodyHyperlinksSupported: false
            imageSupported: true
            persistenceSupported: true
            inlineReplySupported: true
            onNotification: n => { n.tracked = true; Notifs.receive(n); }
        }
    }
    readonly property var notifList: serverLoader.item ? serverLoader.item.trackedNotifications.values : []
    readonly property bool dnd: Config.s.dnd
    function setDnd(on) { Config.s.dnd = on; }

    // ═════════════════════ SCREEN RECORDING ══════════════════════
    property bool recording: false
    Process {
        id: recProc
        command: ["pgrep", "-x", "wf-recorder|wl-screenrec|gpu-screen-recorder|obs|kooha"]
        onExited: code => root.recording = code === 0
    }
    Timer { interval: 4000; repeat: true; triggeredOnStart: true; running: true; onTriggered: recProc.running = true }
    function stopRecording() {
        Quickshell.execDetached(["sh", "-c",
            "pkill -INT -x wf-recorder; pkill -INT -x wl-screenrec; pkill -INT -f gpu-screen-recorder; true"]);
        recKick.start();
    }
    Timer { id: recKick; interval: 800; onTriggered: recProc.running = true }

    // ═══════════════════════ QUICK TOGGLES ═══════════════════════
    property bool caffeine: false
    function setCaffeine(on) { caffeine = on; }
    Process {
        running: root.caffeine
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=Island", "--why=Caffeine", "--mode=block", "sleep", "infinity"]
    }

    // Night Shift: hyprsunset, restarted whenever the temperature changes
    property bool nightLight: false
    function setNightLight(on) { nightLight = on; }
    Process {
        id: sunset
        running: root.nightLight
        command: ["hyprsunset", "-t", String(Config.s.nightLightTemp)]
    }
    Connections {
        target: Config.s
        function onNightLightTempChanged() { if (root.nightLight) { sunset.running = false; sunsetRestart.restart(); } }
    }
    Timer { id: sunsetRestart; interval: 250; onTriggered: sunset.running = root.nightLight }

    // ═══════════════════════ SESSION + TOOLS ═════════════════════
    // Ryoku's ryoku-shell when it is installed, plain systemd otherwise.
    function session(action) {
        const cmds = {
            lock: "command -v ryoku-shell >/dev/null && exec ryoku-shell lock; exec loginctl lock-session",
            suspend: "command -v ryoku-shell >/dev/null && exec ryoku-shell suspend; exec systemctl suspend",
            logout: "exec hyprctl dispatch exit",
            reboot: "exec systemctl reboot",
            shutdown: "exec systemctl poweroff"
        };
        if (cmds[action]) Quickshell.execDetached(["sh", "-c", cmds[action]]);
    }
    function screenshot() {
        Quickshell.execDetached(["sh", "-c",
            "sleep 0.4; g=$(slurp) || exit 0; grim -g \"$g\" - | wl-copy && notify-send -a Screenshot -i camera-photo 'Screenshot' 'Copied to clipboard'"]);
    }
    function colorPick() { Quickshell.execDetached(["sh", "-c", "sleep 0.4; exec hyprpicker -a"]); }

    // ═════════════════════════ LAUNCHING ═════════════════════════
    function terminalArgv(cmd) {
        return ["sh", "-c", "if command -v xdg-terminal-exec >/dev/null; then exec xdg-terminal-exec sh -c \"$1; exec $SHELL\"; " +
                "elif command -v kitty >/dev/null; then exec kitty sh -c \"$1; exec $SHELL\"; " +
                "else exec ${TERMINAL:-foot} sh -c \"$1; exec $SHELL\"; fi", "sh", cmd];
    }
    function launch(entry) {
        if (!entry) return;
        if (entry.runInTerminal) Quickshell.execDetached(terminalArgv(entry.execString.replace(/%[fFuUdDnNickvm]/g, "").trim()));
        else entry.execute();
    }
    function runCommand(cmd, inTerminal) {
        if (inTerminal) Quickshell.execDetached(terminalArgv(cmd));
        else Quickshell.execDetached(["sh", "-c", cmd]);
    }
    function copyText(text) { Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", text]); }

    readonly property var extraDeps: [
        { cmd: "bluetoothctl", pkg: "bluez-utils", what: "Bluetooth (with the bluetooth service running)" },
        { cmd: "hyprsunset", pkg: "hyprsunset", what: "Night Shift" },
        { cmd: "grim", pkg: "grim", what: "Screenshot" },
        { cmd: "slurp", pkg: "slurp", what: "Screenshot region" },
        { cmd: "wl-copy", pkg: "wl-clipboard", what: "Copy screenshots and maths results" },
        { cmd: "hyprpicker", pkg: "hyprpicker", what: "Colour picker" },
        { cmd: "notify-send", pkg: "libnotify", what: "Test notification" }
    ]
    readonly property string bluetoothHint: "Start it with: sudo systemctl enable --now bluetooth"

    // ═══════════════════════ GLOBAL SHORTCUTS ════════════════════
    // Bind in hyprland.conf: bind = SUPER, space, global, quickshell:islandLauncher
    readonly property var shortcuts: [
        { name: "islandLauncher", what: "App launcher" },
        { name: "islandToggle", what: "Open / close the island" },
        { name: "islandCenter", what: "Notification Center" },
        { name: "islandTray", what: "System tray" },
        { name: "islandSettings", what: "Settings" }
    ]
    readonly property string shortcutHint: "Add to hyprland.conf as: bind = MODS, KEY, global, quickshell:<name>"
    GlobalShortcut { name: "islandLauncher"; description: "App launcher in the island"; onPressed: Hub.toggleLauncher() }
    GlobalShortcut { name: "islandToggle"; description: "Toggle the dynamic island"; onPressed: Hub.toggle("") }
    GlobalShortcut { name: "islandCenter"; description: "Notification Center"; onPressed: Notifs.toggleCenter("") }
    GlobalShortcut { name: "islandTray"; description: "System tray in the island"; onPressed: Hub.trayView !== "" ? Hub.collapse() : Hub.openTrayList("") }
    GlobalShortcut { name: "islandSettings"; description: "Island settings"; onPressed: Hub.openSettings() }
}
