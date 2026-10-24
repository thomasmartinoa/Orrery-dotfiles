pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Coding agents (Claude Code, Codex, OpenCode, …), the Omarchy way: usage
// of the default agent's account in the bar, a panel with plan, limits and
// token counts, right-click to launch. Data comes from
// `orrery-agent usage-update` (~/.local/state/orrery/agents.json),
// refreshed every 15 minutes and whenever the panel opens.
Singleton {
    id: root
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/orrery-agent"
    readonly property string file: Quickshell.env("HOME") + "/.local/state/orrery/agents.json"

    property var data: ({ updated: 0, accounts: [], tokens: { days: [], models: [] } })
    readonly property var accounts: data.accounts || []
    readonly property var noTokens: ({ days: [], models: [], messages: 0, sessions: 0 })
    // the selected agent's own numbers, never another agent's
    readonly property var tokens: (data.tokensByAgent || {})[defaultAgent] || noTokens
    readonly property bool present: accounts.length > 0
    readonly property var primary: accounts.find(a => a.id === defaultAgent) || null
    // the number in the bar: the session limit of the first account
    // Only show a true session quota in the bar. Provider budgets (e.g.
    // OpenRouter's) belong in the panel and must not masquerade as this meter.
    readonly property var session: primary ? (primary.limits || []).find(l => l.name.indexOf("Session") === 0) || null : null
    // the configured default, or the first agent found when it is not installed (any more)
    readonly property string configured: (Config.data.agents && Config.data.agents.default) || ""
    readonly property string defaultAgent: accounts.some(a => a.id === configured) ? configured : (accounts[0] ? accounts[0].id : "")
    function icon(id) { return id === "claude" ? "󰛄" : id === "opencode" ? "code" : id === "codex" ? "terminal" : id === "qwen" ? "smart_toy" : "smart_toy" }
    property bool busy: false
    readonly property int updated: data.updated || 0

    function refresh() { if (!busy) { busy = true; update.running = true } }
    function launch(name) { Quickshell.execDetached([bin, "launch"].concat(name ? [name] : [])) }
    function setDefault(name) { Config.set("agents.default", name) }

    function fmtStat(s) {
        if (s.kind === "usd") return "$" + s.value.toFixed(2)
        return s.kind === "tokens" ? fmtTokens(s.value) : String(s.value)
    }
    function fmtTokens(n) {
        if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
        if (n >= 1e3) return Math.round(n / 1e3) + "K"
        return String(n)
    }
    function resetsIn(iso) {
        if (!iso) return ""
        const ms = new Date(iso).getTime() - Date.now()
        if (isNaN(ms) || ms <= 0) return "resets now"
        const m = Math.round(ms / 60000), h = Math.floor(m / 60), d = Math.floor(h / 24)
        if (d >= 1) return "resets in " + d + "d " + (h % 24) + "h"
        if (h >= 1) return "resets in " + h + "h " + (m % 60) + "m"
        return "resets in " + m + "m"
    }
    function ago() {
        if (!updated) return "never"
        const m = Math.round((Date.now() / 1000 - updated) / 60)
        return m < 1 ? "just now" : m < 60 ? m + "m ago" : Math.round(m / 60) + "h ago"
    }

    Process {
        id: update
        command: [root.bin, "usage-update"]
        onExited: root.busy = false
    }
    FileView {
        id: view
        path: root.file
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.data = JSON.parse(text()) } catch (e) { console.warn("Agents: " + e) } }
        onLoadFailed: root.refresh()
    }
    Timer { interval: 15 * 60 * 1000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()

    IpcHandler {
        target: "agents"
        function refresh(): void { root.refresh() }
        function launch(): void { root.launch("") }
        function session(): string { return root.session ? root.session.percent + "%" : "" }
    }
}
