pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The current wallpaper. ~/.config/orrery/current/background is the
// symlink orrery-wall maintains; on start we show whatever it points at, and
// orrery-wall pushes every change over IPC so the windows can crossfade.
Singleton {
    id: root
    readonly property string link: Quickshell.env("HOME") + "/.config/orrery/current/background"
    property string path: link
    property int generation: 0        // bumps on every set, even to the same path
    // the picture itself: `path` may be the link (at start, on reload), and the
    // picker compares real files
    property string file: ""
    Process {
        id: resolve
        command: ["readlink", "-f", root.path]
        stdout: StdioCollector { onStreamFinished: root.file = text.trim() }
    }
    Component.onCompleted: resolve.running = true

    // the link can be missing (a theme step that never finished): ask
    // orrery-wall to pick one of the theme's backgrounds, once; it calls set()
    property bool recovering: false
    function recover() {
        if (recovering) return
        recovering = true
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/orrery-wall", "ensure"])
    }

    function set(p) {
        path = p && p.length > 0 ? p : link
        generation++
        resolve.running = false; resolve.running = true
    }

    IpcHandler {
        target: "wallpaper"
        function set(path: string): string { root.set(path); return root.path }
        function get(): string { return root.path }
        function reload(): void { root.set(root.link) }
    }
}
