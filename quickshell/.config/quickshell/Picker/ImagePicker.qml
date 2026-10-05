import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Bar
import qs.Services

// The picker — Omarchy's carousel: the selected item expanded in the
// middle, the rest as tall dimmed slices to either side, all sliding as
// the selection moves. Themes are previewed live in their own colours
// (ThemePreview); wallpapers are just the image, with colours-from-wallpaper
// under them (WallOptions).
// ← → (h l), Home/End, scroll; Enter applies; Esc; type to filter. Wallpapers
// also: Ctrl+T colours on/off, Ctrl+M mode, Ctrl+S style, Ctrl+1–4 main colour,
// Ctrl+O add an image; or drop an image file on the picker.
Variants {
    model: Quickshell.screens
    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        visible: Themes.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Themes.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "orrery-picker"
        color: Theme.alpha(Theme.c.bg0, 0.72)

        readonly property bool themeMode: Themes.lastMode === "theme"
        property string filter: ""
        property int selected: 0
        readonly property var items: {
            const q = filter.toLowerCase()
            if (themeMode) {
                // "From wallpaper" last, and there even before its first use
                const match = (t) => q === "" || t.name.toLowerCase().indexOf(q) !== -1 || t.id.indexOf(q) !== -1
                const own = Themes.themes.filter(t => t.id !== "wallpaper" && match(t))
                const wall = Themes.themes.find(t => t.id === "wallpaper") || { id: "wallpaper", name: "From wallpaper", virtual: true }
                return match(wall) ? own.concat([wall]) : own
            }
            const walls = Themes.wallpapers.filter(p => q === "" || p.split("/").pop().toLowerCase().indexOf(q) !== -1).map(p => ({ path: p }))
            // the last card adds a picture (file chooser); not while filtering
            return q === "" ? walls.concat([{ path: "", add: true }]) : walls
        }
        // the catalogue is re-read on open; until it lands, land on the current item
        property bool snapToCurrent: false
        function snap() { selected = Math.max(0, items.findIndex(t => t.current || t.path === Wallpaper.file)) }
        onItemsChanged: {
            // a picture just added (file chooser, drop): select it once it's listed
            if (pendingPath) { const i = items.findIndex(t => t.path === pendingPath); if (i >= 0) { selected = i; pendingPath = ""; snapToCurrent = false; return } }
            if (snapToCurrent && filter === "") snap()
            else if (selected >= items.length) selected = Math.max(0, items.length - 1)
        }
        onVisibleChanged: if (visible) { filter = ""; snapToCurrent = true; snap(); WallTheme.refresh(); askPreview(true) } else snapToCurrent = false
        // the palette for the selection; on open always fresh (settings or the
        // theme may have changed since the picker was last shown)
        function askPreview(fresh) {
            // the theme picker's "From wallpaper" card before its first use: the wallpaper on screen
            if (themeMode) { if (!Themes.themes.find(t => t.id === "wallpaper") && WallTheme.picture) WallTheme.want(WallTheme.picture, WallTheme.accentFor(WallTheme.picture)); return }
            if (!selPath) return
            if (fresh) WallTheme.preview = null
            // computed here, not from selIsCurrent: in a change handler that
            // binding can still hold the previous picture's answer
            WallTheme.want(selPath, WallTheme.accentFor(selPath))
        }
        onFilterChanged: if (filter !== "") snapToCurrent = false

        // geometry (Omarchy: 768x475 expanded, 108x432 slices); scaled to the screen
        readonly property real k: Math.min(1, (screen.width - 160) / 1400, (screen.height - 200) / 640)
        readonly property int bigW: Math.round(768 * k)
        readonly property int bigH: Math.round(475 * k)
        readonly property int sliceW: Math.round(108 * k)
        readonly property int sliceH: Math.round(432 * k)
        readonly property int gap: Math.round(10 * k)
        readonly property int step: sliceW + gap
        readonly property int sidesEach: Math.max(1, Math.floor((screen.width - 120 - bigW) / 2 / step))

        function activate() {
            const it = items[selected]; if (!it) return
            if (themeMode && it.virtual) { WallTheme.turnOn(""); Themes.close() }
            else if (themeMode) Themes.apply(it.id)
            else if (it.add) WallTheme.addImage()
            // the accent you clicked for this picture, else the one it remembers
            else if (WallTheme.on) { WallTheme.apply(it.path, WallTheme.previewPath === it.path ? WallTheme.previewAccent : undefined); Themes.close() }
            else Themes.applyWallpaper(it.path)
        }

        // colours from wallpaper: the selected picture's palette, kept fresh
        readonly property string selPath: !themeMode && items[selected] ? (items[selected].path || "") : ""
        readonly property bool selIsCurrent: selPath !== "" && selPath === Wallpaper.file
        onSelPathChanged: askPreview(false)
        Connections { target: Themes; function onMoveBy(by) { win.move(by) } }
        // a picture just added (file chooser, drop): select it once it's listed
        property string pendingPath: ""
        Connections {
            target: WallTheme
            function onAdded(path) {
                win.pendingPath = path
                if (WallTheme.on) WallTheme.apply(path, 0)
            }
        }
        function cycle(list, cur) { return list[(list.indexOf(cur) + 1) % list.length] }
        function move(d) { const n = items.length; if (n) selected = Math.max(0, Math.min(n - 1, selected + d)) }

        MouseArea { anchors.fill: parent; onClicked: Themes.close(); onWheel: (w) => win.move(w.angleDelta.y > 0 ? -1 : 1) }

        Item {
            anchors.fill: parent
            focus: Themes.open
            Keys.onPressed: (e) => {
                if (!win.themeMode && (e.modifiers & Qt.ControlModifier)) {
                    if (e.key === Qt.Key_T) { if (WallTheme.on) WallTheme.turnOff(); else WallTheme.turnOn(win.selPath); return }
                    if (e.key === Qt.Key_M) { WallTheme.setMode(win.cycle(["auto", "dark", "light"], WallTheme.mode)); return }
                    if (e.key === Qt.Key_S) { WallTheme.setStyle(win.cycle(["soft", "faithful", "vivid"], WallTheme.style)); return }
                    if (e.key === Qt.Key_O) { WallTheme.addImage(); return }
                    if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) { WallTheme.want(win.selPath, e.key - Qt.Key_1); opts.changed(); return }
                }
                if (e.key === Qt.Key_Escape) { if (win.filter !== "") win.filter = ""; else Themes.close(); return }
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.activate(); return }
                if (e.key === Qt.Key_Left  || (e.key === Qt.Key_H && win.filter === "")) { win.move(-1); return }
                if (e.key === Qt.Key_Right || (e.key === Qt.Key_L && win.filter === "") || e.key === Qt.Key_Tab) { win.move(1); return }
                if (e.key === Qt.Key_Home) { win.selected = 0; return }
                if (e.key === Qt.Key_End) { win.selected = Math.max(0, win.items.length - 1); return }
                if (e.key === Qt.Key_Backspace) { win.filter = win.filter.slice(0, -1); return }
                if (e.text && e.text.length === 1 && e.text >= " ") { win.filter += e.text; win.selected = 0 }
            }

            Arrive { target: carousel; when: win.visible; from: 0.97 }
            // carousel
            Item {
                id: carousel
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - win.bigH) / 2
                width: win.bigW + 2 * win.sidesEach * win.step
                height: win.bigH
                readonly property real bigX: (width - win.bigW) / 2

                Repeater {
                    model: win.items
                    Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property int rel: index - win.selected
                        readonly property bool sel: rel === 0
                        readonly property bool shown: Math.abs(rel) <= win.sidesEach
                        visible: shown || xAnim.running
                        x: sel ? carousel.bigX
                           : rel < 0 ? carousel.bigX + rel * win.step
                                     : carousel.bigX + win.bigW + win.gap + (rel - 1) * win.step
                        y: (carousel.height - height) / 2
                        width: sel ? win.bigW : win.sliceW
                        height: sel ? win.bigH : win.sliceH
                        z: sel ? 2 : 1
                        Behavior on x { NumberAnimation { id: xAnim; duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius
                            color: Theme.c.bg1
                            border.width: cell.sel ? 3 : 1
                            border.color: cell.sel ? Theme.c.accentBright : Theme.c.border
                            clip: true
                            // the content is always drawn at the expanded size and cropped, so
                            // a slice is a strip of the same picture
                            Item {
                                id: content
                                width: win.bigW; height: win.bigH
                                x: (parent.width - width) / 2
                                y: (parent.height - height) / 2
                                Loader {
                                    anchors.fill: parent
                                    sourceComponent: win.themeMode ? themePreview : cell.modelData.add ? addTile : wallPreview
                                }
                                // colours on: the selected picture, as the desktop would look
                                WallMock {
                                    anchors.fill: parent
                                    visible: !win.themeMode && cell.sel && WallTheme.on && !cell.modelData.add
                                    colors: visible && WallTheme.preview && WallTheme.previewPath === cell.modelData.path ? WallTheme.preview.colors : null
                                }
                                Component {
                                    id: addTile
                                    Rectangle {
                                        color: Theme.c.bg1
                                        // a dashed outline in the accent, inset, with rounded corners
                                        Canvas {
                                            id: dash
                                            anchors.fill: parent; anchors.margins: 22
                                            onPaint: {
                                                const g = getContext("2d"); g.reset()
                                                g.setLineDash([10, 7]); g.lineWidth = 2
                                                g.strokeStyle = Theme.alpha(Theme.c.accentBright, 0.55)
                                                const r = Math.max(4, Theme.radius * 2)
                                                g.beginPath(); g.roundedRect(1, 1, width - 2, height - 2, r, r); g.stroke()
                                            }
                                            Connections { target: Theme; function onCChanged() { dash.requestPaint() } }
                                        }
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 12
                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 72; height: 72; radius: 36
                                                color: Theme.alpha(Theme.c.accentBright, 0.14)
                                                Icon { anchors.centerIn: parent; icon: "add_photo_alternate"; size: Theme.fs(34); color: Theme.c.accentBright }
                                            }
                                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Add a picture"; font.pixelSize: Theme.fs(18); font.weight: Font.DemiBold; color: Theme.c.fg }
                                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Choose a file, or drop one anywhere here"; font.pixelSize: Theme.fs(12); color: Theme.c.accentLight }
                                            Label { anchors.horizontalCenter: parent.horizontalCenter
                                                    text: "It's copied into " + (WallTheme.folder || "~/Pictures/Wallpapers").replace(Quickshell.env("HOME"), "~")
                                                    font.pixelSize: Theme.fs(11); color: Theme.c.accentMid }
                                        }
                                    }
                                }
                                Component { id: themePreview
                                            Loader { sourceComponent: cell.modelData.id === "wallpaper" ? wallCard : plainTheme
                                                     Component { id: plainTheme; ThemePreview { theme: cell.modelData } }
                                                     Component { id: wallCard; WallThemeCard { theme: cell.modelData } } } }
                                Component {
                                    id: wallPreview
                                    Image {
                                        source: "file://" + cell.modelData.path
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize: Qt.size(1024, 640)
                                        cache: true
                                        // a first load fades in instead of popping over the empty card
                                        opacity: status === Image.Ready ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }
                                }
                            }
                            Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.c.bg0, cell.sel ? 0 : 0.42)
                                        Behavior on color { ColorAnimation { duration: 220 } } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (cell.sel) win.activate(); else win.selected = cell.index }
                        }
                    }
                }
            }

            // themes: which one this is (the cards alone never said)
            Row {
                id: caption
                visible: win.themeMode
                readonly property var it: win.items[win.selected] || null
                anchors.top: carousel.bottom; anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                height: 26
                Label { anchors.verticalCenter: parent.verticalCenter; text: (caption.it && caption.it.name) || ""
                        font.pixelSize: Theme.fs(15); font.weight: Font.DemiBold; color: Theme.c.fg }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!caption.it
                    width: modeL.width + 16; height: 20; radius: 10
                    color: Theme.c.bg2; border.width: 1; border.color: Theme.c.border
                    Label { id: modeL; anchors.centerIn: parent; font.pixelSize: Theme.fs(10.5); color: Theme.c.accentLight
                            text: !caption.it ? "" : caption.it.id === "wallpaper" ? "Follows your wallpaper"
                                  : caption.it.mode === "light" ? "Light" : "Dark" }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!caption.it && !!caption.it.current
                    spacing: 5
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: Theme.c.accentBright }
                    Label { text: "In use"; font.pixelSize: Theme.fs(11); color: Theme.c.accentMid }
                }
            }

            // wallpapers: colours from the wallpaper
            WallOptions {
                id: opts
                visible: !win.themeMode
                anchors.top: carousel.bottom; anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                path: win.selPath
                isCurrent: win.selIsCurrent
                onApplyNow: WallTheme.apply(win.selPath, WallTheme.previewAccent)
            }

            // an image file dropped from a file manager: into your folder, and selected
            DropArea {
                id: drop
                anchors.fill: parent
                enabled: !win.themeMode
                keys: ["text/uri-list"]
                property bool over: false
                onEntered: over = true
                onExited: over = false
                onDropped: (drop) => {
                    over = false
                    for (const u of drop.urls) {
                        const p = decodeURIComponent(u.toString().replace(/^file:\/\//, ""))
                        if (/\.(png|jpe?g|webp)$/i.test(p)) { WallTheme.importImage(p); break }
                    }
                }
            }

            // a picture being dragged over the picker: where it will go
            Rectangle {
                anchors.fill: parent
                visible: drop.over
                color: Theme.alpha(Theme.c.bg0, 0.6)
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; icon: "add_photo_alternate"; size: Theme.fs(40); color: Theme.c.accentBright }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Drop the picture to add it"; font.pixelSize: Theme.fs(16); color: Theme.c.fg }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "It's copied into " + (WallTheme.folder || "~/Pictures/Wallpapers").replace(Quickshell.env("HOME"), "~")
                            font.pixelSize: Theme.fs(11); color: Theme.c.accentMid }
                }
            }

            // only the filter shows while you type
            Label {
                visible: win.filter !== ""
                anchors.top: win.themeMode ? caption.bottom : opts.bottom; anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u{f0349}  " + win.filter
                font.pixelSize: Theme.fs(13); color: Theme.c.fg
            }
        }
    }
}
