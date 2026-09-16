import QtQuick
import Quickshell
import Quickshell.Io
import "."

ProviderBase {
    id: root
    providerId: "codex"
    name: "Codex"
    icon: "󰚩"

    property string pluginDirectory: ""
    property var services: null
    property var recentProjects: []
    property int recentCount: 10
    property bool notifyWaiting: true
    property bool show5hQuota: true
    property bool showWeeklyQuota: true
    property bool monitorRunning: false

    function bridgePath() { return pluginDirectory + "/providers/codex/codex_bridge.py"; }
    function actionPath() { return pluginDirectory + "/services/agent_action.py"; }
    function terminalCommand() {
        if (!services || !services.config) return "kitty -e";
        const launcher = services.config.getSetting("launcher", {});
        return launcher && launcher.terminalCommand ? launcher.terminalCommand : "kitty -e";
    }
    function applyMessage(line) {
        let msg;
        try { msg = JSON.parse(line); } catch (e) { return; }
        if (msg.type === "snapshot") {
            activeSessions = msg.activeSessions || [];
            recentSessions = msg.recentSessions || [];
            quotaItems = msg.quotaItems || [];
            availableModels = msg.availableModels || [];
            availablePermissions = msg.availablePermissions || [];
            recentProjects = msg.recentProjects || [];
            if (!defaultModel && availableModels.length) {
                const d = availableModels.find(m => m.isDefault);
                defaultModel = d ? d.id : availableModels[0].id;
            }
            if (!defaultPermission && availablePermissions.length) {
                const w = availablePermissions.find(p => p.id === ":workspace" || p.id === "workspace-write");
                defaultPermission = w ? w.id : availablePermissions[0].id;
            }
            ready = true; error = ""; updated();
        } else if (msg.type === "attention") {
            sessionNeedsAttention(msg.session);
            if (notifyWaiting) sendNotification(msg.session);
        } else if (msg.type === "error") error = msg.message || "Codex bridge error";
    }
    function refresh() {
        if (refreshProcess.running) return;
        refreshProcess.command = ["python3", bridgePath(), "--once", "--recent", recentCount.toString()];
        refreshProcess.running = true;
    }
    function restartMonitor() {
        if (monitor.running) monitor.running = false;
        monitor.command = ["python3", bridgePath(), "--recent", recentCount.toString()];
        monitor.running = enabled;
    }
    function resume(session) {
        Quickshell.execDetached(["python3", actionPath(), "resume", "--session", session.id, "--project", session.projectPath || "", "--pid", String(session.processId || 0), "--terminal", terminalCommand()]);
    }
    function focus(session) { resume(session); }
    function launch(project, prompt, model, permission) {
        if (!project) return;
        Quickshell.execDetached(["python3", actionPath(), "launch", "--project", project, "--prompt", prompt || "", "--model", model || "", "--permission", permission || "", "--terminal", terminalCommand()]);
    }
    function sendNotification(session) {
        Quickshell.execDetached(["python3", actionPath(), "notify", "--session", session.id, "--project", session.projectPath || "", "--pid", String(session.processId || 0), "--terminal", terminalCommand(), "--title", session.title || "session"]);
    }
    function getRecentProjects() { return recentProjects; }

    onPluginDirectoryChanged: { if (pluginDirectory !== "" && enabled) restartMonitor(); }
    onEnabledChanged: { if (enabled && pluginDirectory !== "") restartMonitor(); else if (!enabled) monitor.running = false; }

    Process {
        id: monitor
        running: root.enabled && root.pluginDirectory !== ""
        command: ["python3", root.bridgePath(), "--recent", root.recentCount.toString()]
        stdout: SplitParser { onRead: data => root.applyMessage(data) }
        onRunningChanged: root.monitorRunning = running
        onExited: function(code) { if (root.enabled && code !== 0) retry.start(); }
    }
    Process {
        id: refreshProcess
        command: []
        stdout: SplitParser { onRead: data => root.applyMessage(data) }
    }
    Timer { id: retry; interval: 5000; repeat: false; onTriggered: root.restartMonitor() }
}
