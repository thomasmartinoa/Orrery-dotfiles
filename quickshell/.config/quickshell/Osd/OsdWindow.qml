import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Bar
import qs.Services

// Volume / brightness overlay, bottom centre of the focused screen.
Variants {
    model: Quickshell.screens
    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        visible: Osd.visible
        anchors.bottom: true
        // clear of a bottom dock (its icon row + padding + gap), whether or not
        // it is slid away at the moment
        margins.bottom: Dock.enabled && Dock.position === "bottom" ? Dock.iconSize + 12 + 12 + 6 + 16 : 60
        implicitWidth: 260
        implicitHeight: 48
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "orrery-osd"
        mask: Region {}      // click-through

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.c.bg0
            border.width: 1
            border.color: Theme.c.border
            opacity: Osd.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            readonly property string icon: Osd.kind === "brightness" ? (Osd.value < 0.34 ? "brightness_low" : Osd.value < 0.67 ? "brightness_medium" : "brightness_high")
                                         : Osd.kind === "mic" ? (Osd.muted ? "mic_off" : "mic")
                                         : Osd.muted ? "volume_off" : Osd.value < 0.01 ? "volume_mute" : Osd.value < 0.5 ? "volume_down" : "volume_up"
            // colours from the wallpaper: a message and a moving bar while it works
            Row {
                anchors.centerIn: parent
                spacing: 12
                visible: Osd.kind === "colours"
                Icon { icon: Osd.working ? "palette" : "check"; size: Theme.fs(20); width: 24; color: Theme.c.accentBright
                       anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Label { text: Osd.working ? "Applying colours…" : "Colours applied"; font.pixelSize: Theme.fs(12); color: Theme.c.fg }
                    Rectangle {
                        width: 170; height: 3; radius: 1.5; color: Theme.c.bg3; clip: true
                        visible: Osd.working
                        Rectangle {
                            width: 50; height: parent.height; radius: 1.5; color: Theme.c.accentBright
                            NumberAnimation on x { from: -50; to: 170; duration: 1100; loops: Animation.Infinite; running: Osd.working && Osd.visible }
                        }
                    }
                }
            }
            Row {
                anchors.centerIn: parent
                spacing: 12
                visible: Osd.kind !== "colours"
                Icon { icon: parent.parent.icon; size: Theme.fs(22); width: 24; color: Osd.muted ? Theme.c.accentDim : Theme.c.accentBright }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150; height: 6; radius: 3; color: Theme.c.bg3
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Osd.value)); height: parent.height; radius: 3
                        color: Osd.muted ? Theme.c.accentDim : Theme.c.fg
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }
                }
                Label { text: Math.round(Osd.value * 100) + "%"; width: 36; horizontalAlignment: Text.AlignRight
                        font.pixelSize: Theme.fs(12); color: Theme.c.accentMid }
            }
        }
    }
}
