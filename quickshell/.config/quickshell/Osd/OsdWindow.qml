import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Bar
import qs.Services

// Volume / brightness overlay, bottom centre of the focused screen; between
// volume changes it also says "Starting <app>…" (Services/Launching.qml).
Variants {
    model: Quickshell.screens
    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        visible: Osd.visible || Launching.visible
        // volume / brightness win over the app notice, which comes back after
        readonly property string kind: Osd.visible ? Osd.kind : "app"
        anchors.bottom: true
        // clear of a bottom dock (its icon row + padding + gap), whether or not
        // it is slid away at the moment
        margins.bottom: Dock.enabled && Dock.position === "bottom" ? Dock.iconSize + 12 + 12 + 6 + 16 : 60
        // the colours and app notices are sized to their text, so they sit centred
        implicitWidth: kind === "colours" ? coloursRow.width + 56 : kind === "app" ? appRow.width + 56 : 260
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
            opacity: win.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            readonly property string icon: Osd.kind === "brightness" ? (Osd.value < 0.34 ? "brightness_low" : Osd.value < 0.67 ? "brightness_medium" : "brightness_high")
                                         : Osd.kind === "mic" ? (Osd.muted ? "mic_off" : "mic")
                                         : Osd.muted ? "volume_off" : Osd.value < 0.01 ? "volume_mute" : Osd.value < 0.5 ? "volume_down" : "volume_up"
            // colours from the wallpaper: a message and a moving bar while it works
            Row {
                id: coloursRow
                anchors.centerIn: parent
                spacing: 10
                visible: win.kind === "colours"
                Icon { icon: Osd.working ? "palette" : "check"; size: Theme.fs(18); color: Theme.c.accentBright
                       anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Label { id: coloursText; text: Osd.working ? "Applying colours…" : "Colours applied"; font.pixelSize: Theme.fs(12); color: Theme.c.fg }
                    Rectangle {
                        width: Math.max(coloursText.width, 140); height: 3; radius: 1.5; color: Theme.c.bg3; clip: true
                        visible: Osd.working
                        Rectangle {
                            width: 50; height: parent.height; radius: 1.5; color: Theme.c.accentBright
                            NumberAnimation on x { from: -50; to: 190; duration: 1100; loops: Animation.Infinite; running: Osd.working && Osd.visible }
                        }
                    }
                }
            }
            Row {
                anchors.centerIn: parent
                spacing: 12
                visible: win.kind !== "colours" && win.kind !== "app"
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
            // an app on its way: its icon, the name and a moving bar, like the colours notice
            Row {
                id: appRow
                anchors.centerIn: parent
                spacing: 10
                visible: win.kind === "app"
                Item {
                    width: 22; height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    IconImage {
                        id: appIcon
                        anchors.fill: parent
                        source: Launching.icon ? Quickshell.iconPath(Launching.icon, true) : ""
                        visible: status === Image.Ready
                    }
                    Icon { anchors.centerIn: parent; visible: !appIcon.visible; icon: "rocket_launch"
                           size: Theme.fs(18); color: Theme.c.accentBright }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    // "Starting" quiet, the app's name in full colour
                    Row {
                        id: appText
                        spacing: 5
                        Label { text: Launching.done ? "Opened" : "Starting"; font.pixelSize: Theme.fs(12); color: Theme.c.accentMid }
                        Label { text: Launching.name; font.pixelSize: Theme.fs(12); color: Theme.c.fg
                                elide: Text.ElideRight; width: Math.min(implicitWidth, 260) }
                        Label { visible: Launching.more > 0; text: "+" + Launching.more; font.pixelSize: Theme.fs(11); color: Theme.c.accentDim }
                    }
                    Rectangle {
                        width: Math.max(appText.width, 140); height: 3; radius: 1.5; color: Theme.c.bg3; clip: true
                        // a sweep while it starts, full once the window is there
                        Rectangle {
                            visible: !Launching.done
                            width: 50; height: parent.height; radius: 1.5; color: Theme.c.accentBright
                            NumberAnimation on x { from: -50; to: Math.max(appText.width, 140); duration: 1100; loops: Animation.Infinite
                                                   running: win.kind === "app" && win.visible && !Launching.done }
                        }
                        // fills from the left once the window is there
                        Rectangle {
                            height: parent.height; radius: 1.5; color: Theme.c.accentBright
                            width: Launching.done ? parent.width : 0
                            visible: Launching.done
                            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }
}
