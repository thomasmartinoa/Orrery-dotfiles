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
        // shown while wanted, and on through the fade-out
        readonly property bool want: Osd.visible || Launching.visible
        visible: want || card.opacity > 0
        // volume / brightness win over the app notice, which comes back after;
        // while fading out it keeps showing what it showed
        property string kind: "volume"
        readonly property string liveKind: Osd.visible ? Osd.kind : "app"
        onLiveKindChanged: if (want) kind = liveKind
        onWantChanged: if (want) kind = liveKind
        anchors.bottom: true
        // clear of a bottom dock (its icon row + padding + gap), whether or not
        // it is slid away at the moment
        margins.bottom: Dock.enabled && Dock.position === "bottom" ? Dock.iconSize + 12 + 12 + 6 + 16 : 60
        // the colours and app notices are sized to their text, so they sit centred
        implicitWidth: kind === "colours" ? coloursRow.width + 56 : kind === "app" ? appRow.width + 26 : 260
        implicitHeight: 48
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "orrery-osd"
        mask: Region {}      // click-through

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.c.bg0
            border.width: 1
            border.color: Theme.c.border
            // fades in rising 6 px, fades out in place
            opacity: win.want ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: win.want ? 140 : 180; easing.type: Easing.OutCubic } }
            transform: Translate { y: card.rise }
            property real rise: 0
            Connections { target: win; function onWantChanged() { if (win.want && card.opacity < 0.05) riseIn.restart() } }
            NumberAnimation { id: riseIn; target: card; property: "rise"; from: 6; to: 0; duration: 180; easing.type: Easing.OutCubic }

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
                            NumberAnimation on x { from: -50; to: 190; duration: 1100; loops: Animation.Infinite; running: Osd.working && win.want }
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
            // an app on its way, laid out like the volume row (24 px icon column,
            // 12 px gap, the same 260 px box at least): its icon, "Starting <name>"
            // and an indeterminate bar across the whole text column
            Row {
                id: appRow
                anchors.centerIn: parent
                spacing: 12
                visible: win.kind === "app"
                // the volume row's 13 px sides, so the icons line up
                readonly property real col: Math.min(Math.max(appText.implicitWidth, 260 - 26 - 24 - 12), 360)
                Item {
                    width: 24; height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    IconImage {
                        id: appIcon
                        anchors.fill: parent
                        source: Launching.icon ? Quickshell.iconPath(Launching.icon, true) : ""
                        visible: status === Image.Ready
                    }
                    Icon { anchors.centerIn: parent; visible: !appIcon.visible; icon: "rocket_launch"
                           size: Theme.fs(20); color: Theme.c.accentBright }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: appRow.col
                    spacing: 6
                    // "Starting" quiet, the app's name in full colour
                    Row {
                        id: appText
                        spacing: 5
                        Label { id: verb; text: Launching.done ? "Opened" : "Starting"; font.pixelSize: Theme.fs(12); color: Theme.c.accentMid }
                        Label { id: appName; text: Launching.name; font.pixelSize: Theme.fs(12); color: Theme.c.fg; elide: Text.ElideRight
                                width: Math.min(implicitWidth, 360 - verb.implicitWidth - 5 - (moreLabel.visible ? moreLabel.implicitWidth + 5 : 0)) }
                        Label { id: moreLabel; visible: Launching.more > 0; text: "+" + Launching.more; font.pixelSize: Theme.fs(11); color: Theme.c.accentDim
                                anchors.baseline: appName.baseline }
                    }
                    Rectangle {
                        id: track
                        width: appRow.col; height: 3; radius: 1.5; color: Theme.c.bg3; clip: true
                        // an eased sweep while it starts …
                        Rectangle {
                            visible: !Launching.done
                            width: Math.round(track.width * 0.32); height: parent.height; radius: 1.5; color: Theme.c.accentBright
                            NumberAnimation on x { from: -track.width * 0.32; to: track.width; duration: 1300; easing.type: Easing.InOutSine
                                                   loops: Animation.Infinite; running: win.kind === "app" && win.want && !Launching.done }
                        }
                        // … full once the window is there
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
