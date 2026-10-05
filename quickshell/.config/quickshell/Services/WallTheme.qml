pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Colours from your wallpaper (orrery-wall-theme): whether it's on, its
// settings, your wallpapers folder, and a preview of the palette the picker's
// selected picture would give. "On" means the current theme is the
// generated "Wallpaper" theme; off, the shipped themes work as always.
Singleton {
    id: root
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/orrery-wall-theme"
    readonly property bool on: Theme.name === "Wallpaper"
    property string mode: "auto"          // auto | dark | light
    property string style: "soft"         // soft | faithful | vivid
    property int accent: 0
    property string folder: ""
    property var images: []               // your folder, newest last
    property bool busy: false             // a palette is being applied

    // the picker's selection: its palette and main colours
    property string previewPath: ""
    property var preview: null            // { mode, mono, candidates: [...], colors: {...} }
    property int previewAccent: 0

    function refresh() { status.running = true; list.running = true }

    // apply the picture (and remember the settings); off = back to your theme
    function apply(path, accentIndex) {
        busy = true
        applyProc.command = [bin, "apply", path, "--mode", mode, "--style", style,
                             "--accent", String(accentIndex === undefined ? previewAccent : accentIndex)]
        applyProc.running = true
    }
    function turnOff() { Quickshell.execDetached([bin, "off"]) }

    // the picker asks for a picture's palette; the last ask wins
    function want(path, accentIndex) {
        if (path === previewPath && accentIndex === previewAccent && preview) return
        if (path !== previewPath) preview = null
        previewPath = path
        previewAccent = accentIndex
        debounce.restart()
    }
    function setMode(m) { mode = m; rePreview() }
    function setStyle(s) { style = s; rePreview() }
    function rePreview() { preview = null; debounce.restart() }

    // a picture from anywhere: the GTK file chooser, then into the folder
    signal added(string path)
    function addImage() { chooser.running = true }
    function importImage(path) { importProc.command = [bin, "import", path]; importProc.running = true }

    Timer { id: debounce; interval: 120; onTriggered: if (root.previewPath) { previewProc.running = false; previewProc.running = true } }
    Process {
        id: previewProc
        command: [root.bin, "preview", root.previewPath, "--mode", root.mode, "--style", root.style, "--accent", String(root.previewAccent)]
        property string forPath: ""
        onStarted: forPath = root.previewPath
        stdout: StdioCollector { onStreamFinished: {
            if (previewProc.forPath !== root.previewPath) return
            try { root.preview = JSON.parse(text) } catch (e) { root.preview = null }
        } }
    }
    Process {
        id: applyProc
        stdout: StdioCollector { onStreamFinished: { root.busy = false; root.refresh() } }
        onExited: root.busy = false
    }
    Process {
        id: status
        command: [root.bin, "status"]
        stdout: StdioCollector { onStreamFinished: { try {
            const s = JSON.parse(text)
            root.mode = s.mode; root.style = s.style; root.accent = s.accent; root.folder = s.folder
            // the picture on screen: its swatch follows the accent in use
            if (root.on && root.previewPath === Wallpaper.file && root.previewAccent !== s.accent) root.want(root.previewPath, s.accent)
        } catch (e) {} } }
    }
    Process {
        id: list
        command: [root.bin, "list"]
        property string last: ""
        stdout: StdioCollector { onStreamFinished: {
            if (text === list.last) return
            try { root.images = JSON.parse(text); list.last = text } catch (e) {}
        } }
    }
    Process {
        id: chooser
        command: ["zenity", "--file-selection", "--title=Choose a wallpaper",
                  "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG *.WEBP"]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p) root.importImage(p) } }
    }
    Process {
        id: importProc
        stdout: StdioCollector { onStreamFinished: {
            const p = text.trim()
            if (!p) return
            list.running = true
            root.added(p)
            // from the menu, with the picker closed: show it, on the new picture
            if (!Themes.open) Themes.openPicker("wallpaper")
        } }
    }

    Component.onCompleted: refresh()
    // a theme switch can be this one turning on or off: re-read the settings
    Connections { target: Theme; function onNameChanged() { root.refresh() } }

    IpcHandler {
        target: "walltheme"
        function apply(path: string): void { root.apply(path, 0) }
        function off(): void { root.turnOff() }
        function add(): void { root.addImage() }
    }
}
