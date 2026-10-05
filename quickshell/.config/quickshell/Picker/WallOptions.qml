import QtQuick
import qs.Commons
import qs.Bar
import qs.Panels
import qs.Services

// Under the wallpaper carousel: colours from the wallpaper. The switch turns
// the generated "Wallpaper" theme on or off; mode, style and the picture's
// main colours shape it, and the chip shows what the selected picture would
// give. With it on, a change to the wallpaper on screen applies at once;
// another picture applies on Enter, as always.
Rectangle {
    id: bar
    property string path: ""                 // the selected picture
    property bool isCurrent: false           // ...is the wallpaper on screen
    readonly property var pv: WallTheme.preview
    signal applyNow()                         // re-apply the picture on screen with the new settings

    width: row.width + 24
    height: 44
    radius: Theme.radius
    color: Theme.c.bg1
    border.width: 1; border.color: Theme.c.border

    function changed() { if (WallTheme.on && isCurrent) applyNow() }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14

        // on / off
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                on: WallTheme.on
                onToggled: (want) => want ? WallTheme.apply(bar.path) : WallTheme.turnOff()
            }
            Label { anchors.verticalCenter: parent.verticalCenter; text: "Colours from wallpaper"
                    font.pixelSize: Theme.fs(12); color: Theme.c.fg }
        }

        Rectangle { width: 1; height: 24; anchors.verticalCenter: parent.verticalCenter; color: Theme.c.border }

        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fs(12) * 13; height: 30
            current: WallTheme.mode
            options: [{ label: "Auto", value: "auto" }, { label: "Dark", value: "dark" }, { label: "Light", value: "light" }]
            onPicked: (v) => { WallTheme.setMode(v); bar.changed() }
        }
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fs(12) * 16; height: 30
            current: bar.pv && bar.pv.mono ? "" : WallTheme.style
            opacity: bar.pv && bar.pv.mono ? 0.4 : 1
            options: [{ label: "Soft", value: "soft" }, { label: "Faithful", value: "faithful" }, { label: "Vivid", value: "vivid" }]
            onPicked: (v) => { WallTheme.setStyle(v); bar.changed() }
        }

        // the picture's main colours: which one leads
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: bar.pv && bar.pv.candidates.length > 1
            Repeater {
                model: bar.pv ? bar.pv.candidates : []
                Rectangle {
                    required property string modelData
                    required property int index
                    readonly property bool sel: index === WallTheme.previewAccent
                    width: 22; height: 22; radius: 11
                    color: modelData
                    border.width: sel ? 2 : 1
                    border.color: sel ? Theme.c.fg : Theme.c.border
                    Rectangle { anchors.centerIn: parent; visible: parent.sel; width: 6; height: 6; radius: 3; color: Theme.c.fg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { WallTheme.want(bar.path, index); bar.changed() } }
                }
            }
        }

        // what you'd get: the surface, text, accent and hues
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 128; height: 30
            radius: Math.max(2, Theme.radius - 1)
            color: bar.pv ? bar.pv.colors.bg0 : Theme.c.bg0
            border.width: 1; border.color: bar.pv ? bar.pv.colors.bg4 : Theme.c.border
            opacity: bar.pv ? 1 : 0.35
            Behavior on color { ColorAnimation { duration: Motion.fadeMs } }
            Row {
                anchors.centerIn: parent
                spacing: 6
                Label { anchors.verticalCenter: parent.verticalCenter; text: "Aa"; font.pixelSize: Theme.fs(12); font.weight: Font.DemiBold
                        color: bar.pv ? bar.pv.colors.fg : Theme.c.fg }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 8
                            color: bar.pv ? bar.pv.colors.accent_bright : Theme.c.accentBright }
                Repeater {
                    model: ["red", "yellow", "green", "blue", "purple"]
                    Rectangle { required property string modelData
                                anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 3.5
                                color: bar.pv ? bar.pv.colors[modelData] : Theme.c.accentDim }
                }
            }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "add_photo_alternate"
            onClicked: WallTheme.addImage()
        }
    }
}
