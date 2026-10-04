import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Services

// Power menu — the old wlogout layout + style, ported:
// five 190x174 buttons 38px apart, centred; wlogout's own PNG icons (light
// "-rest" on the dark button, dark "-hover" on the light hover fill, mode
// aware); first button focused; keys l e u h r s,
// arrows + Enter, Escape. The backdrop is blurred by the Hyprland layer
// rule for the "orrery-powermenu" namespace, like wlogout's was.
Scope {
    id: scope
    property bool open: false
    property int focused: 0
    onOpenChanged: if (open) focused = 0

    IpcHandler {
        target: "powermenu"
        function toggle(): void { scope.open = !scope.open }
        function close(): void { scope.open = false }
    }

    // the PNGs that came with wlogout, kept next to this file
    readonly property string icons: Qt.resolvedUrl("icons/").toString()
    // keys as in wlogout: l lock, e log out, u sleep (suspend), h hibernate,
    // r restart, s shut down. Hibernate only where the system can (a disk
    // sleep state and swap to write memory to).
    property bool canHibernate: false
    Process {
        running: true
        command: ["sh", "-c", "grep -qw disk /sys/power/state && [ -n \"$(swapon --show --noheadings)\" ]"]
        onExited: (code) => scope.canHibernate = code === 0
    }
    readonly property var actions: [
        { key: "l", icon: "lock",      label: "Lock",      run: () => { scope.open = false; Lock.lock() } },
        { key: "e", icon: "exit",      label: "Log out",   run: () => Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit") },
        { key: "u", icon: "sleep",     label: "Sleep",     run: () => { scope.open = false; Quickshell.execDetached(["systemctl", "suspend"]) } },
        { key: "h", icon: "hibernate", label: "Hibernate", run: () => { scope.open = false; Quickshell.execDetached(["systemctl", "hibernate"]) } },
        { key: "r", icon: "reboot",    label: "Restart",   run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { key: "s", icon: "shutdown",  label: "Shut down", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
    ].filter(a => a.icon !== "hibernate" || scope.canHibernate)
    readonly property int count: actions.length

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: scope.open
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: scope.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "orrery-powermenu"
            // window { background-color: alpha(@bg0, 0.7) }
            color: Theme.alpha(Theme.c.bg0, 0.7)

            MouseArea { anchors.fill: parent; onClicked: scope.open = false }

            Item {
                anchors.fill: parent
                focus: scope.open
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Escape) { scope.open = false; return }
                    if (e.key === Qt.Key_Left || (e.key === Qt.Key_Tab && e.modifiers & Qt.ShiftModifier)) { scope.focused = (scope.focused + scope.count - 1) % scope.count; return }
                    if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) { scope.focused = (scope.focused + 1) % scope.count; return }
                    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { scope.actions[scope.focused].run(); return }
                    const a = scope.actions.find(x => x.key === e.text.toLowerCase())
                    if (a) a.run()
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 38
                    Repeater {
                        model: scope.actions
                        Rectangle {
                            id: btn
                            required property var modelData
                            required property int index
                            readonly property bool hov: m.containsMouse
                            readonly property bool foc: scope.focused === index
                            width: 190; height: 174
                            radius: Theme.radius
                            // button / button:focus / button:hover from the wlogout css
                            color: hov ? Theme.c.fg : foc ? Theme.c.bg2 : Theme.c.bg1
                            border.width: 1
                            border.color: hov ? Theme.c.fg : foc ? Theme.c.borderStrong : Theme.c.border
                            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            // rises in on open, one after another (Motion.effects stagger)
                            opacity: 0
                            transform: Translate { id: rise; y: 16 }
                            states: State { when: scope.open
                                PropertyChanges { btn.opacity: 1 } PropertyChanges { rise.y: 0 } }
                            transitions: Transition { to: "*"
                                SequentialAnimation {
                                    PauseAnimation { duration: scope.open ? btn.index * 35 : 0 }
                                    ParallelAnimation {
                                        NumberAnimation { target: btn; property: "opacity"; duration: Motion.effectsMs }
                                        NumberAnimation { target: rise; property: "y"; duration: Motion.growMs
                                                          easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.growCurve }
                                    }
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 26
                                text: btn.modelData.label
                                font.family: Theme.font; font.pixelSize: Theme.fs(13)
                                color: btn.hov ? Theme.c.bg0 : btn.foc ? Theme.c.fg : Theme.c.accentLight
                            }
                            Image {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -14
                                width: 52; height: 52
                                sourceSize: Qt.size(96, 96)
                                smooth: true
                                // rest → light icon on dark / dark icon on light; hover → the opposite
                                source: scope.icons + btn.modelData.icon + "-" +
                                        (btn.hov ? (Theme.light ? "rest" : "hover")
                                                 : btn.foc ? (Theme.light ? "hover" : "focus")
                                                           : (Theme.light ? "hover" : "rest")) + ".png"
                            }
                            MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onEntered: scope.focused = btn.index
                                        onClicked: btn.modelData.run() }
                        }
                    }
                }
            }
        }
    }
}
