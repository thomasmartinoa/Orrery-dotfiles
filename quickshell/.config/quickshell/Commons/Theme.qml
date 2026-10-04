pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The rice's palette, live. orrery-theme renders ~/.config/orrery/current/
// colors.json on every switch; this watches it, so every shell surface
// recolours the moment the theme changes. `qs ipc call theme reload` is the
// explicit nudge orrery-theme sends (the file is replaced atomically, which
// can outrun the watcher).
Singleton {
    id: root

    readonly property string file: Quickshell.env("HOME") + "/.config/orrery/current/colors.json"

    property string name: "Eclipse"
    property string mode: "dark"
    readonly property bool light: mode === "light"

    // Bar skin: "pill" (Legacy: floating bordered modules), "floating" (the
    // minimal strip, inset from the edge with rounded corners) or "minimal"
    // (flat strip flush with the edge, Omarchy-like).
    // A theme sets its preference in colors.toml; `qs ipc call bar style X`
    // overrides it for this session.
    property string themeBarStyle: "minimal"
    // the skin you picked (SUPER+SHIFT+B, the menu) is saved in shell.json as
    // bar.skin so it survives restarts; "" = follow the theme's preference
    readonly property string barOverride: Config.skin
    readonly property string barStyle: barOverride !== "" ? barOverride : themeBarStyle
    // widget set + layout the skin uses: floating shares minimal's
    readonly property string barLayout: barStyle === "pill" ? "pill" : "minimal"
    // true once colors.json was read (or failed): the bar maps only then, so
    // it never starts with another skin's margins (they would stick)
    property bool ready: false

    // hued = true for a real-palette theme (Catppuccin…): widgets then use
    // c.good / c.warning / c.critical the way a stock bar does; the mono
    // themes keep telling state apart by shade only.
    property bool hued: false

    // Defaults = Eclipse dark, so the shell renders before the file loads.
    property var c: ({
        bg0: "#0a0a0a", bg1: "#141414", bg2: "#1e1e1e", bg3: "#282828", bg4: "#333333",
        fg: "#e8e8e8",
        accentBright: "#ffffff", accentLight: "#e0e0e0", accentMid: "#a0a0a0", accentDim: "#606060",
        active: "#ffffff", hover: "#cccccc", warning: "#b0b0b0", critical: "#808080", good: "#b0b0b0",
        grey0: "#404040", grey1: "#707070", grey2: "#a0a0a0",
        border: "#3de0e0e0", borderStrong: "#abffffff"
    })

    // The rice's corner: squarish, 4px (Hyprland rounding = 4, rofi 4px). The
    // theme can set its own; orrery-border (Config.radius) overrides both, for
    // the shell and Hyprland alike. radiusSm is for small things inside a surface.
    property int themeRadius: 4
    // the theme's dock: "" (no preference) | bottom | left | right | top | off;
    // Services/Dock uses it only where shell.json has no choice of yours
    property string themeDock: ""
    readonly property int radius: Config.radius >= 0 ? Config.radius : themeRadius
    readonly property int radiusSm: Math.round(radius * 0.75)

    // colours in `c` are strings (JSON); use this for translucent variants
    function alpha(col, a) { const q = Qt.color(col); return Qt.rgba(q.r, q.g, q.b, a) }

    // `orrery-font set <family>` writes shell.json; "" keeps the rice's own
    readonly property string font: Config.fontFamily !== "" ? Config.fontFamily : "JetBrainsMono Nerd Font Propo"
    // GTK's "12px" in the old waybar css rendered at ~15 logical px; match it.
    // one knob for text size: `orrery-text-size <px>` writes shell.json, this
    // scales every size in the shell from the 12px design baseline
    readonly property int fontSize: Config.fontSize
    function fs(px) { return Math.max(6, Math.round(px * Config.fontSize / 12)) }

    function parse() {
        try {
            const j = JSON.parse(view.text())
            if (j.colors) root.c = j.colors
            if (j.mode) root.mode = j.mode
            root.hued = j.hued === true
            if (j.name) root.name = j.name
            if (j.bar === "pill" || j.bar === "floating" || j.bar === "minimal") root.themeBarStyle = j.bar
            if (j.radius !== undefined) root.themeRadius = j.radius
            root.themeDock = typeof j.dock === "string" ? j.dock : ""
        } catch (e) {
            console.warn("Theme: could not parse " + root.file + ": " + e)
        }
    }

    FileView {
        id: view
        path: root.file
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { root.parse(); root.ready = true }
        onLoadFailed: (err) => { console.warn("Theme: " + root.file + " not readable (" + err + "), using defaults"); root.ready = true }
    }

    IpcHandler {
        target: "theme"
        function reload(): void { view.reload() }
        function current(): string { return root.name + " (" + root.mode + ")" }
    }

}
