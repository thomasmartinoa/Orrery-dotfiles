pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Theme catalogue from `orrery-theme json`, plus the picker's state.
// A theme is any folder in ~/.config/orrery/themes with a colors.toml,
// so anything you or an agent drop there shows up.
Singleton {
    id: root
    property var themes: []
    property string pickerMode: ""      // "" | "theme" | "wallpaper"
    readonly property bool open: pickerMode !== ""
    // the mode last opened, kept while closed: the picker's cards stay built
    // for it, so reopening shows them at once instead of rebuilding them
    property string lastMode: "theme"

    signal moveBy(int by)
    function refresh() { list.running = true }
    function openPicker(mode) { refresh(); lastMode = mode; pickerMode = mode }
    function close() { pickerMode = "" }
    function apply(id) { Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/orrery-theme", "set", id]); close() }
    function applyWallpaper(path) { Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/orrery-wall", "set", path]); close() }

    readonly property var current: themes.find(t => t.current) || null
    readonly property var wallpapers: {
        // the current theme's backgrounds first, then your wallpapers folder
        // (the Wallpaper theme's own, already first when it's on), then the
        // other themes'
        const cur = current ? current.backgrounds : []
        const seen = {}, out = []
        const add = (p) => { if (!seen[p]) { seen[p] = true; out.push(p) } }
        cur.forEach(add)
        WallTheme.images.forEach(add)
        for (const t of themes) if (!t.current) t.backgrounds.forEach(add)
        return out
    }

    Process {
        id: list
        command: [Quickshell.env("HOME") + "/.local/bin/orrery-theme", "json"]
        // Only a changed catalogue replaces `themes`: a new array rebuilds every
        // picker card, and each would reload its picture (the picker flashed on open)
        property string last: ""
        stdout: StdioCollector { onStreamFinished: {
            if (text === list.last) return
            try { root.themes = JSON.parse(text); list.last = text } catch (e) { console.warn("Themes: " + e) }
        } }
    }
    Component.onCompleted: refresh()
    // a theme switch re-renders colors.json (Theme reloads it) → re-read the catalogue
    Connections { target: Theme; function onNameChanged() { root.refresh() } function onModeChanged() { root.refresh() } }

    IpcHandler {
        target: "picker"
        function theme(): void { root.openPicker("theme") }
        function wallpaper(): void { root.openPicker("wallpaper") }
        function close(): void { root.close() }
        function toggle(mode: string): void { if (root.pickerMode === mode) root.close(); else root.openPicker(mode) }
        // step the selection (scripts, screenshots): + right, - left
        function move(by: int): void { root.moveBy(by) }
    }
}
