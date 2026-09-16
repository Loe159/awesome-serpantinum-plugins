import QtQuick

Item {
    width: 0
    height: 0
    property string providerId: ""
    property string name: ""
    property string icon: "󰚩"
    property bool enabled: true
    property var activeSessions: []
    property var recentSessions: []
    property var quotaItems: []
    property var availableModels: []
    property var availablePermissions: []
    property string defaultModel: ""
    property string defaultPermission: ""
    property bool ready: false
    property string error: ""

    signal sessionNeedsAttention(var session)
    signal updated()

    function refresh() {}
    function launch(project, prompt, model, permission) {}
    function resume(session) {}
    function focus(session) {}
    function getRecentProjects() { return []; }
}
