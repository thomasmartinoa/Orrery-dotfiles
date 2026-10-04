import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Commons
import qs.Bar
import qs.Services

Panel {
    id: p
    name: "network"

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired) || null
    property var networks: []
    property var pskFor: null      // network waiting for a password

    function refresh() {
        if (!wifi) { networks = []; return }
        const seen = {}
        const out = []
        for (const n of wifi.networks.values) {
            if (!n.name || seen[n.name]) continue
            seen[n.name] = true
            out.push(n)
        }
        out.sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
        networks = out
    }
    onOpenChanged: {
        if (wifi) wifi.scannerEnabled = open
        if (open) refresh(); else pskFor = null
    }
    Timer { interval: 2000; running: p.open; repeat: true; onTriggered: p.refresh() }
    // and as soon as a scan reports, not up to 2 s later
    Connections {
        target: p.wifi ? p.wifi.networks : null
        function onValuesChanged() { if (p.open) p.refresh() }
    }
    panelWidth: 340

    // signalStrength is 0..1
    function strengthIcon(v) { const s = v * 100; return s > 75 ? "signal_wifi_4_bar" : s > 50 ? "network_wifi_3_bar" : s > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar" }
    // open and "enhanced open" (OWE) networks take no password
    function isOpen(n) { return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe }
    function tap(n) {
        if (n.connected) { n.disconnect(); return }
        if (n.known || isOpen(n)) { n.connect(); return }
        pskFor = n
    }

    readonly property var current: networks.find(n => n.connected) || null
    readonly property var others: networks.filter(n => !n.connected)

    PanelHeader {
        title: "Wi-Fi"
        detail: Networking.wifiEnabled ? "" : "off"
        showToggle: true
        toggle.on: Networking.wifiEnabled
        onToggled: (on) => Networking.wifiEnabled = on
        actions: [
            IconButton {
                visible: Networking.wifiEnabled
                icon: "refresh"
                RotationAnimation on rotation { running: p.open && p.networks.length === 0 && Networking.wifiEnabled; from: 0; to: 360; duration: 900; loops: Animation.Infinite
                                                 onRunningChanged: if (!running) parent.rotation = 0 }
                onClicked: { if (p.wifi) { p.wifi.scannerEnabled = false; p.wifi.scannerEnabled = true } p.refresh() }
            }
        ]
    }

    PanelRow {
        visible: p.wired && p.wired.connected
        icon: "lan"; title: "Wired"; subtitle: p.wired ? (p.wired.name || "") : ""; active: true; trailing: "connected"
    }

    EmptyState {
        visible: !Networking.wifiEnabled
        icon: "wifi_off"; text: "Wi-Fi is off"; hint: "Turn it on with the switch above"
    }

    // the connected network, with its own card
    Rectangle {
        visible: Networking.wifiEnabled && p.current !== null
        width: parent.width; height: 56
        radius: Theme.radius
        color: Theme.alpha(Theme.c.accentBright, 0.08)
        border.width: 1; border.color: Theme.alpha(Theme.c.accentBright, 0.28)
        PanelRow {
            anchors.left: parent.left; anchors.right: disc.left; anchors.verticalCenter: parent.verticalCenter
            width: undefined
            strength: p.current ? p.current.signalStrength : 0
            title: p.current ? p.current.name : ""
            subtitle: p.current ? "Connected · " + Math.round(p.current.signalStrength * 100) + "%" : ""
            active: true; check: false
            busy: p.current ? p.current.stateChanging : false
            color: "transparent"
        }
        PanelButton {
            id: disc
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            text: "Disconnect"
            onClicked: if (p.current) p.current.disconnect()
        }
    }

    PanelSection { visible: Networking.wifiEnabled && p.others.length > 0; text: "Networks" }
    Label {
        visible: Networking.wifiEnabled && p.networks.length === 0
        text: "Looking for networks…"; font.pixelSize: Theme.fs(12); color: Theme.c.accentMid; leftPadding: 6
    }
    Column {
        width: parent.width; spacing: 2
        visible: Networking.wifiEnabled
        Repeater {
            model: p.others.slice(0, 8)
            Column {
                required property var modelData
                width: parent.width
                PanelRow {
                    strength: modelData.signalStrength
                    title: modelData.name
                    subtitle: modelData.known ? "Saved" : p.isOpen(modelData) ? "Open" : "Secured"
                    trailingIcon: modelData.known || p.isOpen(modelData) ? "" : "lock"
                    busy: modelData.stateChanging
                    onClicked: p.tap(modelData)
                    onRightClicked: if (modelData.known) modelData.forget()
                }
                // password prompt for an unknown secured network
                Rectangle {
                    visible: p.pskFor === modelData
                    width: parent.width; height: 36; radius: Theme.radius
                    color: Theme.c.bg1; border.width: 1; border.color: Theme.c.borderStrong
                    TextInput {
                        id: psk
                        anchors.fill: parent; anchors.margins: 10
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        font.family: Theme.font; font.pixelSize: Theme.fs(12); color: Theme.c.fg
                        focus: p.pskFor === modelData
                        Label { anchors.verticalCenter: parent.verticalCenter; visible: !psk.text; text: "Password, then Enter"; font.pixelSize: Theme.fs(11); color: Theme.c.accentDim }
                        onAccepted: { modelData.connectWithPsk(text); text = ""; p.pskFor = null }
                        Keys.onEscapePressed: p.pskFor = null
                    }
                }
            }
        }
    }

    PanelDivider {}
    Row {
        width: parent.width; spacing: 8; layoutDirection: Qt.RightToLeft
        PanelButton { text: "Network settings"; icon: "settings"; onClicked: { Quickshell.execDetached(["nm-connection-editor"]); Panels.close() } }
    }
}
