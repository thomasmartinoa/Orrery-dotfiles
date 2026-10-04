// Orrery — SDDM greeter theme matching hyprlock.conf and orrery/palette.css.
//
// Layout mirrors the lock screen: blurred wallpaper, big time up top,
// "Hello, <user>" in the middle, the same 340x62 grey password box under it.
// On top of that it has what a login screen needs and hyprlock doesn't:
// user picker, session picker, and suspend / reboot / shutdown.
//
// SDDM injects: sddm, userModel, sessionModel, keyboard, config.
// Preview without logging out:
//   sddm-greeter-qt6 --test-mode --theme /path/to/orrery

import QtQuick
import QtQuick.Effects

Item {
    id: root
    width: 1920
    height: 1080
    focus: true

    // ----- palette -----
    // theme.conf is rewritten by orrery-root-sync on every theme switch
    // (see sddm-theme.conf.tpl); the literals are the Eclipse dark fallback.
    function col(key, fallback) { var v = config.stringValue(key); return v && v.length > 0 ? v : fallback }
    readonly property bool light:   config.stringValue("mode") === "light"
    readonly property color bg0:    col("bg0",    "#0a0a0a")
    readonly property color bg2:    col("bg2",    "#1e1e1e")
    readonly property color bg3:    col("bg3",    "#282828")
    readonly property color bg4:    col("bg4",    "#333333")
    readonly property color fg:     col("fg",     "#e8e8e8")
    readonly property color bright: col("bright", "#ffffff")
    readonly property color mid:    col("mid",    "#a0a0a0")
    readonly property color dim:    col("dim",    "#606060")
    // text drawn straight on the wallpaper: white on dark themes, near-black on light
    readonly property color onWall: light ? "#141414" : "#ffffff"

    // hyprlock sizes are physical pixels (font_size in points); the greeter's
    // Hyprland runs at scale 1, so they apply as-is. `s` only shrinks the
    // preview window (sddm-greeter-qt6 --test-mode).
    readonly property real s: Math.min(1, Math.min(height / 1080, width / 1920))
    function pt(size) { return size * 4 / 3 * s }
    readonly property string font: config.stringValue("font") || "JetBrainsMono Nerd Font Propo"
    readonly property bool clock12h: config.boolValue("clock12h")

    // ----- state -----
    property int userIndex: 0
    property int sessionIndex: 0
    property bool busy: false
    property string errorText: ""
    property string openPopup: ""        // "", "user", "session"

    readonly property int userCount: users.count
    readonly property int sessionCount: sessions.count
    readonly property string currentUser: userCount > 0 ? users.objectAt(userIndex).name : ""
    readonly property string currentUserPretty: {
        if (userCount === 0) return ""
        var u = users.objectAt(userIndex)
        return u.realName && u.realName.length > 0 ? u.realName : u.name
    }
    readonly property string currentSession: sessionCount > 0 ? sessions.objectAt(sessionIndex).name : ""

    // Read the models through delegates so we never depend on role numbers.
    Instantiator {
        id: users
        model: userModel
        delegate: QtObject {
            required property string name
            required property string realName
            required property bool needsPassword
        }
    }
    Instantiator {
        id: sessions
        model: sessionModel
        delegate: QtObject {
            required property string name
            required property string file
        }
    }

    function pickInitialUser() {
        var last = userModel.lastUser || ""
        for (var i = 0; i < userCount; i++)
            if (users.objectAt(i).name === last) return i
        return 0
    }

    function pickInitialSession() {
        if (sessionModel.lastIndex !== undefined && sessionModel.lastIndex >= 0
                && sessionModel.lastIndex < sessionCount)
            return sessionModel.lastIndex
        var want = config.stringValue("preferSession") || ""
        if (want.length > 0)
            for (var i = 0; i < sessionCount; i++)
                if (sessions.objectAt(i).name.indexOf(want) !== -1) return i
        return 0
    }

    function login() {
        if (busy || userCount === 0) return
        errorText = ""
        busy = true
        sddm.login(currentUser, password.text, sessionIndex)
    }

    function cycleUser(dir) {
        if (userCount < 2) return
        userIndex = (userIndex + dir + userCount) % userCount
        errorText = ""
        password.text = ""
        password.forceActiveFocus()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.errorText = "Wrong password"
            password.text = ""
            shake.restart()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() {
            root.busy = false
            root.errorText = ""
        }
    }

    Component.onCompleted: {
        userIndex = pickInitialUser()
        sessionIndex = pickInitialSession()
        password.forceActiveFocus()
    }

    // Global keys: Esc closes popups / clears, arrows cycle users when
    // the password box is empty.
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (openPopup !== "") openPopup = ""
            else password.text = ""
            event.accepted = true
        }
    }

    // ================================================================
    // Background
    // ================================================================
    Image {
        id: wallpaper
        anchors.fill: parent
        // Overscan past the screen edge so the blur never samples transparent
        // pixels there (that produces a dark vignette around the border).
        anchors.margins: -64
        source: config.stringValue("background") || "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        visible: !config.boolValue("blur")
    }

    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        visible: config.boolValue("blur")
        blurEnabled: true
        blur: 2.0
        blurMax: 48
        // hyprlock: brightness 0.8172, contrast 0.8916
        brightness: root.light ? 0.05 : -0.18
        contrast: -0.1
    }

    // Close popups when clicking anywhere else.
    MouseArea {
        anchors.fill: parent
        enabled: root.openPopup !== ""
        onClicked: root.openPopup = ""
    }

    // ================================================================
    // Clock — hyprlock: 100pt, 90px from top
    // ================================================================
    Timer {
        id: clock
        interval: 1000; running: true; repeat: true
        property date now: new Date()
        onTriggered: now = new Date()
    }

    Column {
        anchors.top: parent.top
        anchors.topMargin: 90 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6 * root.s

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.clock12h ? Qt.formatTime(clock.now, "h:mmAP")
                                : Qt.formatTime(clock.now, "HH:mm")
            font.family: root.font
            font.pixelSize: root.pt(100)
            font.weight: Font.Normal
            color: Qt.rgba(root.onWall.r, root.onWall.g, root.onWall.b, 0.8)
        }
    }

    // ================================================================
    // Center: greeting + password
    // ================================================================
    Item {
        id: center
        anchors.centerIn: parent
        width: 340 * root.s
        height: 220 * root.s

        // "Hello, $USER" — hyprlock: 25pt, centre. Click to switch user.
        Item {
            id: greeting
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: greetRow.width + 24 * root.s
            height: greetRow.height + 10 * root.s

            Rectangle {
                anchors.fill: parent
                radius: 4 * root.s
                color: Qt.rgba(root.onWall.r, root.onWall.g, root.onWall.b, greetHover.containsMouse && root.userCount > 1 ? 0.08 : 0)
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Row {
                id: greetRow
                anchors.centerIn: parent
                spacing: 10 * root.s
                Text {
                    text: "Hello, " + root.currentUserPretty
                    font.family: root.font
                    font.pixelSize: root.pt(25)
                    color: Qt.rgba(root.onWall.r, root.onWall.g, root.onWall.b, 0.8)
                }
                Text {
                    // chevron only when there is someone to switch to
                    visible: root.userCount > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.openPopup === "user" ? "󰅃" : "󰅀"
                    font.family: root.font
                    font.pixelSize: 22 * root.s
                    color: Qt.rgba(root.onWall.r, root.onWall.g, root.onWall.b, 0.5)
                }
            }

            MouseArea {
                id: greetHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.userCount > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (root.userCount > 1)
                               root.openPopup = root.openPopup === "user" ? "" : "user"
            }
        }

        // Password box — hyprlock input-field: 340x62, rounding 5, outline 2,
        // outer rgba(207,207,207,.6), inner rgba(64,64,64,.4), centred dots.
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            y: 75 * root.s
            width: 340 * root.s
            height: 62 * root.s
            radius: 5 * root.s
            color: root.light ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(64/255, 64/255, 64/255, 0.4)
            border.width: 2 * root.s
            border.color: root.errorText !== "" ? Qt.rgba(root.onWall.r, root.onWall.g, root.onWall.b, 0.9)
                        : password.activeFocus ? Qt.rgba(root.mid.r, root.mid.g, root.mid.b, 0.95)
                        : Qt.rgba(root.mid.r, root.mid.g, root.mid.b, 0.7)
            opacity: root.busy ? 0.5 : 1
            Behavior on border.color { ColorAnimation { duration: 120 } }
            Behavior on opacity { NumberAnimation { duration: 120 } }

            // shake on wrong password
            SequentialAnimation {
                id: shake
                loops: 1
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10 * root.s; duration: 40 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to:  10 * root.s; duration: 70 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to:  -6 * root.s; duration: 60 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to:   0;          duration: 50 }
            }

            // dots: size 0.2 x height, spacing = 1.0 x dot
            Row {
                anchors.centerIn: parent
                spacing: field.height * 0.2
                Repeater {
                    model: Math.min(password.text.length, 24)
                    Rectangle {
                        width: field.height * 0.2
                        height: width
                        radius: width / 2
                        color: root.light ? root.fg : "#c8c8c8"
                    }
                }
            }

            TextInput {
                id: password
                anchors.fill: parent
                anchors.margins: 10 * root.s
                echoMode: TextInput.Password
                passwordCharacter: " "
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorVisible: false
                cursorDelegate: Item {}
                font.family: root.font
                font.pixelSize: 24 * root.s
                enabled: !root.busy
                onTextChanged: root.errorText = ""
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.login(); event.accepted = true
                    } else if (text.length === 0 && event.key === Qt.Key_Left) {
                        root.cycleUser(-1); event.accepted = true
                    } else if (text.length === 0 && event.key === Qt.Key_Right) {
                        root.cycleUser(1); event.accepted = true
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: password.forceActiveFocus()
            }
        }

        // status line under the box: error / caps lock / hint
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: field.y + field.height + 14 * root.s
            font.family: root.font
            font.pixelSize: 15 * root.s
            color: Qt.rgba(root.onWall.r, root.onWall.g, root.onWall.b, root.errorText !== "" ? 0.85 : 0.45)
            text: root.busy ? "Logging in…"
                : root.errorText !== "" ? root.errorText
                : keyboard.capsLock ? "󰪛  Caps Lock is on"
                : ""
        }

        // user list popup
        Popup {
            id: userPopup
            visible: root.openPopup === "user"
            anchors.horizontalCenter: parent.horizontalCenter
            y: greeting.y + greeting.height + 6 * root.s
            minWidth: Math.max(260 * root.s, greetRow.width + 60 * root.s)
            model: userModel
            currentIndex: root.userIndex
            labelOf: (m) => (m.realName && m.realName.length > 0) ? m.realName : m.name
            onPicked: (i) => { root.userIndex = i; root.openPopup = ""; password.text = ""; password.forceActiveFocus() }
        }
    }

    // ================================================================
    // Bottom-left: session picker
    // ================================================================
    Item {
        id: sessionPick
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 36 * root.s
        anchors.bottomMargin: 36 * root.s
        width: sessRow.width + 28 * root.s
        height: 44 * root.s

        Rectangle {
            anchors.fill: parent
            radius: 4 * root.s
            color: sessHover.containsMouse || root.openPopup === "session" ? root.bg2 : root.bg0
            opacity: 0.85
            border.width: 1
            border.color: sessHover.containsMouse ? root.bg4 : root.bg3
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Row {
            id: sessRow
            anchors.centerIn: parent
            spacing: 10 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍹"
                font.family: root.font
                font.pixelSize: 18 * root.s
                color: root.mid
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentSession
                font.family: root.font
                font.pixelSize: 15 * root.s
                color: root.fg
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.sessionCount > 1
                text: root.openPopup === "session" ? "󰅀" : "󰅃"
                font.family: root.font
                font.pixelSize: 16 * root.s
                color: root.dim
            }
        }
        MouseArea {
            id: sessHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.sessionCount > 1)
                           root.openPopup = root.openPopup === "session" ? "" : "session"
        }

        Popup {
            visible: root.openPopup === "session"
            anchors.left: parent.left
            y: -height - 8 * root.s
            minWidth: Math.max(260 * root.s, sessRow.width + 80 * root.s)
            model: sessionModel
            currentIndex: root.sessionIndex
            labelOf: (m) => m.name
            onPicked: (i) => { root.sessionIndex = i; root.openPopup = ""; password.forceActiveFocus() }
        }
    }

    // ================================================================
    // Bottom-right: suspend / reboot / shutdown (wlogout icons)
    // ================================================================
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 36 * root.s
        anchors.bottomMargin: 36 * root.s
        spacing: 10 * root.s

        PowerButton { icon: "sleep";    tip: "Suspend";  visible: sddm.canSuspend;  onClicked: sddm.suspend() }
        PowerButton { icon: "reboot";   tip: "Reboot";   visible: sddm.canReboot;   onClicked: sddm.reboot() }
        PowerButton { icon: "shutdown"; tip: "Shutdown"; visible: sddm.canPowerOff; onClicked: sddm.powerOff() }
    }

    // ================================================================
    // Components
    // ================================================================
    component PowerButton: Item {
        id: pb
        property string icon
        property string tip
        signal clicked()
        width: 44 * root.s
        height: 44 * root.s

        // Same states as wlogout/style.css: rest = dark pill + light icon,
        // hover/press = light (#e8e8e8) fill + the dark "-hover" icon.
        readonly property bool lit: pbMouse.containsMouse || pbMouse.pressed
        Rectangle {
            anchors.fill: parent
            radius: 4 * root.s
            color: pb.lit ? root.fg : root.bg0
            opacity: pb.lit ? 1 : 0.85
            border.width: 1
            border.color: pb.lit ? root.fg : root.bg3
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Image {
            anchors.centerIn: parent
            width: 22 * root.s
            height: 22 * root.s
            // "-rest" is the light icon, "-hover" the dark one; pick whichever
            // contrasts with the pill in this mode (as the shell's power menu does).
            source: "icons/" + pb.icon + ((pb.lit !== root.light) ? "-hover" : "-rest") + ".png"
            sourceSize: Qt.size(96, 96)
            smooth: true
        }
        Text {
            anchors.bottom: parent.top
            anchors.bottomMargin: 8 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pb.lit
            text: pb.tip
            font.family: root.font
            font.pixelSize: 13 * root.s
            color: root.mid
        }
        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    // Generic list popup for users / sessions.
    component Popup: Rectangle {
        id: pop
        property var model
        property int currentIndex: -1
        property var labelOf: (m) => ""
        signal picked(int index)

        readonly property real rowHeight: 36 * root.s
        property real minWidth: 260 * root.s
        width: minWidth
        // count-based, not contentHeight: that would be circular with the
        // ListView filling this rectangle and collapse to 0.
        height: list.count * rowHeight + 12 * root.s
        radius: 4 * root.s
        color: root.bg0
        opacity: visible ? 0.95 : 0
        border.width: 1
        border.color: root.bg3
        Behavior on opacity { NumberAnimation { duration: 120 } }

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 6 * root.s
            model: pop.model
            interactive: false
            delegate: Rectangle {
                id: row
                required property int index
                required property var model
                width: list.width
                height: pop.rowHeight
                radius: 4 * root.s
                color: index === pop.currentIndex ? root.bg3 : rowMouse.containsMouse ? root.bg2 : "transparent"
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12 * root.s
                    anchors.rightMargin: 36 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: pop.labelOf(row.model)
                    font.family: root.font
                    font.pixelSize: 15 * root.s
                    color: row.index === pop.currentIndex ? root.bright : root.fg
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.index === pop.currentIndex
                    text: "󰄬"
                    font.family: root.font
                    font.pixelSize: 15 * root.s
                    color: root.mid
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.picked(row.index)
                }
            }
        }
    }
}
