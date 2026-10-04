import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Commons
import qs.Services
import qs.Panels

Pill {
    id: net
    gap: pillMode ? 13 : 6
    extraRight: pillMode && net.text.length > 12 ? 7 : 0
    // Pick the connected device: wired first, else wifi.
    readonly property var devices: Networking.devices.values
    property var dev: null
    property var network: null
    function refresh() {
        let wired = null, wifi = null
        for (const d of devices) {
            if (!d.connected) continue
            if (d.type === DeviceType.Wired && !wired) wired = d
            if (d.type === DeviceType.Wifi && !wifi) wifi = d
        }
        dev = wired || wifi
        let n = null
        if (dev) for (const x of dev.networks.values) if (x.connected) { n = x; break }
        network = n
    }
    onDevicesChanged: refresh()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: net.refresh() }
    Component.onCompleted: refresh()

    readonly property bool wired: dev && dev.type === DeviceType.Wired
    // Quickshell reports signalStrength as 0..1; bound, so the glyph follows it live
    readonly property int strength: network ? Math.round(network.signalStrength * 100) : 100
    readonly property string icon: !dev ? "wifi_off" : wired ? "lan"
                                   : strength > 75 ? "signal_wifi_4_bar" : strength > 50 ? "network_wifi_3_bar" : strength > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
    // wired: a word, not dev.address (the card's MAC, which also ends up in screenshots)
    readonly property string text: !dev ? "offline" : wired ? "Wired" : (network ? network.name : "wifi")

    onClicked: Panels.toggle("network", net)

    Icon { icon: net.icon; color: net.dev ? Theme.c.accentLight : Theme.c.accentDim }
    Label {
        visible: net.pillMode && !net.vertical
        // waybar's max-length 16 counted the icon and two spaces too
        text: net.text.length > 12 ? net.text.substring(0, 11) + "…" : net.text
        color: net.dev ? Theme.c.accentLight : Theme.c.accentDim
    }

    NetworkPanel { anchorItem: net }
}
