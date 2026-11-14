pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// "Starting Firefox…": feedback between launching an app and its window
// appearing, shown in the OSD box (Osd/OsdWindow.qml). The launcher and the
// dock report launches here; keybinds go through `orrery-launch <command>`
// (IPC `launching command`). A launch ends when a window of that app opens
// or an existing one is focused (single-instance apps); a window nobody
// claims ends the oldest launch (a terminal app opens in kitty, a wrapper
// script's app has another class). Fast apps never show it: the box waits
// `delay` ms, and once shown stays `minShown` ms so it does not flash.
// Off with shell.json › launch.feedback = false (Menu › Quick toggles).
Singleton {
    id: root

    readonly property bool enabled: !(Config.data.launch && Config.data.launch.feedback === false)
    function toggle() { Config.set("launch.feedback", !enabled) }

    readonly property int delay: 400        // ms before the box appears
    readonly property int minShown: 600     // ms it stays once it appeared
    readonly property int timeout: 25000    // give up quietly (no window ever came)
    readonly property int timeoutRunning: 5000   // the app already had a window: it may only reuse it

    // [{ name, icon, keys: [lowercase class guesses], at: ms, until: ms }]
    property var pending: []
    readonly property var current: pending.length ? pending[pending.length - 1] : null
    property bool shown: false              // the delay has passed for the current launch
    property bool holding: false            // inside minShown after the last launch ended
    property var last: null                 // what the box shows while holding
    readonly property bool visible: enabled && ((current !== null && shown) || holding)
    readonly property var showing: current || last
    readonly property string name: showing ? showing.name : ""
    readonly property string icon: showing ? showing.icon : ""
    readonly property int more: Math.max(0, pending.length - 1)
    // the window is there: the box shows "Opened <app>" for its last moment
    readonly property bool done: holding && current === null

    // ---- reporting a launch -----------------------------------------------
    function base(s) { return String(s || "").split("/").pop().toLowerCase() }
    function keysFor(entry) {
        const k = []
        const add = (s) => { s = String(s || "").toLowerCase(); if (s && k.indexOf(s) === -1) k.push(s) }
        add(entry.id); add(entry.id.split(".").pop())          // org.gnome.Nautilus → nautilus
        add(entry.startupClass)
        const cmd = entry.command || []
        // flatpak run org.x.App / env FOO=1 app: the first word that is the app
        for (const w of cmd) { const b = base(w); if (b && ["env", "flatpak", "run", "sh", "bash", "-c"].indexOf(b) === -1 && b.indexOf("=") === -1 && b[0] !== "-") { add(b); break } }
        add(entry.name)
        return k
    }
    function alreadyRunning(keys) {
        for (const t of ToplevelManager.toplevels.values) if (t.appId && matches(t.appId, keys)) return true
        return false
    }
    function start(name, icon, keys) {
        if (!enabled || !name) return
        const now = Date.now()
        const running = alreadyRunning(keys)
        pending = pending.concat([{ name: name, icon: icon || "", keys: keys,
                                    at: now, until: now + (running ? timeoutRunning : timeout) }])
        // another launch while the box is up keeps it up (now naming the new app)
        if (holding) shown = true
        else if (!shown) appear.restart()
    }
    function forEntry(entry) { if (entry) start(entry.name, entry.icon, keysFor(entry)) }
    // a command line from a keybind: name and icon from its desktop entry when there is one
    function forCommand(cmd) {
        const words = String(cmd || "").trim().split(/\s+/)
        const b = base(words[0])
        if (!b) return
        // the desktop id, then the entry that runs it, then one whose icon,
        // window class or id it is named after (zen-browser runs zen-bin from
        // zen.desktop, Icon=zen-browser), and Quickshell's guess last
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
        const tests = [
            a => a.command && a.command.length && base(a.command[0]) === b,
            a => String(a.icon || "").toLowerCase() === b,
            a => String(a.startupClass || "").toLowerCase() === b,
            a => b.indexOf(a.id.toLowerCase() + "-") === 0
        ]
        let e = DesktopEntries.byId(b)
        for (let i = 0; !e && i < tests.length; i++) e = apps.find(tests[i]) || null
        if (!e) e = DesktopEntries.heuristicLookup(b)
        if (e) { const k = keysFor(e); if (k.indexOf(b) === -1) k.push(b); start(e.name, e.icon, k) }
        else start(b.charAt(0).toUpperCase() + b.slice(1), "", [b])
    }

    // ---- ending one -------------------------------------------------------
    function matches(cls, keys) {
        const c = String(cls || "").toLowerCase()
        if (!c) return false
        for (const k of keys) {
            if (c === k || c.endsWith("." + k) || k.endsWith("." + c)) return true
            if (k.length >= 4 && (c.indexOf(k) !== -1 || k.indexOf(c) !== -1) && c.length >= 3) return true
        }
        return false
    }
    function finish(i) {
        if (i < 0 || i >= pending.length) return
        const p = pending.slice()
        const done = p.splice(i, 1)[0]
        if (shown && p.length === 0) { last = done; holding = true; hold.restart() }
        pending = p
        if (p.length === 0) { shown = false; appear.stop() }
    }
    function windowOpened(cls, claimAny) {
        if (!pending.length) return
        for (let i = pending.length - 1; i >= 0; i--)
            if (matches(cls, pending[i].keys)) { finish(i); return }
        if (claimAny) finish(0)
    }

    Connections {
        target: Hyprland
        enabled: root.pending.length > 0
        // openwindow>>ADDR,WORKSPACE,CLASS,TITLE · activewindow>>CLASS,TITLE
        function onRawEvent(e) {
            if (e.name === "openwindow") root.windowOpened(e.data.split(",")[2], true)
            else if (e.name === "activewindow") root.windowOpened(e.data.split(",")[0], false)
        }
    }
    Timer { id: appear; interval: root.delay; onTriggered: if (root.pending.length) root.shown = true }
    Timer { id: hold; interval: root.minShown; onTriggered: root.holding = false }
    Timer {
        id: prune
        interval: 1000; repeat: true
        running: root.pending.length > 0
        onTriggered: {
            const now = Date.now()
            const keep = root.pending.filter(p => p.until > now)
            if (keep.length !== root.pending.length) {
                root.pending = keep
                if (!keep.length) { root.shown = false; root.holding = false }   // gave up: just go
            }
        }
    }

    IpcHandler {
        target: "launching"
        // orrery-launch: the command line about to be started
        function command(cmd: string): void { root.forCommand(cmd) }
        // a desktop id (firefox, org.gnome.Nautilus)
        function app(id: string): void { root.forEntry(DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)) }
        function clear(): void { root.pending = []; root.shown = false; root.holding = false }
        function toggle(): bool { root.toggle(); return !root.enabled }
        function status(): string { return root.pending.map(p => p.name).join(", ") || (root.done ? "opened " + root.name : "idle") }
    }
}
