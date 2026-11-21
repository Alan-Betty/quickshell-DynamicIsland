pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent settings. Edited live from the Settings app (SUPER+, or the gear),
// stored in ~/.config/quickshell/island/settings.json. You can also hand-edit the
// JSON; changes are picked up instantly.
Singleton {
    id: root

    readonly property string dir: String(Quickshell.shellDir || "").replace(/^file:\/\//, "").replace(/\/$/, "") || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/island")
    readonly property string iconFont: "Material Symbols Rounded"

    property alias s: adapter
    property bool resetting: false

    function reset() {
        resetting = true;
        Quickshell.execDetached(["sh", "-c", "rm -f '" + dir + "/settings.json'"]);
        resetTimer.start();
    }
    Timer { id: resetTimer; interval: 300; onTriggered: Quickshell.reload(true) }

    FileView {
        id: file
        path: root.dir + "/settings.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onAdapterUpdated: if (!root.resetting) writeAdapter()
        onLoadFailed: err => {
            // first run → write defaults
            if (!root.resetting) writeAdapter();
        }

        JsonAdapter {
            id: adapter

            // ── Appearance ──
            property string style: "glass"          // glass | black
            property string appearance: "auto"      // auto | dark | light
            property real glassOpacity: 0.55        // tint strength behind the blur
            property bool glassRim: true            // liquid-glass specular edge
            property bool glassAccentTint: true     // mix a hint of the accent into the glass
            property bool glow: true
            property string accentSource: "auto"    // auto | wallpaper | wal | matugen | hyprland | gtk | album | custom
            property string customAccent: "#0a84ff"
            property string matugenPath: "~/.cache/matugen/colors.json"
            property string wallpaperPath: ""       // empty = detect (swww, hyprpaper, swaybg, waypaper…)
            property bool albumTint: true           // tint island with album colour while music plays
            property string font: "auto"            // auto = SF Pro if installed, else Inter

            // ── Island ──
            property bool overlayBar: true
            property bool reserveSpace: true        // push maximized/tiled windows below the island (bar-like)
            property int topMargin: 6
            property string motion: "balanced"      // gentle | balanced | bouncy | reduced
            property bool use24h: false
            property bool showAmPm: false
            property bool showSeconds: false
            property bool showBattery: true
            property bool showPrivacy: true
            property bool workspaceFlash: true
            property bool splitActivities: true     // iOS-style second bubble
            property string activityClock: "split"  // split | inline | hidden — the time while music/timers run
            property bool hoverPeek: true
            property int hoverDelay: 260

            // ── Media ──
            property bool visualizer: true
            property bool trackChangePeek: true
            property bool spinArt: true

            // ── Notifications ──
            property bool notifications: true
            property bool takeover: true            // stop mako/dunst/swaync on start
            property string notifStyle: "banner"    // banner | island | corner
            property int bannerTimeout: 5
            property string previews: "always"      // always | never
            property bool notifSound: true
            property string soundFile: "/usr/share/sounds/freedesktop/stereo/message.oga"
            property bool groupByApp: true
            property bool dnd: false
            property bool dndAllowCritical: true

            // ── Weather + location ──
            property bool weather: true
            property string locationMode: "auto"    // auto (GeoClue → IP) | ip | manual
            property real manualLat: 0
            property real manualLon: 0
            property string manualName: ""
            property string units: "metric"         // metric | imperial

            // ── Controls ──
            property bool ccAccent: true            // Control Center toggles use your theme accent
            property int nightLightTemp: 4000
            property int osdTimeout: 1600
            property bool confirmPower: true
        }
    }
}
