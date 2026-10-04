pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// The dock's state: settings (shell.json › dock), the pinned apps and the
// items shown — pinned apps in their order, then whatever else is running,
// so an app appears as soon as it opens. Settings are written through
// Config, so hand edits to shell.json apply live too.
Singleton {
    id: root

    readonly property var cfg: Config.data.dock || Config.defaults.dock
    // shown/position: your choice (Menu › Appearance › Dock) when you made one,
    // else the theme's (colors.toml dock = "left" | "off" | …), else bottom
    readonly property bool enabled: cfg.enabled === true || cfg.enabled === false ? cfg.enabled : Theme.themeDock !== "off"
    // always · autohide (show when the cursor reaches the edge) ·
    // intellihide (hide only while a window would sit under it)
    readonly property string mode: ["always", "autohide", "intellihide"].indexOf(cfg.mode) !== -1 ? cfg.mode : "intellihide"
    readonly property string position: ["bottom", "left", "right", "top"].indexOf(cfg.position) !== -1 ? cfg.position
        : ["bottom", "left", "right", "top"].indexOf(Theme.themeDock) !== -1 ? Theme.themeDock : "bottom"
    readonly property bool vertical: position === "left" || position === "right"
    readonly property bool transparent: !!cfg.transparent
    readonly property int iconSize: (cfg.iconSize >= 24 && cfg.iconSize <= 72) ? cfg.iconSize : 40
    readonly property var pinned: Array.isArray(cfg.pinned) ? cfg.pinned : []

    function set(key, value) { Config.set("dock." + key, value) }

    // desktop entry for a pinned id or a window's app id: the id itself, then
    // the app's StartupWMClass (com.anthropic.Claude), then Quickshell's guess
    function entryFor(id) {
        if (!id) return null
        const e = DesktopEntries.byId(id)
        if (e) return e
        const low = id.toLowerCase()
        for (const a of DesktopEntries.applications.values)
            if ((a.startupClass || "").toLowerCase() === low || a.id.toLowerCase() === low) return a
        return DesktopEntries.heuristicLookup(id) || null
    }
    function keyFor(entry, appId) { return entry ? entry.id : (appId || "") }

    function isPinned(id) { return pinned.indexOf(id) !== -1 }
    function pin(id) { if (id && !isPinned(id)) set("pinned", pinned.concat([id])) }
    function unpin(id) { set("pinned", pinned.filter(p => p !== id)) }
    function togglePin(id) { if (isPinned(id)) unpin(id); else pin(id) }

    // [{ key, entry, windows: [Toplevel] }] — pinned first, then running
    readonly property var items: {
        void DesktopEntries.applications.values   // rebuild once the app list (re)loads
        const out = [], at = {}
        for (const id of pinned) {
            const e = entryFor(id)
            if (!e) continue                 // not installed here: skip quietly
            const k = keyFor(e, id)
            if (at[k] !== undefined) continue
            at[k] = out.length
            out.push({ key: k, entry: e, windows: [] })
        }
        for (const t of ToplevelManager.toplevels.values) {
            if (!t.appId) continue
            const e = entryFor(t.appId)
            const k = keyFor(e, t.appId)
            if (at[k] === undefined) { at[k] = out.length; out.push({ key: k, entry: e, windows: [] }) }
            out[at[k]].windows.push(t)
        }
        return out
    }

    // click: launch, focus, or cycle through the app's windows
    function activate(item) {
        const w = item.windows
        if (w.length === 0) { launch(item); return }
        const cur = w.findIndex(t => t.activated)
        w[(cur + 1) % w.length].activate()
    }
    // look the entry up again: the one cached in `items` can be a stale
    // object after Quickshell re-reads the desktop files
    function launch(item) {
        const e = entryFor(item.key)
        if (e && typeof e.execute === "function") e.execute()
        else if (item.entry) Quickshell.execDetached(["gtk-launch", item.key])
        else if (item.key) Quickshell.execDetached(["sh", "-c", item.key])
    }
    function closeAll(item) { for (const t of item.windows) t.close() }

    IpcHandler {
        target: "dock"
        function toggle(): bool { root.set("enabled", !root.enabled); return !root.enabled }
        // always | autohide | intellihide
        function mode(m: string): string { if (["always", "autohide", "intellihide"].indexOf(m) !== -1) root.set("mode", m); return root.mode }
        function position(p: string): string { if (["bottom", "left", "right", "top"].indexOf(p) !== -1) root.set("position", p); return root.position }
        function transparent(): bool { root.set("transparent", !root.transparent); return !root.transparent }
        function size(px: int): int { root.set("iconSize", Math.max(24, Math.min(72, px))); return root.iconSize }
        // desktop id (e.g. "firefox", "org.gnome.Nautilus"), toggles
        function pin(id: string): bool { const e = root.entryFor(id); root.togglePin(e ? e.id : id); return root.isPinned(e ? e.id : id) }
        function pinned(): string { return root.pinned.join(" ") }
    }
}
