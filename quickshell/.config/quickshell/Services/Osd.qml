pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// On-screen display for volume / brightness. Volume comes straight from
// pipewire (any change, keyboard or panel); brightness is pushed by
// ~/.config/hypr/scripts/brightness.sh over IPC because sysfs does not
// notify.
Singleton {
    id: root
    property string kind: "volume"     // volume | mic | brightness | colours
    property real value: 0             // 0..1
    property bool muted: false
    property bool visible: false
    property bool armed: false         // ignore the initial pipewire values

    function show(k, v, m) {
        kind = k; value = v; muted = !!m
        visible = true
        hide.restart()
    }
    Timer { id: hide; interval: 1400; onTriggered: root.visible = false }
    // colours from the wallpaper: shown while they're being applied (a few
    // seconds), then "applied" for a moment
    property bool working: false
    function colours(on) {
        kind = "colours"; working = on; visible = true
        if (on) hide.stop(); else hide.restart()
    }
    Timer { interval: 2000; running: true; onTriggered: root.armed = true }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source] }
    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() { if (root.armed) root.show("volume", root.sink.audio.volume, root.sink.audio.muted) }
        function onMutedChanged()  { if (root.armed) root.show("volume", root.sink.audio.volume, root.sink.audio.muted) }
    }
    Connections {
        target: root.source ? root.source.audio : null
        function onMutedChanged()  { if (root.armed) root.show("mic", root.source.audio.volume, root.source.audio.muted) }
    }

    IpcHandler {
        target: "osd"
        function brightness(percent: string): void { root.show("brightness", Math.max(0, Math.min(100, parseFloat(percent))) / 100, false) }
        function volume(): void { if (root.sink) root.show("volume", root.sink.audio.volume, root.sink.audio.muted) }
    }
}
