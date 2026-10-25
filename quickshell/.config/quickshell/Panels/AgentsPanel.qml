import QtQuick
import Quickshell
import qs.Commons
import qs.Bar
import qs.Services

// Agent usage: one tab per coding agent found on this PC. Tabs only change
// what the panel shows; the star makes an agent the default (the bar's
// number, and what a right-click launches). Two looks, switched with the
// button in the title: "detailed" (limits, facts, a labelled week chart and
// models) and "minimal" (limits, a sparkline, one line of facts). Every
// section keeps the same height whichever agent is shown, so switching tabs
// never makes the panel jump.
Panel {
    id: p
    name: "agents"
    panelWidth: 380
    // on open, but not more than every 2 minutes: the usage API rate-limits
    onOpenChanged: {
        if (!open) return
        Agents.viewing = ""     // always open on the default agent
        if (Date.now() / 1000 - Agents.updated > 120) Agents.refresh()
    }

    // ticks the countdowns while open
    property int now: 0
    Timer { interval: 30000; running: p.open; repeat: true; onTriggered: p.now++ }

    readonly property bool mini: Agents.style === "minimal"
    readonly property var acct: Agents.viewAccount
    readonly property bool isDefault: Agents.viewId === Agents.defaultAgent
    readonly property var days: {
        const d = Agents.tokens.days || []
        return d.length === 7 ? d : [0, 1, 2, 3, 4, 5, 6].map(i => d[i] || { date: "", total: 0, output: 0 })
    }
    readonly property real dayMax: Math.max(1, ...days.map(d => d.total))
    readonly property real week: days.reduce((s, d) => s + d.total, 0)
    readonly property int modelRows: 4
    readonly property var topModel: (Agents.tokens.models || [])[0] || null
    readonly property real modelTotal: (Agents.tokens.models || []).reduce((s, m) => s + m.total, 0)
    // quota colour: calm until it matters. Hued themes warn at 75% and go red at 90%;
    // the grey themes dim the figure instead of using colour.
    function tone(pc) { return Theme.hued ? (pc >= 90 ? Theme.c.critical : pc >= 75 ? Theme.c.warning : Theme.c.accentBright)
                                          : (pc >= 90 ? Theme.c.accentDim : Theme.c.accentBright) }
    readonly property color warnColor: Theme.hued ? Theme.c.warning : Theme.c.accentBright
    // index of the bar under the mouse (-1 none): its day replaces the weekly total
    property int hoverDay: -1
    function stat(i) { const s = ((acct && acct.stats) || [])[i]; return s ? Agents.fmtStat(s) : "–" }
    function statLabel(i) { const s = ((acct && acct.stats) || [])[i]; return s ? s.label.toLowerCase() : "" }

    // the panel's rows are sized from one real line of text
    Label { id: line; visible: false; font.pixelSize: Theme.fs(11); text: "Ag" }
    readonly property real limitH: line.implicitHeight + 4 + 6                   // name row, gap, bar
    function headHeight(a) {                                                     // limits + notes of one agent
        if (!a) return 0
        const n = (a.limits || []).length
        let h = n * limitH + Math.max(0, n - 1) * 8
        for (const t of [a.error, a.note, a.providerDetail, a.extra ? "x" : ""]) if (t) h += line.implicitHeight + 8
        return h
    }
    readonly property real headReserve: Math.max(line.implicitHeight + 8, ...Agents.accounts.map(a => headHeight(a)))
    readonly property real miniLimitH: line.implicitHeight + 4 + 4
    function miniHeight(a) {                                                     // minimal: limits, or one summary line, + a warning line
        if (!a) return 0
        const n = Math.max(1, (a.limits || []).length)
        return n * miniLimitH + (n - 1) * 8 + (a.error || a.warn ? line.implicitHeight + 8 : 0)
    }
    readonly property real miniReserve: Math.max(line.implicitHeight, ...Agents.accounts.map(a => miniHeight(a)))

    // fade the details when another agent is shown
    property real fade: 1
    NumberAnimation { id: fadeIn; target: p; property: "fade"; from: 0.25; to: 1; duration: 180; easing.type: Easing.OutCubic }
    Connections { target: Agents; function onViewIdChanged() { fadeIn.restart() } }

    PanelHeader {
        title: "Agent usage"
        actions: [
            // offers the other look
            Item {
                width: modeLbl.implicitWidth + 16; height: 28
                Label { id: modeLbl; anchors.centerIn: parent; text: p.mini ? "Detailed" : "Minimal"; font.pixelSize: Theme.fs(11)
                        color: modeHover.containsMouse ? Theme.c.fg : Theme.c.accentMid }
                MouseArea { id: modeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Agents.setStyle(p.mini ? "detailed" : "minimal") }
            }
        ]
    }

    // ---- tabs ----------------------------------------------------------
    // detailed: buttons
    Row {
        visible: !p.mini
        width: parent.width; spacing: 6
        Repeater {
            model: Agents.accounts
            PanelButton {
                required property var modelData
                width: (parent.width - 6 * (Agents.accounts.length - 1)) / Math.max(1, Agents.accounts.length)
                icon: Agents.icon(modelData.id)
                text: Agents.accounts.length > 2 ? modelData.name.replace(/ (Code|CLI)$/, "") : modelData.name
                primary: modelData.id === Agents.viewId
                onClicked: Agents.viewing = modelData.id
                // the default agent carries a small dot
                Rectangle { visible: modelData.id === Agents.defaultAgent; width: 6; height: 6; radius: 3
                            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 5
                            color: parent.primary ? Theme.c.bg0 : Theme.c.accentBright }
            }
        }
    }
    // minimal: plain words with an underline
    Row {
        visible: p.mini
        width: parent.width; spacing: 18
        Repeater {
            model: Agents.accounts
            Item {
                id: tab
                required property var modelData
                readonly property bool sel: modelData.id === Agents.viewId
                width: tabRow.implicitWidth; height: 24
                Row {
                    id: tabRow
                    anchors.verticalCenter: parent.verticalCenter; spacing: 5
                    Rectangle { visible: tab.modelData.id === Agents.defaultAgent; anchors.verticalCenter: parent.verticalCenter
                                width: 5; height: 5; radius: 3; color: Theme.c.accentBright }
                    Label { text: tab.modelData.name.replace(/ (Code|CLI)$/, ""); font.pixelSize: Theme.fs(12)
                            font.weight: tab.sel ? Font.DemiBold : Font.Normal
                            color: tab.sel ? Theme.c.fg : Theme.c.accentMid }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1
                            color: Theme.c.accentBright; opacity: tab.sel ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Motion.fadeMs } } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Agents.viewing = tab.modelData.id }
            }
        }
    }

    // =====================================================================
    // DETAILED
    // =====================================================================
    Column {
        width: parent.width; spacing: 8
        opacity: p.fade
        visible: Agents.present && !p.mini

        // ---- name and plan -------------------------------------------
        Row {
            width: parent.width
            Label { text: p.acct ? p.acct.name : ""; font.pixelSize: Theme.fs(13); font.weight: Font.DemiBold; color: Theme.c.fg
                    width: parent.width - plan.width - (site.visible ? site.width + 6 : 0) }
            // the provider's own usage page, for the numbers this panel can't see
            Rectangle {
                id: site
                visible: !!p.acct && !!p.acct.url
                width: 22; height: 18; radius: Theme.radiusSm
                color: siteHover.containsMouse ? Theme.c.bg3 : Theme.c.bg2; border.width: 1; border.color: Theme.c.border
                Icon { anchors.centerIn: parent; icon: "open_in_new"; size: Theme.fs(11); color: Theme.c.accentMid }
                MouseArea { id: siteHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { Agents.openUrl(p.acct.url); Panels.close() } }
            }
            Item { visible: site.visible; width: 6; height: 1 }
            Rectangle {
                id: plan
                visible: !!p.acct && p.acct.plan !== ""
                width: planLbl.implicitWidth + 12; height: 18; radius: Theme.radiusSm
                color: Theme.c.bg2; border.width: 1; border.color: Theme.c.border
                Label { id: planLbl; anchors.centerIn: parent; text: p.acct ? p.acct.plan : ""; font.pixelSize: Theme.fs(10); color: Theme.c.accentMid }
            }
        }

        // ---- limits, notes -------------------------------------------
        Item {
            width: parent.width
            height: Math.max(p.headReserve, head.implicitHeight)
            Column {
                id: head
                width: parent.width; spacing: 8
                Label { visible: !!p.acct && p.acct.error !== ""; width: parent.width; wrapMode: Text.Wrap
                        text: p.acct ? p.acct.error : ""; font.pixelSize: Theme.fs(11); color: p.warnColor }
                Label { visible: !!p.acct && !!p.acct.note; width: parent.width; elide: Text.ElideRight
                        text: p.acct ? (p.acct.note || "") : ""; font.pixelSize: Theme.fs(11)
                        color: p.acct && p.acct.warn ? p.warnColor : Theme.c.accentMid }
                Repeater {
                    model: p.acct ? p.acct.limits : []
                    Column {
                        required property var modelData
                        width: parent.width; spacing: 4
                        Row {
                            width: parent.width
                            Label { text: modelData.name; font.pixelSize: Theme.fs(11); color: Theme.c.fg
                                    width: Math.max(0, parent.width - pct.width - reset.width); elide: Text.ElideRight }
                            Label { id: reset; text: { void p.now; return Agents.resetsIn(modelData.resets_at) } font.pixelSize: Theme.fs(11); color: Theme.c.accentMid; rightPadding: 8 }
                            Label { id: pct; text: modelData.percent + "%"; font.pixelSize: Theme.fs(11); font.weight: Font.DemiBold
                                    color: p.tone(modelData.percent) }
                        }
                        // the window's clock is the lighter stretch of the track: a fill that
                        // runs past it means the limit is being used faster than time passes
                        Rectangle {
                            width: parent.width; height: 6; radius: 3; color: Theme.c.bg2
                            Rectangle { visible: modelData.elapsed !== undefined; height: parent.height; radius: 3
                                        width: parent.width * (modelData.elapsed || 0) / 100
                                        color: Theme.alpha(Theme.c.accentMid, 0.22) }
                            Rectangle { width: Math.max(6, parent.width * Math.min(100, modelData.percent) / 100); height: parent.height; radius: 3
                                        color: p.tone(modelData.percent)
                                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } }
                        }
                    }
                }
                Label {
                    visible: !!p.acct && !!p.acct.extra
                    text: p.acct && p.acct.extra ? "Extra usage: " + (p.acct.extra.used ?? 0) + " / " + (p.acct.extra.limit ?? "∞") + " " + p.acct.extra.currency : ""
                    font.pixelSize: Theme.fs(11); color: Theme.c.accentMid
                }
                Label {
                    visible: !!p.acct && !!p.acct.providerDetail
                    width: parent.width; wrapMode: Text.Wrap
                    text: p.acct ? (p.acct.providerDetail || "") : ""
                    font.pixelSize: Theme.fs(11); color: Theme.c.accentMid
                }
            }
        }

        // ---- facts: today, replies, sessions (or cost) ----------------
        Row {
            width: parent.width; spacing: 6
            Repeater {
                model: p.acct && p.acct.stats ? p.acct.stats : []
                Rectangle {
                    required property var modelData
                    width: (parent.width - 12) / 3; height: 38; radius: Theme.radiusSm
                    color: Theme.c.bg2; border.width: 1; border.color: Theme.c.border
                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: Agents.fmtStat(modelData)
                                font.pixelSize: Theme.fs(13); font.weight: Font.DemiBold; color: Theme.c.fg }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label
                                font.pixelSize: Theme.fs(10); color: Theme.c.accentMid }
                    }
                }
            }
        }
    }

    // =====================================================================
    // MINIMAL
    // =====================================================================
    Column {
        width: parent.width; spacing: 12
        opacity: p.fade
        visible: Agents.present && p.mini

        Item {
            width: parent.width
            height: Math.max(p.miniReserve, mhead.implicitHeight)
            Column {
                id: mhead
                width: parent.width; spacing: 8
                Label { visible: !!p.acct && (p.acct.error !== "" || !!p.acct.warn); width: parent.width; elide: Text.ElideRight
                        text: p.acct ? (p.acct.error || p.acct.note || "") : ""; font.pixelSize: Theme.fs(11); color: p.warnColor }
                Repeater {
                    model: p.acct ? p.acct.limits : []
                    Column {
                        required property var modelData
                        width: parent.width; spacing: 4
                        Row {
                            width: parent.width
                            Label { text: modelData.name; font.pixelSize: Theme.fs(11); color: Theme.c.fg
                                    width: parent.width - right.width; elide: Text.ElideRight }
                            Label { id: right; font.pixelSize: Theme.fs(11)
                                    text: { void p.now; const r = Agents.resetsIn(modelData.resets_at); return modelData.percent + "%" + (r ? "  ·  " + r.replace("resets in ", "") : "") }
                                    font.weight: modelData.percent >= 75 ? Font.DemiBold : Font.Normal
                                    color: modelData.percent >= 75 ? p.tone(modelData.percent) : Theme.c.accentMid }
                        }
                        Rectangle {
                            width: parent.width; height: 4; radius: 2; color: Theme.c.bg2
                            Rectangle { visible: modelData.elapsed !== undefined; height: parent.height; radius: 2
                                        width: parent.width * (modelData.elapsed || 0) / 100
                                        color: Theme.alpha(Theme.c.accentMid, 0.22) }
                            Rectangle { width: Math.max(4, parent.width * Math.min(100, modelData.percent) / 100); height: parent.height; radius: 2
                                        color: p.tone(modelData.percent)
                                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } }
                        }
                    }
                }
                // an agent without a quota: its numbers in one line instead
                Label { visible: !!p.acct && (p.acct.limits || []).length === 0; width: parent.width; elide: Text.ElideRight
                        text: p.stat(0) + " " + p.statLabel(0) + "  ·  " + p.stat(1) + " " + p.statLabel(1)
                        font.pixelSize: Theme.fs(12); color: Theme.c.fg }
            }
        }

        // a week as seven small bars, the total at the right
        Row {
            width: parent.width; spacing: 10
            Row {
                id: spark
                width: parent.width - wkMini.width - 10; height: 26; spacing: 4
                readonly property real bw: (width - spacing * 6) / 7
                Repeater {
                    model: 7
                    Item {
                        id: sb
                        required property int index
                        width: spark.bw; height: spark.height
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width; radius: 2
                            height: Math.max(2, parent.height * p.days[sb.index].total / p.dayMax)
                            color: sb.index === p.hoverDay || (p.hoverDay < 0 && sb.index === 6) ? Theme.c.accentBright : Theme.alpha(Theme.c.accentMid, 0.55)
                            Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        }
                        MouseArea { anchors.fill: parent; hoverEnabled: true
                                    onEntered: p.hoverDay = sb.index
                                    onExited: if (p.hoverDay === sb.index) p.hoverDay = -1 }
                    }
                }
            }
            // fixed width (the widest text it can show), right-aligned, so hovering a
            // day never resizes the sparkline beside it
            Label { id: wkMini; anchors.bottom: parent.bottom; width: wkMetrics.width; horizontalAlignment: Text.AlignRight
                    text: p.hoverDay < 0 ? Agents.fmtTokens(p.week) + " / 7d"
                          : Qt.formatDate(new Date(p.days[p.hoverDay].date + "T12:00:00"), "ddd") + " " + Agents.fmtTokens(p.days[p.hoverDay].total)
                    font.pixelSize: Theme.fs(11); color: Theme.c.accentMid }
            TextMetrics { id: wkMetrics; font.family: wkMini.font.family; font.pixelSize: Theme.fs(11); text: "999.9M / 7d" }
        }

        // the busiest model and the session count (or cost)
        Row {
            width: parent.width; spacing: 0
            Label { id: topName; width: Math.min(implicitWidth, parent.width - topRest.implicitWidth); elide: Text.ElideRight
                    font.pixelSize: Theme.fs(11); color: Theme.c.fg; text: p.topModel ? p.topModel.model : "No usage this week" }
            Label { id: topRest; visible: !!p.topModel; font.pixelSize: Theme.fs(11); color: Theme.c.accentMid
                    text: p.topModel ? "  ·  " + Math.round(100 * p.topModel.total / Math.max(1, p.modelTotal)) + "%  ·  " + p.stat(2) + " " + p.statLabel(2) : "" }
        }
    }

    Label {
        visible: !Agents.present
        width: parent.width; wrapMode: Text.Wrap
        text: "No coding agent found. Install one (Claude Code, OpenCode, Codex, Qwen Code…) and its usage appears here."
        font.pixelSize: Theme.fs(12); color: Theme.c.accentMid
    }

    Rectangle { visible: Agents.present && !p.mini; width: parent.width; height: 1; color: Theme.c.bg3 }

    // ---- detailed: tokens by day, seven bars that always exist ---------
    Column {
        visible: Agents.present && !p.mini
        width: parent.width; spacing: 6
        opacity: p.fade
        Row {
            width: parent.width
            Label { text: p.hoverDay < 0 ? "Tokens (with cache) · last 7 days" : Qt.formatDate(new Date(p.days[p.hoverDay].date + "T12:00:00"), "dddd d MMM")
                    font.pixelSize: Theme.fs(11); color: Theme.c.accentMid; width: parent.width - wk.width }
            Label { id: wk; text: Agents.fmtTokens(p.hoverDay < 0 ? p.week : p.days[p.hoverDay].total)
                    font.pixelSize: Theme.fs(11); color: Theme.c.fg }
        }
        Row {
            id: chart
            width: parent.width; height: 56; spacing: 6
            readonly property real bw: (width - spacing * 6) / 7
            Repeater {
                model: 7
                Item {
                    id: bar
                    required property int index
                    readonly property var day: p.days[index]
                    width: chart.bw; height: chart.height
                    Column {
                        anchors.fill: parent; spacing: 3
                        Item {
                            width: parent.width; height: parent.height - 14
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width
                                height: Math.max(2, parent.height * bar.day.total / p.dayMax)
                                radius: 2
                                color: bar.index === p.hoverDay || (p.hoverDay < 0 && bar.index === 6) ? Theme.c.accentBright : Theme.c.accentMid
                                Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                            }
                        }
                        Label { anchors.horizontalCenter: parent.horizontalCenter
                                text: bar.day.date ? Qt.formatDate(new Date(bar.day.date + "T12:00:00"), "ddd").slice(0, 2) : ""
                                font.pixelSize: Theme.fs(10.5); color: bar.index === 6 ? Theme.c.fg : Theme.c.accentMid }
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true
                                onEntered: p.hoverDay = bar.index
                                onExited: if (p.hoverDay === bar.index) p.hoverDay = -1 }
                }
            }
        }
    }

    // ---- detailed: tokens by model, always four rows tall ---------------
    Column {
        visible: Agents.present && !p.mini
        width: parent.width; spacing: 4
        opacity: p.fade
        Label { text: "By model"; font.pixelSize: Theme.fs(11); color: Theme.c.accentMid }
        Repeater {
            model: p.modelRows
            Item {
                required property int index
                readonly property var m: (Agents.tokens.models || [])[index]
                width: parent.width; height: line.implicitHeight
                Label { text: m ? m.model : index === 0 ? "No usage yet" : ""; font.pixelSize: Theme.fs(11); color: m ? Theme.c.fg : Theme.c.accentMid
                        width: parent.width - tot.width - 8; elide: Text.ElideRight }
                Label { id: tot; visible: !!m; anchors.right: parent.right
                        text: m ? Agents.fmtTokens(m.total) + "  ·  " + Agents.fmtTokens(m.output) + " out" : ""
                        font.pixelSize: Theme.fs(11); color: Theme.c.accentMid }
            }
        }
    }

    Rectangle { visible: !p.mini; width: parent.width; height: 1; color: Theme.c.bg3 }

    // ---- footer: launch the agent being shown, star = default, refresh ---
    Row {
        width: parent.width; spacing: 6
        Column {
            width: parent.width - launch.width - refresh.width - star.width - 18
            anchors.verticalCenter: parent.verticalCenter; spacing: 1
            Label { visible: !p.mini; width: parent.width; elide: Text.ElideRight; font.pixelSize: Theme.fs(12); color: Theme.c.fg
                    text: p.isDefault ? "Default agent" : "Not the default" }
            Label { width: parent.width; elide: Text.ElideRight; font.pixelSize: Theme.fs(10)
                    text: { void p.now; return Agents.busy ? "updating…" : "updated " + Agents.ago() }
                    color: !Agents.busy && Date.now() / 1000 - Agents.updated > 1800 ? p.warnColor : Theme.c.accentMid }
        }
        // the star: this agent is the default (filled) or becomes it
        IconButton { id: star; icon: "star"; active: p.isDefault; iconSize: Theme.fs(17)
                     anchors.verticalCenter: parent.verticalCenter; enabled: !p.isDefault
                     onClicked: Agents.setDefault(Agents.viewId) }
        PanelButton { id: refresh; icon: Agents.busy ? "sync" : "refresh"; onClicked: Agents.refresh() }
        PanelButton { id: launch; icon: "rocket_launch"; text: "Launch"; primary: true; enabled: Agents.viewId !== ""
                      onClicked: { Agents.launch(Agents.viewId); Panels.close() } }
    }
}
