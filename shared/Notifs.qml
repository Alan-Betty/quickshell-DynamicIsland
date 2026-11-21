pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Apple-style notification daemon: banners, grouping, Notification Center, Focus.
Singleton {
    id: root

    // ═══════════════════════ CENTER / FOCUS ══════════════════════
    property bool centerOpen: false
    property string centerScreen: ""
    property bool replying: false       // an inline-reply field has focus
    property bool hovering: false       // a banner is hovered → pause timers
    property bool bannerExpanded: false // a banner was pulled down / opened → keep it

    function toggleCenter(screenName) {
        if (centerOpen) { centerOpen = false; return; }
        Hub.expanded = false;
        centerScreen = screenName || Hub.focusedScreen();
        centerOpen = true;
    }
    readonly property bool dnd: Config.s.dnd
    function toggleDnd() {
        Config.s.dnd = !Config.s.dnd;
        Hub.flash("osd", Config.s.dnd ? "bedtime" : "bedtime_off", Config.s.dnd ? "Do Not Disturb" : "Focus Off",
                  -1, Config.s.dnd ? Theme.indigo : null, 1800);
    }

    // ═══════════════════════ DAEMON TAKEOVER ═════════════════════
    // Stops other notification daemons so this one can own org.freedesktop.Notifications.
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

    // Who currently owns the notification bus name?
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

    // ═════════════════════════ SERVER ════════════════════════════
    property var times: ({})
    LazyLoader {
        id: loader
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
            onNotification: n => root.receive(n)
        }
    }
    readonly property var server: loader.item
    readonly property var list: server ? server.trackedNotifications.values : []
    readonly property int count: list.length

    function receive(n) {
        const t = Object.assign({}, times);
        t[n.id] = Date.now();
        times = t;
        n.tracked = true;
        const critical = n.urgency === NotificationUrgency.Critical;
        const silenced = dnd && !(critical && Config.s.dndAllowCritical);
        if (silenced) { if (n.transient) n.expire(); return; }
        pushPopup(n, critical);
        if (Config.s.notifSound) {
            const h = n.hints || {};
            if (!h["suppress-sound"]) {
                const f = h["sound-file"] || Config.s.soundFile;
                if (f) Quickshell.execDetached(["paplay", f]);
            }
        }
    }

    // ═════════════════════════ BANNERS ═══════════════════════════
    property var popups: []         // newest first
    property var expiry: ({})
    property real holdStart: 0
    readonly property bool hold: hovering || replying || bannerExpanded

    function pushPopup(n, sticky) {
        popups = [n].concat(popups.filter(p => p && p !== n)).slice(0, 5);
        const e = Object.assign({}, expiry);
        e[n.id] = sticky ? Number.MAX_SAFE_INTEGER : Date.now() + Math.max(2, Config.s.bannerTimeout) * 1000;
        expiry = e;
    }
    function removePopup(n) {
        popups = popups.filter(p => p && p !== n);
        if (n && n.transient) n.expire();
    }
    function clearPopups() { const ps = popups; popups = []; ps.forEach(p => { if (p && p.transient) p.expire(); }); }
    onHoldChanged: {
        if (hold) { holdStart = Date.now(); return; }
        const d = Date.now() - holdStart;
        const e = Object.assign({}, expiry);
        for (const k in e) if (e[k] < Number.MAX_SAFE_INTEGER) e[k] += d;
        expiry = e;
    }
    Timer {
        interval: 200; repeat: true
        running: root.popups.length > 0 && !root.hold
        onTriggered: {
            const now = Date.now();
            const keep = [], drop = [];
            for (let i = 0; i < root.popups.length; i++) {
                const p = root.popups[i];
                if (!p) continue;
                (root.expiry[p.id] > now ? keep : drop).push(p);
            }
            if (drop.length) {
                root.popups = keep;
                drop.forEach(p => { if (p.transient) p.expire(); });
            }
        }
    }
    Connections {
        target: root.server ? root.server.trackedNotifications : null
        // Only prune banners whose notification was actually closed. Deferred and read
        // straight from the model: this signal fires before `list` re-evaluates, and
        // pruning against the stale list used to drop every brand-new banner instantly.
        function onValuesChanged() { Qt.callLater(root.prunePopups); }
    }
    function prunePopups() {
        const l = server ? server.trackedNotifications.values : [];
        const next = popups.filter(p => p && l.indexOf(p) >= 0);
        if (next.length !== popups.length) popups = next;
    }
    onCenterOpenChanged: if (centerOpen) clearPopups()

    // ═════════════════════════ GROUPS ════════════════════════════
    readonly property var groups: {
        const t = times, m = {}, order = [];
        const l = list;
        for (let i = 0; i < l.length; i++) {
            const n = l[i];
            if (n.transient) continue;
            const key = Config.s.groupByApp ? (n.appName || n.desktopEntry || "Notifications") : ("#" + n.id);
            if (!m[key]) { m[key] = { key: key, app: n.appName || "Notifications", items: [], latest: 0 }; order.push(m[key]); }
            m[key].items.push(n);
            m[key].latest = Math.max(m[key].latest, t[n.id] || 0);
        }
        for (let i = 0; i < order.length; i++) order[i].items.sort((a, b) => (t[b.id] || 0) - (t[a.id] || 0));
        order.sort((a, b) => b.latest - a.latest);
        return order;
    }
    readonly property int visibleCount: { let c = 0; for (let i = 0; i < groups.length; i++) c += groups[i].items.length; return c; }

    // ═════════════════════════ HELPERS ═══════════════════════════
    function resolveIcon(s) {
        if (!s) return "";
        if (s.startsWith("/")) return "file://" + s;
        if (s.startsWith("file:") || s.startsWith("image:") || s.startsWith("qrc:") || s.startsWith("http")) return s;
        return Quickshell.iconPath(s, true);
    }
    function appIcon(n) {
        if (!n) return "";
        return resolveIcon(n.appIcon) || resolveIcon(n.desktopEntry) || resolveIcon((n.appName || "").toLowerCase().replace(/ /g, "-"));
    }
    function image(n) { return n ? resolveIcon(n.image) : ""; }
    function title(n) { return !n ? "" : (n.summary || n.appName || "Notification"); }
    function body(n) {
        if (!n) return "";
        if (Config.s.previews === "never") return "Notification";
        return (n.body || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'");
    }
    function critical(n) { return n !== null && n !== undefined && n.urgency === NotificationUrgency.Critical; }
    // iOS wording: now · 4m ago · 2h ago · 09:41 · Yesterday · Tuesday · 12/03/26
    function age(n) {
        const t = n ? times[n.id] : undefined;
        if (!t) return "now";
        const now = Hub.now;
        const d = Math.floor((now.getTime() - t) / 60000);
        if (d < 1) return "now";
        if (d < 60) return d + "m ago";
        if (d < 240) return Math.floor(d / 60) + "h ago";
        const then = new Date(t);
        const day0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        if (t >= day0) return Hub.fmtClock(then, false, true);
        if (t >= day0 - 86400000) return "Yesterday";
        if (t >= day0 - 6 * 86400000) return Qt.locale().dayName(then.getDay(), Locale.LongFormat);
        return Qt.formatDate(then, Locale.ShortFormat);
    }
    // a messaging-style notification (contact picture + small app badge)
    function isMessage(n) {
        if (!n) return false;
        const h = n.hints || {};
        const cat = String(h.category || "");
        return cat.startsWith("im") || /telegram|signal|whatsapp|discord|slack|messages|element|vesktop|webcord|teams|thunderbird|mail|evolution|geary/i.test(n.appName || "");
    }
    function buttons(n) {
        if (!n) return [];
        const out = [], a = n.actions;
        for (let i = 0; i < a.length; i++) if (a[i].identifier !== "default" && a[i].text !== "") out.push(a[i]);
        return out;
    }
    function activate(n) {
        if (!n) return;
        const a = n.actions;
        for (let i = 0; i < a.length; i++)
            if (a[i].identifier === "default") { a[i].invoke(); removePopup(n); return; }
        // no default action → open the Notification Center
        removePopup(n);
        if (!centerOpen) toggleCenter("");
    }
    function dismiss(n) { if (n) { removePopup(n); n.dismiss(); } }
    // swipe a banner away: it goes quietly to the Notification Center (like iOS)
    function hide(n) { if (n) { popups = popups.filter(p => p && p !== n); bannerExpanded = false; if (n.transient) n.expire(); } }
    function clearGroup(g) { const it = g.items.slice(); for (let i = 0; i < it.length; i++) it[i].dismiss(); }
    function clearAll() {
        const it = list.slice();
        popups = [];
        for (let i = 0; i < it.length; i++) it[i].dismiss();
    }
    function test() {
        Quickshell.execDetached(["notify-send", "-a", "Island", "-i", "preferences-desktop-notification",
                                 "Hello from Island", "This is what your notifications look like now."]);
    }
}
