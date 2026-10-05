pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Services

// The menu (SUPER+SPACE): a tree defined as data in
// ~/.config/orrery/menu.jsonc (+ menu.local.jsonc overlay, merged by id),
// searched flat from anywhere. Live ✓ state comes from the shell itself
// (theme, bar, caffeine, dnd) and from `orrery-menu-data`, which also supplies
// the dynamic rows (agents, keybindings, packages, reminders, about) — one
// process per open. Rendered by Menu/Menu.qml.
Singleton {
    id: root
    readonly property string dir: Quickshell.env("HOME") + "/.config/orrery/"

    property bool open: false
    property string path: ""            // current submenu id ("" = root)
    property string query: ""
    property var inputRow: null         // a row with "input": the search box is its argument
    property var entries: ({})
    property var data: ({ state: {} })
    property int selected: 0

    // ---- files -----------------------------------------------------------
    function strip(text) { return text.split("\n").filter(l => !/^\s*\/\//.test(l)).join("\n") }
    // ids from before the menu was regrouped, so an older menu.local.jsonc
    // still overrides the entry it meant (longest prefix wins)
    readonly property var oldIds: [
        ["style.bar.pill", "appearance.bar.style.pill"], ["style.bar.floating", "appearance.bar.style.floating"],
        ["style.bar.minimal", "appearance.bar.style.minimal"], ["style.bar.top", "appearance.bar.position.top"],
        ["style.bar.bottom", "appearance.bar.position.bottom"], ["style.bar.left", "appearance.bar.position.left"],
        ["style.bar.right", "appearance.bar.position.right"], ["style.dock.always", "appearance.dock.behaviour.always"],
        ["style.dock.intellihide", "appearance.dock.behaviour.intellihide"], ["style.dock.autohide", "appearance.dock.behaviour.autohide"],
        ["style.dock.bottom", "appearance.dock.position.bottom"], ["style.dock.left", "appearance.dock.position.left"],
        ["style.dock.right", "appearance.dock.position.right"], ["style.dock.top", "appearance.dock.position.top"],
        ["toggle.battery", "appearance.bar.battery"], ["setup.defaults", "settings.defaults"],
        ["setup.wifi", "devices.wifi"], ["setup.bluetooth", "devices.bluetooth"], ["setup.audio", "devices.audio"],
        ["setup.power", "devices.power"], ["setup.monitors", "devices.monitors"], ["setup.input", "devices.input"],
        ["setup", "settings"], ["style", "appearance"], ["system", "power"]
    ]
    function renamed(id) {
        for (const [a, b] of oldIds) if (id === a || id.indexOf(a + ".") === 0) return b + id.slice(a.length)
        return id
    }
    function load() {
        let base = {}, local = {}
        try { base = JSON.parse(strip(baseFile.text())) } catch (e) { console.warn("Menu: menu.jsonc: " + e) }
        try { if (localFile.text()) local = JSON.parse(strip(localFile.text())) } catch (e) { console.warn("Menu: menu.local.jsonc: " + e) }
        for (const k0 in local) {
            const k = renamed(k0)
            base[k] = Object.assign({}, base[k] || {}, local[k0])
        }
        entries = base
    }
    FileView { id: baseFile;  path: root.dir + "menu.jsonc";       watchChanges: true; onFileChanged: reload(); onLoaded: root.load() }
    FileView { id: localFile; path: root.dir + "menu.local.jsonc"; printErrors: false; watchChanges: true; onFileChanged: reload(); onLoaded: root.load(); onLoadFailed: {} }

    Process {
        id: fetch
        command: [Quickshell.env("HOME") + "/.local/bin/orrery-menu-data"]
        stdout: StdioCollector { onStreamFinished: { try { root.data = JSON.parse(text) } catch (e) { console.warn("Menu: data: " + e) } } }
    }
    function refresh() { fetch.running = true }

    // ---- state -----------------------------------------------------------
    readonly property var laptop: UPower.displayDevice && UPower.displayDevice.isLaptopBattery
    function state(key) {
        if (!key) return true
        if (key[0] === "!") return !state(key.slice(1))
        const eq = key.indexOf(":")
        if (eq > 0) return String(state(key.slice(0, eq))) === key.slice(eq + 1)
        switch (key) {
        case "theme":     return Theme.name
        case "light":     return Theme.light
        case "wallpaper": return (data.state && data.state.wallpaper) || ""
        case "walltheme": return WallTheme.on
        case "bar.pill":  return Theme.barStyle === "pill"
        case "bar.floating": return Theme.barStyle === "floating"
        case "bar.minimal": return Theme.barStyle === "minimal"
        case "bar.style":   return ({ pill: "Legacy", floating: "Floating", minimal: "Minimal" })[Theme.barStyle] || ""
        case "bar.position": return Config.position.charAt(0).toUpperCase() + Config.position.slice(1)
        case "dock.positionLabel": return Dock.position.charAt(0).toUpperCase() + Dock.position.slice(1)
        case "dock.modeLabel": return ({ always: "Always visible", intellihide: "Hide when covered", autohide: "Auto-hide" })[Dock.mode] || ""
        case "bar.top": case "bar.bottom": case "bar.left": case "bar.right": return Config.position === key.slice(4)
        case "bar.transparent": return Config.transparent
        case "bar.hidden":      return Config.hidden
        case "bar.battery":     return Config.batteryPercent
        case "dock":             return Dock.enabled
        case "dock.mode":        return Dock.mode
        case "dock.position":    return Dock.position
        case "dock.transparent": return Dock.transparent
        case "caffeine": return Caffeine.on
        case "dnd":      return Notifs.dnd
        case "laptop":   return !!laptop
        default:
            if (key.indexOf("widget.") === 0) return root.widgetOn(key.slice(7))
            const st = data.state || {}
            return key in st ? st[key] : false
        }
    }
    // rebinds rows when live state changes
    readonly property var tick: [Theme.name, Theme.barStyle, Config.position, Config.transparent, Config.hidden, Config.batteryPercent, Caffeine.on, Notifs.dnd, Dock.cfg, data]

    // ---- rows ------------------------------------------------------------
    readonly property var widgetIds: ["clock", "workspaces", "tray", "audio", "network", "bluetooth", "battery", "caffeine", "bell", "activewindow", "media", "sysmon", "netspeed", "nightlight", "keyboard", "agents"]
    function layoutAll() { const s = Theme.barLayout; return ["left", "center", "right"].map(sec => Config.layoutFor(s, sec)) }
    function widgetOn(id) { return layoutAll().some(l => l.indexOf(id) !== -1) }
    function toggleWidget(id) {
        const s = Theme.barLayout
        for (const sec of ["left", "center", "right"]) {
            const l = Config.layoutFor(s, sec).slice()
            const i = l.indexOf(id)
            if (i !== -1) { l.splice(i, 1); Config.set("bar.layout." + s + "." + sec, l); return }
        }
        // back where the default layout has it, so turning a widget off and
        // on never reshuffles the bar. While the section still follows the
        // default order it is rebuilt from the default (spacers included);
        // a hand-reordered one gets it after its nearest shown neighbour.
        const d = Config.defaults.bar.layout[s] || {}
        let sec = "right"
        for (const k of ["left", "center", "right"]) if ((d[k] || []).indexOf(id) !== -1) sec = k
        const def = d[sec] || []
        let l = Config.layoutFor(s, sec).slice()
        const real = x => x !== "spacer"
        const shown = l.filter(real), order = def.filter(x => real(x) && shown.indexOf(x) !== -1)
        if (def.indexOf(id) !== -1 && shown.join() === order.join()) {
            l = def.filter(x => !real(x) || x === id || shown.indexOf(x) !== -1)
        } else {
            const at = def.indexOf(id)
            let pos = -1
            for (let j = at - 1; j >= 0 && pos === -1; j--) { const q = real(def[j]) ? l.indexOf(def[j]) : -1; if (q !== -1) pos = q + 1 }
            for (let j = at + 1; at !== -1 && j < def.length && pos === -1; j++) { const q = real(def[j]) ? l.indexOf(def[j]) : -1; if (q !== -1) pos = q }
            if (pos === -1) pos = l.indexOf("bell") !== -1 ? l.indexOf("bell") : l.length
            l.splice(pos, 0, id)
        }
        Config.set("bar.layout." + s + "." + sec, l)
    }


    function row(id, e, crumb) {
        return { id: id, icon: e.icon || "", label: e.label || id.split(".").pop(), description: e.description || "",
                 action: e.action || "", keep: !!e.keep, input: e.input || "", provider: e.provider || "",
                 sub: !e.action && !e.input && (!!e.provider || hasChildren(id)),
                 checked: e.checked ? !!state(e.checked) : null, value: e.value ? String(state(e.value)) : "",
                 crumb: crumb || "" }
    }
    function hasChildren(id) { for (const k in entries) if (k.indexOf(id + ".") === 0 && k.slice(id.length + 1).indexOf(".") === -1) return true; return false }
    function childrenOf(id) {
        void tick
        const out = []
        for (const k in entries) {
            const parent = k.indexOf(".") === -1 ? "" : k.slice(0, k.lastIndexOf("."))
            if (parent !== id) continue
            const e = entries[k]
            if (e.when && !state(e.when)) continue
            out.push(row(k, e, ""))
        }
        return out
    }
    function providerRows(name) {
        void tick
        if (name === "widgets") return widgetIds.map(w => ({ id: "widget." + w, icon: "widgets", label: w, description: "", action: "", keep: true,
                                                              input: "", provider: "", sub: false, checked: widgetOn(w), value: "", crumb: "", internal: "widget" }))
        if (name === "dock.pins") return Apps.all.slice()   // pinned first, in dock order, then A–Z
                                        .sort((a, b) => ((Dock.isPinned(a.id) ? Dock.pinned.indexOf(a.id) : 1e4) - (Dock.isPinned(b.id) ? Dock.pinned.indexOf(b.id) : 1e4))
                                                        || a.name.localeCompare(b.name))
                                        .map(a => ({ id: "dockpin." + a.id, icon: "push_pin", label: a.name, description: "", action: "", keep: true,
                                                     input: "", provider: "", sub: false, checked: Dock.isPinned(a.id), value: "", crumb: "", internal: "dockpin" }))
        if (name === "agents.default") return (data.agents || []).map(a => ({ id: "agent." + a.id, icon: a.icon, label: a.label, description: "", action: "orrery-agent default " + a.id,
                                                                            keep: true, input: "", provider: "", sub: false, checked: a.checked, value: "", crumb: "" }))
        return (data[name] || []).map(r => ({ id: name + "." + r.id, icon: r.icon || "", label: r.label, description: r.description || "", action: r.action || "",
                                              keep: !!r.keep, input: "", provider: "", sub: false,
                                              checked: r.checked === undefined ? null : r.checked, value: r.value || "", crumb: "" }))
    }
    function crumbFor(id) {
        const parts = id.split("."), out = []
        for (let i = 1; i < parts.length; i++) { const p = parts.slice(0, i).join("."); out.push(entries[p] ? entries[p].label : p) }
        return out.join(" › ")
    }
    function search(q) {
        void tick
        const words = q.toLowerCase().split(/\s+/).filter(w => w)
        const out = []
        const consider = (r, crumb) => {
            const hay = (r.label + " " + r.description + " " + crumb + " " + r.id.split(".").pop()).toLowerCase()
            let score = 0
            for (const w of words) {
                if (r.label.toLowerCase().indexOf(w) === 0) score += 3
                else if (r.label.toLowerCase().indexOf(w) !== -1) score += 2
                else if (hay.indexOf(w) !== -1) score += 1
                else return
            }
            r.crumb = crumb; r.score = score; out.push(r)
        }
        for (const k in entries) {
            const e = entries[k]
            if (e.when && !state(e.when)) continue
            const r = row(k, e, "")
            if (r.sub && !e.provider) continue            // only leaves; submenus are reached via their rows
            consider(r, crumbFor(k))
            if (e.provider && e.provider !== "widgets" && e.provider !== "dock.pins") for (const pr of providerRows(e.provider)) consider(pr, crumbFor(k + ".x"))
        }
        out.sort((a, b) => b.score - a.score)
        return out.slice(0, 40)
    }
    readonly property var rows: {
        void tick
        if (inputRow) return []
        if (query !== "") return search(query)
        const e = entries[path]
        if (e && e.provider) return providerRows(e.provider)
        return childrenOf(path)
    }
    onRowsChanged: if (selected >= rows.length) selected = Math.max(0, rows.length - 1)
    readonly property string crumb: inputRow ? inputRow.label : path === "" ? "Menu" : crumbFor(path + ".x")
    readonly property string placeholder: inputRow ? inputRow.input : "Search"

    // ---- actions ---------------------------------------------------------
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
    function activate(r) {
        if (!r) return
        if (r.internal === "widget") { toggleWidget(r.id.slice(7)); return }
        if (r.internal === "dockpin") { Dock.togglePin(r.id.slice(8)); return }
        if (r.input) { inputRow = r; query = ""; return }
        if (r.sub) { path = r.id; query = ""; selected = 0; return }
        if (!r.action) return
        run(r.action)
        if (r.keep) later.restart(); else close()
    }
    function submitInput(text) {
        if (!inputRow || !text.trim()) return
        run(inputRow.action.replace("{}", "'" + text.replace(/'/g, "'\\''") + "'"))
        close()
    }
    Timer { id: later; interval: 350; onTriggered: root.refresh() }
    function up() {
        if (inputRow) { inputRow = null; return }
        if (query !== "") { query = ""; return }
        if (path === "") { close(); return }
        path = path.indexOf(".") === -1 ? "" : path.slice(0, path.lastIndexOf("."))
        selected = 0
    }
    function show(section) {
        const e = section ? entries[section] : null
        query = ""; inputRow = null; selected = 0
        if (e && e.input) {            // an input row: open its parent with the box as the argument
            path = section.indexOf(".") === -1 ? "" : section.slice(0, section.lastIndexOf("."))
            inputRow = row(section, e, "")
        } else path = e ? section : ""
        refresh(); open = true
    }
    function close() { open = false; inputRow = null; query = "" }
    function toggle(section) { if (open) close(); else show(section) }

    IpcHandler {
        target: "menu"
        function toggle(): void { root.toggle("") }
        function open(section: string): void { if (root.open && root.path === section) root.close(); else root.show(section) }
        function close(): void { root.close() }
        function search(q: string): void { root.show(""); root.query = q }
        // run one entry by id without opening the menu (keybinds, scripts): `qs ipc call menu run toggle.caffeine`
        // show/hide a bar widget (the Widgets page does the same)
        function widget(id: string): bool { root.toggleWidget(id); return root.widgetOn(id) }
        function run(id: string): string {
            const e = root.entries[id]
            if (!e) return "unknown: " + id
            if (e.action) { root.run(e.action); return e.action }
            root.show(id); return "opened"
        }
    }
}
