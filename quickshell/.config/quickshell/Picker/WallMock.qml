import QtQuick
import qs.Commons

// What colours-from-wallpaper would make of the selected picture, drawn over
// it: the bar along the top and one panel, in the palette the picture gives.
// Light on purpose: the picture is what you're choosing, so most of it stays
// in view. Drawn for a 768-wide card and scaled.
Item {
    id: m
    property var colors: null           // orrery-wall-theme preview's colours
    readonly property var c: colors || ({})
    readonly property real k: width / 768
    readonly property real r: Math.max(2, Theme.radius) * k
    opacity: colors ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Motion.fadeMs } }

    component T: Text { font.family: Theme.font; color: m.c.fg || "white"; renderType: Text.QtRendering }

    // ---- the bar ----
    Rectangle {
        width: parent.width; height: 24 * m.k
        color: m.c.bg0 || "black"
        T { x: 12 * m.k; anchors.verticalCenter: parent.verticalCenter; text: "●  2  3  4"; font.pixelSize: 10 * m.k; color: m.c.accent_bright || "white" }
        T { anchors.centerIn: parent; text: "Monday 09:41"; font.pixelSize: 10 * m.k }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 12 * m.k; anchors.verticalCenter: parent.verticalCenter
            spacing: 9 * m.k
            Repeater { model: 5; Rectangle { width: 9 * m.k; height: 9 * m.k; radius: 2 * m.k; color: m.c.accent_light || "white" } }
            Rectangle { width: 9 * m.k; height: 9 * m.k; radius: 4.5 * m.k; color: m.c.accent_bright || "white" }
        }
    }

    // ---- a panel, as if opened from the bar ----
    Rectangle {
        id: panel
        anchors.right: parent.right; anchors.rightMargin: 10 * m.k
        y: 30 * m.k
        width: 230 * m.k; height: col.height + 24 * m.k
        radius: m.r
        color: m.c.bg0 || "black"
        border.width: 1; border.color: m.c.bg3 || "grey"
        Column {
            id: col
            x: 12 * m.k; y: 12 * m.k; width: parent.width - 24 * m.k
            spacing: 8 * m.k
            T { text: "Sound"; font.pixelSize: 12 * m.k; font.weight: Font.DemiBold }
            T { text: "OUTPUT"; font.pixelSize: 7.5 * m.k; font.letterSpacing: 1 * m.k; color: m.c.accent_mid || "grey" }
            // a slider at 70 %
            Item {
                width: parent.width; height: 12 * m.k
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 30 * m.k; height: 4 * m.k; radius: 2 * m.k; color: m.c.bg3 || "grey"
                            Rectangle { width: parent.width * 0.7; height: parent.height; radius: parent.radius; color: m.c.accent_bright || "white" }
                            Rectangle { x: parent.width * 0.7 - 6 * m.k; anchors.verticalCenter: parent.verticalCenter; width: 12 * m.k; height: 12 * m.k; radius: 6 * m.k; color: m.c.accent_bright || "white" } }
                T { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "70%"; font.pixelSize: 8.5 * m.k; color: m.c.accent_light || "white" }
            }
            // the chosen device, highlighted
            Rectangle {
                width: parent.width; height: 24 * m.k; radius: m.r
                color: m.c.bg2 || "grey"
                T { x: 8 * m.k; anchors.verticalCenter: parent.verticalCenter; text: "Speaker"; font.pixelSize: 9 * m.k }
                T { anchors.right: parent.right; anchors.rightMargin: 8 * m.k; anchors.verticalCenter: parent.verticalCenter; text: "✓"; font.pixelSize: 9 * m.k; color: m.c.accent_bright || "white" }
            }
            T { x: 8 * m.k; text: "Headphones"; font.pixelSize: 9 * m.k; color: m.c.accent_light || "white" }
            Rectangle { width: parent.width; height: 1; color: m.c.bg3 || "grey" }
            // a switch, on
            Item {
                width: parent.width; height: 14 * m.k
                T { anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi"; font.pixelSize: 9 * m.k }
                Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: 26 * m.k; height: 14 * m.k; radius: 7 * m.k; color: m.c.accent_bright || "white"
                            Rectangle { x: parent.width - width - 2 * m.k; anchors.verticalCenter: parent.verticalCenter
                                        width: 10 * m.k; height: 10 * m.k; radius: 5 * m.k; color: m.c.bg0 || "black" } }
            }
            // the terminal colours
            Row {
                spacing: 4 * m.k
                Repeater {
                    model: ["red", "orange", "yellow", "green", "aqua", "blue", "purple"]
                    Rectangle { required property string modelData; width: 18 * m.k; height: 8 * m.k; radius: 2 * m.k; color: m.c[modelData] || "grey" }
                }
            }
        }
    }
}
