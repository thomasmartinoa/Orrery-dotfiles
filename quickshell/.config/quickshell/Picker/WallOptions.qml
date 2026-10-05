import QtQuick
import qs.Commons
import qs.Bar
import qs.Panels
import qs.Services

// Under the wallpaper carousel: colours from the wallpaper. The switch turns
// the generated "Wallpaper" theme on or off; mode, style and the picture's
// main colours shape it, and the chip shows what the selected picture would
// give. Off, only the switch shows (the rest would do nothing); on, the rest
// slides open. With it on, a change to the wallpaper on screen applies at
// once; another picture applies on Enter, as always.
Rectangle {
    id: bar
    property string path: ""                 // the selected picture
    property bool isCurrent: false           // ...is the wallpaper on screen
    readonly property var pv: WallTheme.preview
    signal applyNow()                         // re-apply the picture on screen with the new settings

    width: row.width + 24
    Behavior on width { NumberAnimation { duration: Motion.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.moveCurve } }
    clip: true
    height: 52
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
                onToggled: (want) => want ? WallTheme.turnOn(bar.path) : WallTheme.turnOff()
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Label { text: "Colours from wallpaper"; font.pixelSize: Theme.fs(12); color: Theme.c.fg }
                Label { text: !WallTheme.on ? (WallTheme.picture ? "Let your pictures colour the desktop" : "Add a picture to start")
                              : bar.pv && WallTheme.mode === "auto" ? "Auto picked " + (bar.pv.mode === "light" ? "light" : "dark") + " for this picture"
                              : "The desktop follows the picture"
                        font.pixelSize: Theme.fs(10); color: Theme.c.accentMid }
            }
        }

        // the settings: only with the switch on
        Item {
            id: more
            anchors.verticalCenter: parent.verticalCenter
            width: WallTheme.on ? moreRow.width : 0
            height: moreRow.height
            opacity: WallTheme.on ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.fadeMs } }
            Row {
                id: moreRow
                spacing: 14
                visible: more.opacity > 0
        Rectangle { width: 1; height: 24; anchors.verticalCenter: parent.verticalCenter; color: Theme.c.border }

        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fs(12) * 14; height: 30
            current: WallTheme.mode
            // Auto says what it chose for this picture
            options: [{ label: "Auto", value: "auto" }, { label: "Dark", value: "dark" }, { label: "Light", value: "light" }]
            onPicked: (v) => WallTheme.setMode(v)
        }
        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fs(12) * 18; height: 30
            current: bar.pv && bar.pv.mono ? "" : WallTheme.style
            opacity: bar.pv && bar.pv.mono ? 0.4 : 1
            options: [{ label: "Soft", value: "soft" }, { label: "Faithful", value: "faithful" }, { label: "Vivid", value: "vivid" }]
            onPicked: (v) => WallTheme.setStyle(v)
        }

        // the picture's main colours: which one leads
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: bar.pv && bar.pv.candidates.length > 1
            Label { anchors.verticalCenter: parent.verticalCenter; text: "Accent"; font.pixelSize: Theme.fs(11); color: Theme.c.accentMid; rightPadding: 2 }
            Repeater {
                model: bar.pv ? bar.pv.candidates : []
                Rectangle {
                    required property string modelData
                    required property int index
                    readonly property bool sel: index === WallTheme.previewAccent
                    width: 24; height: 24; radius: 12
                    color: modelData
                    border.width: sel || sm.containsMouse ? 2 : 1
                    border.color: sel ? Theme.c.fg : sm.containsMouse ? Theme.c.accentLight : Theme.c.border
                    scale: sm.containsMouse && !sel ? 1.1 : 1
                    Behavior on scale { NumberAnimation { duration: Motion.fadeMs } }
                    Rectangle { anchors.centerIn: parent; visible: parent.sel; width: 6; height: 6; radius: 3; color: Theme.c.fg }
                    MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { WallTheme.want(bar.path, index); bar.changed() } }
                }
            }
        }

            }
        }
    }
}
