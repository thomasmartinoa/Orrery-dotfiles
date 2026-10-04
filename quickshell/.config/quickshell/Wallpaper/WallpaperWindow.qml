import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// One background layer per screen, crossfading between images.
Variants {
    model: Quickshell.screens
    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "orrery-wallpaper"
        color: Theme.c.bg0

        // two slots; `front` is the one showing, the other loads the next
        property int front: 0
        property var slots: [a, b]
        function show(path, gen) {
            const back = slots[1 - front]
            // cache-bust so re-setting the same symlink re-reads the new target
            back.source = "file://" + path + "?g=" + gen
        }
        Connections {
            target: Wallpaper
            function onGenerationChanged() { win.show(Wallpaper.path, Wallpaper.generation) }
        }
        Component.onCompleted: show(Wallpaper.path, Wallpaper.generation)

        component Slot: Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
            sourceSize: Qt.size(win.screen.width * win.screen.devicePixelRatio, win.screen.height * win.screen.devicePixelRatio)
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
            onStatusChanged: {
                if (status === Image.Ready && win.slots[win.front] !== this) {
                    opacity = 1
                    win.slots[win.front].opacity = 0
                    win.front = win.slots.indexOf(this)
                } else if (status === Image.Error) {
                    console.warn("wallpaper: cannot load " + source)
                    Wallpaper.recover()
                }
            }
        }
        Slot { id: a; z: win.front === 0 ? 1 : 0 }
        Slot { id: b; z: win.front === 1 ? 1 : 0 }
    }
}
