import QtQuick
import qs.Commons
import qs.Services
import qs.Panels

// Agents: the default agent's session usage. Hidden until an agent account
// is found. Click for the panel, right-click launches the default agent.
Pill {
    id: ag
    // The badge is a single composite item, so the Pill's normal inter-widget
    // gap would become an empty trailing gap and pull it off-center.
    gap: 0
    visible: Agents.present
    readonly property int pct: Agents.session ? Agents.session.percent : -1
    // normal colour while there is quota left; dimmed only once the limit is
    // used up (hued themes warn from 90%)
    readonly property color tone: pct >= 100 ? Theme.c.accentDim
                                : Theme.hued && pct >= 90 ? Theme.c.warning : Theme.c.accentLight
    onClicked: Panels.toggle("agents", ag)
    onRightClicked: Agents.launch("")
    // Center the icon and optional percentage as one compact group. With no
    // quota, the badge contracts to the centered icon instead of reserving a
    // blank percentage cell.
    Item {
        id: badge
        readonly property bool showPct: ag.pct >= 0 && !ag.vertical
        width: contents.implicitWidth; height: 18
        implicitWidth: width; implicitHeight: height
        Row {
            id: contents
            anchors.centerIn: parent
            spacing: badge.showPct ? 4 : 0
            Item {
                width: 18; height: 18
                Icon { anchors.centerIn: parent; icon: "󱚝"; size: Theme.fontSize + 1; color: ag.tone }
            }
            Item {
                visible: badge.showPct
                width: pctLabel.width; height: 18
                FixedLabel {
                    id: pctLabel
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: ag.pct + "%"; widest: "100%"; color: ag.tone
                }
            }
        }
    }
    AgentsPanel { anchorItem: ag }
}
