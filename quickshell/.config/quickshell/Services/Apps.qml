pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Application launcher state: the desktop entries, a fuzzy filter, and a
// launch history so what you use floats up (like rofi's drun sorting).
Singleton {
    id: root
    property bool open: false
    property string query: ""
    property var history: ({})          // desktop id -> launch count
    readonly property string histFile: Quickshell.env("HOME") + "/.local/state/orrery/launcher.json"

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    readonly property var results: {
        const q = query.trim().toLowerCase()
        const score = (e) => {
            const n = (e.name || "").toLowerCase(), g = (e.genericName || "").toLowerCase(), c = (e.comment || "").toLowerCase()
            if (q === "") return 1
            if (n.startsWith(q)) return 100
            if (n.indexOf(q) !== -1) return 60
            if (n.split(/\s+/).some(w => w.startsWith(q))) return 50
            if (g.indexOf(q) !== -1 || c.indexOf(q) !== -1) return 20
            // subsequence match
            let i = 0; for (const ch of n) if (ch === q[i]) i++
            return i === q.length ? 10 : 0
        }
        return all.map(e => ({ e: e, s: score(e), h: history[e.id] || 0 }))
                  .filter(x => x.s > 0)
                  .sort((a, b) => (b.s - a.s) || (b.h - a.h) || a.e.name.localeCompare(b.e.name))
                  .map(x => x.e)
    }

    function launch(entry) {
        if (!entry) return
        history[entry.id] = (history[entry.id] || 0) + 1
        history = Object.assign({}, history)
        hist.setText(JSON.stringify(history))
        Launching.forEntry(entry)
        entry.execute()
        open = false
    }
    function toggle() { query = ""; open = !open }

    function seedFromRofi() {
        // first run: start from rofi's drun history so the order carries over
        let t = ""
        try { t = rofiCache.text() } catch (e) { return }
        const h = {}
        for (const line of t.split("\n")) {
            const m = line.match(/^(\d+)\s+(.+)\.desktop$/)
            if (m) h[m[2]] = parseInt(m[1])
        }
        if (Object.keys(h).length === 0) return
        history = h
        hist.setText(JSON.stringify(h))
    }
    FileView {
        id: hist
        path: root.histFile
        onLoaded: { try { root.history = JSON.parse(text()) } catch (e) {} }
        onLoadFailed: seed.start()
    }
    FileView { id: rofiCache; path: Quickshell.env("HOME") + "/.cache/rofi3.druncache"; onLoadFailed: {} }
    Timer { id: seed; interval: 500; onTriggered: root.seedFromRofi() }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function open(): void { root.query = ""; root.open = true }
        function close(): void { root.open = false }
    }
}
