import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "ui" as UI

Item {
    id: root
    width: 0
    height: 0

    property var pluginMetadata: ({})
    property string pluginDirectory: ""
    property var hostServices: null

    property var tasks: []
    property var projects: []
    property bool connected: false
    property bool authorizing: false
    property bool stale: false
    property bool refreshPending: false
    property bool panelVisible: false
    property bool panelOpen: false
    property bool settingsOpen: false
    property bool editorOpen: false
    property bool editingExisting: false
    property string errorMessage: ""
    property string successMessage: ""
    property string lastCompletedId: ""
    property string activeTab: "today"
    property string selectedProject: ""
    property string panelSection: "center"
    property string panelBarPosition: "top"
    property real panelBarThickness: 40
    property var panelScreen: null
    property string editorId: ""
    property string editorTitle: ""
    property string editorDescription: ""
    property string editorDue: ""
    property string editorProject: ""
    property int editorPriority: 4
    property bool projectPickerOpen: false
    property int settingsRevision: 0

    readonly property var overdueTasks: tasks.filter(t => t.overdue)
    readonly property var todayTasks: tasks.filter(t => t.today && !t.overdue)
    readonly property var upcomingTasks: tasks.filter(t => t.dueDate && !t.today && !t.overdue)
    readonly property var inboxTasks: tasks.filter(t => t.inbox)
    readonly property var selectedProjectTasks: tasks.filter(t => t.projectId === selectedProject)
    readonly property int todayCount: tasks.filter(t => t.today).length

    QtObject {
        id: fallbackTheme
        property color base: "#1e1e2e"
        property color surface0: "#313244"
        property color surface1: "#45475a"
        property color text: "#cdd6f4"
        property color subtext0: "#a6adc8"
        property color overlay1: "#7f849c"
        property color mauve: "#cba6f7"
        property color red: "#f38ba8"
        property color yellow: "#f9e2af"
        property color green: "#a6e3a1"
        property string fontFamily: "sans-serif"
        property real borderRadius: 10
    }
    readonly property var theme: hostServices && hostServices.theme ? hostServices.theme : fallbackTheme
    function s(value) { return hostServices && hostServices.scaler ? hostServices.scaler.s(value) : value; }
    function settings() {
        const manager = hostServices && hostServices.pluginManager;
        return manager ? manager.pluginSettings("todoist") : {};
    }
    function setting(name, defaultValue) {
        const dummy = settingsRevision;
        const value = settings()[name];
        return value === undefined ? defaultValue : value;
    }
    function setSetting(name, value) {
        if (hostServices && hostServices.pluginManager)
            hostServices.pluginManager.updatePluginSetting("todoist", name, value);
        settingsRevision++;
        refresh();
    }

    Connections {
        target: root.hostServices ? root.hostServices.config : null
        ignoreUnknownSignals: true
        function onSettingsLoaded() { root.settingsRevision++; }
        function onRawSettingsChanged() { root.settingsRevision++; }
    }

    function syncPanelContext(host) {
        if (host && host.barSection) panelSection = host.barSection;
        else if (hostServices && hostServices.pluginManager)
            panelSection = hostServices.pluginManager.barModuleSection("plugin:todoist") || "center";
        else panelSection = "center";

        if (host && host.barWindow) {
            panelBarPosition = host.barWindow.barPosition || "top";
            panelBarThickness = host.barWindow.barHeight || 40;
            panelScreen = host.barWindow.screen || null;
        } else {
            const cfg = hostServices && hostServices.config ? hostServices.config.getSetting("bar", {}) : {};
            panelBarPosition = cfg.position || "top";
            panelBarThickness = cfg.height || 40;
            if (!panelScreen && Quickshell.screens && Quickshell.screens.length)
                panelScreen = Quickshell.screens[0];
        }
    }
    function activateBar(host) {
        if (panelOpen) {
            closePanel();
            return;
        }
        syncPanelContext(host);
        activeTab = "today";
        selectedProject = "";
        settingsOpen = false;
        editorOpen = false;
        panelVisible = true;
        openDelay.restart();
        refresh();
    }
    function closePanel() {
        openDelay.stop();
        panelOpen = false;
        hideDelay.restart();
    }

    function refresh() {
        if (statusProcess.running) { refreshPending = true; return; }
        if (!pluginDirectory) return;
        statusProcess.command = ["python3", pluginDirectory + "/services/todoist.py", "status",
            JSON.stringify({
                reminderMinutes: setting("reminderMinutes", 30),
                notifyDue: setting("notifyDue", true),
                notifyOverdue: setting("notifyOverdue", true)
            })];
        statusProcess.running = true;
    }
    function action(op, values) {
        if (actionProcess.running || !pluginDirectory) return;
        errorMessage = "";
        successMessage = "";
        actionProcess.command = ["python3", pluginDirectory + "/services/todoist.py",
            op, JSON.stringify(values || {})];
        actionProcess.running = true;
    }
    function connectTodoist() {
        if (authorizing || connected) return;
        authorizing = true;
        errorMessage = "";
        try {
            Quickshell.execDetached(["python3", pluginDirectory + "/services/todoist.py", "login"]);
        } catch (e) {
            authorizing = false;
            errorMessage = "Impossible de lancer l'authentification : " + String(e);
        }
    }
    function quickAdd() {
        const input = quickInput.text.trim();
        if (!input || actionProcess.running) return;
        action("quick", {text: input});
        quickInput.text = "";
    }
    function createEditor(task) {
        const t = task || null;
        editorOpen = true;
        settingsOpen = false;
        projectPickerOpen = false;
        editingExisting = !!t;
        editorId = t ? t.id : "";
        editorTitle = t ? t.content : "";
        editorDescription = t ? t.description : "";
        editorDue = t ? (t.dueString || t.dueDatetime || t.dueDate) : "";
        editorPriority = t ? t.priority : 4;
        editorProject = t ? t.projectId : "";
    }
    function submitEditor() {
        if (!editorTitle.trim()) { errorMessage = "Le titre est obligatoire."; return; }
        const body = {content: editorTitle.trim(), description: editorDescription,
            priority: editorPriority};
        if (editorDue.trim()) body.due_string = editorDue.trim();
        if (!editingExisting) {
            if (editorProject) body.project_id = editorProject;
            action("create", body);
        } else {
            body.id = editorId;
            action("update", body);
            const oldTask = tasks.find(t => t.id === editorId);
            if (editorProject && oldTask && editorProject !== oldTask.projectId) {
                // A project move is a separate API action; execute it after the update.
                pendingMoveId = editorId;
                pendingMoveProject = editorProject;
            }
        }
        editorOpen = false;
    }
    property string pendingMoveId: ""
    property string pendingMoveProject: ""
    function completeTask(id) {
        lastCompletedId = id;
        action("close", {id: id});
    }
    function renameTask(id, title) {
        if (title.trim()) action("update", {id: id, content: title.trim()});
    }
    function postponeTask(id) {
        action("update", {id: id, due_string: "tomorrow"});
    }
    function cyclePriority(task) {
        action("update", {id: task.id, priority: task.priority === 1 ? 4 : task.priority - 1});
    }
    function projectLabel(id) {
        if (!id) return "Boîte de réception";
        const p = projects.find(p => String(p.id) === String(id));
        return p ? p.name : "Projet";
    }

    Timer { id: openDelay; interval: 12; onTriggered: root.panelOpen = true }
    Timer { id: hideDelay; interval: 170; onTriggered: if (!root.panelOpen) root.panelVisible = false }
    Timer {
        interval: Math.max(1, Math.min(60, Number(root.setting("syncIntervalMinutes", 5)) || 5)) * 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 4000
        running: root.authorizing
        repeat: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: refresh()

    Process {
        id: statusProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.connected = !!data.connected;
                    root.authorizing = !!data.authorizing;
                    root.stale = !!data.stale;
                    root.tasks = data.tasks || [];
                    root.projects = data.projects || [];
                    if (data.error) root.errorMessage = data.error;
                    else if (!actionProcess.running) root.errorMessage = "";
                } catch (e) {
                    root.errorMessage = "Réponse du service Todoist invalide.";
                    root.stale = true;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim()) console.warn("Todoist: process error")
        }
        onExited: function(code) {
            if (code !== 0) { root.stale = true; root.errorMessage = "Actualisation Todoist impossible."; }
            if (root.refreshPending) { root.refreshPending = false; Qt.callLater(root.refresh); }
        }
    }
    Process {
        id: actionProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(this.text);
                    if (response.error || response.ok === false) root.errorMessage = response.error || "Action échouée.";
                    else root.successMessage = "Enregistré.";
                } catch (e) { root.errorMessage = "Réponse Todoist invalide."; }
            }
        }
        onExited: function(code) {
            if (code !== 0) {
                root.pendingMoveId = "";
                root.pendingMoveProject = "";
                if (!root.errorMessage) root.errorMessage = "Action Todoist impossible.";
            }
            if (code === 0 && root.pendingMoveId) {
                const id = root.pendingMoveId;
                const project = root.pendingMoveProject;
                root.pendingMoveId = "";
                root.pendingMoveProject = "";
                Qt.callLater(() => root.action("move", {id: id, project_id: project}));
            }
            root.refresh();
        }
    }

    PanelWindow {
        id: panel
        visible: root.panelVisible
        screen: root.panelScreen || (Quickshell.screens && Quickshell.screens.length ? Quickshell.screens[0] : null)
        color: "transparent"
        WlrLayershell.namespace: "serpantinum-plugin-todoist"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region { item: root.panelVisible ? dismissSurface : null }

        Item {
            id: dismissSurface
            anchors.fill: parent
            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) {
                    if (mouse.x < card.x || mouse.x > card.x + card.width ||
                            mouse.y < card.y || mouse.y > card.y + card.height)
                        root.closePanel();
                }
            }
        }
        Rectangle {
            id: card
            z: 1
            width: Math.min(root.s(455), Math.max(root.s(300), panel.width - root.s(24)))
            height: Math.min(root.s(620), panel.height - root.s(60) -
                             ((root.panelBarPosition === "top" || root.panelBarPosition === "bottom") ? root.panelBarThickness : 0))
            radius: Math.max(root.s(12), root.s(root.theme.borderRadius * 1.7))
            color: root.theme.base
            border.width: root.s(1)
            border.color: root.theme.surface1
            x: {
                const gap = root.s(12);
                if (root.panelBarPosition === "left") return root.panelBarThickness + gap;
                if (root.panelBarPosition === "right") return Math.max(gap, panel.width - width - root.panelBarThickness - gap);
                if (root.panelSection === "left") return gap;
                if (root.panelSection === "right") return Math.max(gap, panel.width - width - gap);
                return Math.max(gap, (panel.width - width) / 2);
            }
            y: {
                const gap = root.s(12);
                if (root.panelBarPosition === "top") return root.panelBarThickness + gap;
                if (root.panelBarPosition === "bottom") return Math.max(gap, panel.height - height - root.panelBarThickness - gap);
                if (root.panelSection === "left") return gap;
                if (root.panelSection === "right") return Math.max(gap, panel.height - height - gap);
                return Math.max(gap, (panel.height - height) / 2);
            }
            opacity: root.panelOpen ? 1 : 0
            scale: root.panelOpen ? 1 : 0.975
            Behavior on opacity { NumberAnimation { duration: root.panelOpen ? 220 : 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.panelOpen ? 220 : 140; easing.type: Easing.OutQuint } }
            transform: Translate {
                y: root.panelOpen ? 0 : (root.panelBarPosition === "bottom" ? root.s(8) : -root.s(8))
                Behavior on y { NumberAnimation { duration: root.panelOpen ? 220 : 140; easing.type: Easing.OutQuint } }
            }
            focus: true
            Keys.onEscapePressed: root.closePanel()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.s(16)
                spacing: root.s(12)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(9)
                    Image {
                        Layout.preferredWidth: root.s(30)
                        Layout.preferredHeight: root.s(30)
                        source: "assets/todoist.svg"
                        sourceSize: Qt.size(120, 120)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    ColumnLayout {
                        spacing: root.s(2)
                        Text {
                            text: "Todoist"
                            color: root.theme.text
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(15)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.connected ? (root.stale ? "Hors ligne · cache" : "Synchronisé")
                                : (root.authorizing ? "Connexion en cours…" : "Non connecté")
                            color: root.connected && !root.stale ? root.theme.green : root.theme.subtext0
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(10)
                        }
                    }
                    Item { Layout.fillWidth: true }
                    UI.ControlButton {
                        id: refreshButton
                        palette: root.theme; factor: root.s(1); glyph: "󰑐"
                        onClicked: { spin(); root.refresh(); }
                    }
                    UI.ControlButton {
                        palette: root.theme; factor: root.s(1)
                        glyph: "󰒓"; active: root.settingsOpen
                        onClicked: { root.settingsOpen = !root.settingsOpen; root.editorOpen = false; }
                    }
                    UI.ControlButton {
                        palette: root.theme; factor: root.s(1); glyph: "󰐕"; primary: true
                        onClicked: root.createEditor(null)
                    }
                }

                RowLayout {
                    visible: !root.settingsOpen && !root.editorOpen && root.connected
                    Layout.fillWidth: true
                    spacing: root.s(3)
                    Repeater {
                        model: [
                            {id: "today", name: "Aujourd'hui"},
                            {id: "upcoming", name: "À venir"},
                            {id: "inbox", name: "Boîte de réception"},
                            {id: "projects", name: "Projets"}
                        ]
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(34)
                            radius: root.s(8)
                            color: root.activeTab === modelData.id ? root.theme.surface1 : root.theme.surface0
                            border.color: root.activeTab === modelData.id ? root.theme.mauve : "transparent"
                            border.width: root.activeTab === modelData.id ? root.s(1) : 0
                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: root.activeTab === modelData.id ? root.theme.text : root.theme.subtext0
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.s(10)
                                elide: Text.ElideRight
                            }
                            TapHandler { onTapped: { root.activeTab = modelData.id; root.selectedProject = ""; } }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }

                Text {
                    visible: root.errorMessage.length > 0
                    Layout.fillWidth: true
                    text: root.errorMessage
                    wrapMode: Text.Wrap
                    color: root.theme.red
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.s(11)
                }

                // The account screen is shown before any credentials are configured.
                ColumnLayout {
                    visible: !root.connected && !root.settingsOpen && !root.editorOpen
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: root.s(12)
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Connecter Todoist"
                        color: root.theme.text
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.s(17)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: root.s(300)
                        text: "Retrouvez vos tâches et projets sans quitter Serpantinum."
                        color: root.theme.subtext0
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.s(12)
                    }
                    UI.ControlButton {
                        Layout.alignment: Qt.AlignHCenter
                        palette: root.theme; factor: root.s(1)
                        label: root.authorizing ? "Connexion en cours…" : "Se connecter via navigateur"
                        primary: true
                        onClicked: root.connectTodoist()
                    }
                    Item { Layout.fillHeight: true }
                }

                Flickable {
                    visible: root.connected && !root.settingsOpen && !root.editorOpen
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: board.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: board
                        width: parent.width
                        spacing: root.s(10)

                        RowLayout {
                            visible: root.activeTab === "today"
                            Layout.fillWidth: true
                            Text {
                                text: "En retard"
                                color: root.theme.red
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.s(12)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: String(root.overdueTasks.length)
                                color: root.theme.subtext0
                                font.pixelSize: root.s(11)
                            }
                        }
                        Repeater {
                            model: root.activeTab === "today" ? root.overdueTasks : []
                            UI.TaskRow {
                                required property var modelData
                                Layout.fillWidth: true
                                task: modelData; palette: root.theme; factor: root.s(1)
                                onCompleted: id => root.completeTask(id)
                                onRenamed: (id, title) => root.renameTask(id, title)
                                onEditRequested: task => root.createEditor(task)
                                onPostponed: id => root.postponeTask(id)
                                onPriorityRequested: task => root.cyclePriority(task)
                            }
                        }
                        Text {
                            visible: root.activeTab === "today"
                            text: "Aujourd'hui  ·  " + root.todayTasks.length
                            color: root.theme.text
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                        }
                        Repeater {
                            model: root.activeTab === "today" ? root.todayTasks : []
                            UI.TaskRow {
                                required property var modelData
                                Layout.fillWidth: true
                                task: modelData; palette: root.theme; factor: root.s(1)
                                onCompleted: id => root.completeTask(id)
                                onRenamed: (id, title) => root.renameTask(id, title)
                                onEditRequested: task => root.createEditor(task)
                                onPostponed: id => root.postponeTask(id)
                                onPriorityRequested: task => root.cyclePriority(task)
                            }
                        }
                        Text {
                            visible: root.activeTab === "upcoming"
                            text: "À venir  ·  " + root.upcomingTasks.length
                            color: root.theme.text
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                        }
                        Repeater {
                            model: root.activeTab === "upcoming" ? root.upcomingTasks : []
                            UI.TaskRow {
                                required property var modelData
                                Layout.fillWidth: true
                                task: modelData; palette: root.theme; factor: root.s(1)
                                onCompleted: id => root.completeTask(id)
                                onRenamed: (id, title) => root.renameTask(id, title)
                                onEditRequested: task => root.createEditor(task)
                                onPostponed: id => root.postponeTask(id)
                                onPriorityRequested: task => root.cyclePriority(task)
                            }
                        }
                        Text {
                            visible: root.activeTab === "inbox"
                            text: "Boîte de réception  ·  " + root.inboxTasks.length
                            color: root.theme.text
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                        }
                        Repeater {
                            model: root.activeTab === "inbox" ? root.inboxTasks : []
                            UI.TaskRow {
                                required property var modelData
                                Layout.fillWidth: true
                                task: modelData; palette: root.theme; factor: root.s(1)
                                onCompleted: id => root.completeTask(id)
                                onRenamed: (id, title) => root.renameTask(id, title)
                                onEditRequested: task => root.createEditor(task)
                                onPostponed: id => root.postponeTask(id)
                                onPriorityRequested: task => root.cyclePriority(task)
                            }
                        }
                        UI.ControlButton {
                            visible: root.activeTab === "projects" && root.selectedProject !== ""
                            Layout.alignment: Qt.AlignLeft
                            palette: root.theme; factor: root.s(1)
                            glyph: "󰁍"; label: "Tous les projets"
                            onClicked: root.selectedProject = ""
                        }
                        Repeater {
                            model: root.activeTab === "projects" && !root.selectedProject ? root.projects : []
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: root.s(43)
                                radius: root.s(8)
                                color: projHover.hovered ? root.theme.surface1 : root.theme.surface0
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: root.s(10)
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: root.theme.text
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.s(12)
                                    }
                                    Text {
                                        text: String(root.tasks.filter(t => t.projectId === String(modelData.id)).length)
                                        color: root.theme.subtext0
                                        font.pixelSize: root.s(11)
                                    }
                                    Text { text: "󰅂"; font.family: "Iosevka Nerd Font"; color: root.theme.subtext0 }
                                }
                                HoverHandler { id: projHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.selectedProject = String(modelData.id) }
                            }
                        }
                        Text {
                            visible: root.activeTab === "projects" && !!root.selectedProject
                            text: root.projectLabel(root.selectedProject) + "  ·  " + root.selectedProjectTasks.length
                            color: root.theme.text
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                        }
                        Repeater {
                            model: root.activeTab === "projects" && !!root.selectedProject ? root.selectedProjectTasks : []
                            UI.TaskRow {
                                required property var modelData
                                Layout.fillWidth: true
                                task: modelData; palette: root.theme; factor: root.s(1)
                                onCompleted: id => root.completeTask(id)
                                onRenamed: (id, title) => root.renameTask(id, title)
                                onEditRequested: task => root.createEditor(task)
                                onPostponed: id => root.postponeTask(id)
                                onPriorityRequested: task => root.cyclePriority(task)
                            }
                        }
                        Text {
                            visible: (root.activeTab === "today" && root.overdueTasks.length + root.todayTasks.length === 0)
                                || (root.activeTab === "upcoming" && root.upcomingTasks.length === 0)
                                || (root.activeTab === "inbox" && root.inboxTasks.length === 0)
                                || (root.activeTab === "projects" && !!root.selectedProject && root.selectedProjectTasks.length === 0)
                            Layout.fillWidth: true
                            text: "Aucune tâche à afficher"
                            horizontalAlignment: Text.AlignHCenter
                            color: root.theme.subtext0
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(12)
                            topPadding: root.s(32)
                        }
                    }
                }

                RowLayout {
                    visible: root.connected && !!root.lastCompletedId && !root.editorOpen && !root.settingsOpen
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Tâche terminée"
                        color: root.theme.subtext0
                        font.pixelSize: root.s(11)
                    }
                    UI.ControlButton {
                        palette: root.theme; factor: root.s(1); label: "Annuler"
                        onClicked: { root.action("reopen", {id: root.lastCompletedId}); root.lastCompletedId = ""; }
                    }
                }

                RowLayout {
                    visible: root.connected && !root.settingsOpen && !root.editorOpen
                    Layout.fillWidth: true
                    spacing: root.s(8)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(42)
                        radius: root.s(9)
                        color: root.theme.surface0
                        border.color: quickInput.activeFocus ? root.theme.mauve : root.theme.surface1
                        border.width: root.s(1)
                        TextInput {
                            id: quickInput
                            anchors.fill: parent
                            anchors.margins: root.s(12)
                            verticalAlignment: TextInput.AlignVCenter
                            color: root.theme.text
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(12)
                            selectByMouse: true
                            onAccepted: root.quickAdd()
                            Text {
                                visible: !quickInput.text && !quickInput.activeFocus
                                text: "+  Ajouter une tâche…"
                                color: root.theme.subtext0
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.s(12)
                            }
                        }
                    }
                    UI.ControlButton {
                        palette: root.theme; factor: root.s(1); glyph: "󰒊"; primary: true
                        onClicked: root.quickAdd()
                    }
                }

                // Task create/edit page (same layout for both paths).
                Flickable {
                    visible: root.editorOpen
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: editorBody.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: editorBody
                        width: parent.width
                        spacing: root.s(12)
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: root.editingExisting ? "Modifier la tâche" : "Nouvelle tâche"
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.s(15)
                                font.weight: Font.DemiBold
                                color: root.theme.text
                            }
                            UI.ControlButton {
                                palette: root.theme; factor: root.s(1); glyph: "󰅖"
                                onClicked: root.editorOpen = false
                            }
                        }
                        Text { text: "Nom de la tâche"; color: root.theme.subtext0; font.pixelSize: root.s(11) }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(38)
                            color: root.theme.surface0
                            radius: root.s(7)
                            border.color: root.theme.surface1
                            TextInput {
                                anchors.fill: parent; anchors.margins: root.s(10)
                                text: root.editorTitle
                                color: root.theme.text
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.s(12)
                                onTextEdited: root.editorTitle = text
                                selectByMouse: true
                            }
                        }
                        Text { text: "Échéance (ex. demain à 18h)"; color: root.theme.subtext0; font.pixelSize: root.s(11) }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: root.s(38)
                            color: root.theme.surface0; radius: root.s(7)
                            border.color: root.theme.surface1
                            TextInput {
                                anchors.fill: parent; anchors.margins: root.s(10)
                                text: root.editorDue; color: root.theme.text
                                font.pixelSize: root.s(12); selectByMouse: true
                                onTextEdited: root.editorDue = text
                            }
                        }
                        Text { text: "Projet"; color: root.theme.subtext0; font.pixelSize: root.s(11) }
                        UI.ControlButton {
                            Layout.fillWidth: true
                            palette: root.theme; factor: root.s(1)
                            label: root.projectLabel(root.editorProject) + "  ▾"
                            onClicked: root.projectPickerOpen = !root.projectPickerOpen
                        }
                        ColumnLayout {
                            visible: root.projectPickerOpen
                            Layout.fillWidth: true
                            spacing: root.s(3)
                            UI.ControlButton {
                                Layout.fillWidth: true
                                palette: root.theme; factor: root.s(1); label: "Boîte de réception"
                                onClicked: {
                                    const inbox = root.projects.find(p => p.is_inbox_project);
                                    root.editorProject = inbox ? String(inbox.id) : "";
                                    root.projectPickerOpen = false;
                                }
                            }
                            Repeater {
                                model: root.projectPickerOpen ? root.projects : []
                                UI.ControlButton {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    palette: root.theme; factor: root.s(1); label: modelData.name
                                    onClicked: { root.editorProject = String(modelData.id); root.projectPickerOpen = false; }
                                }
                            }
                        }
                        Text { text: "Priorité"; color: root.theme.subtext0; font.pixelSize: root.s(11) }
                        RowLayout {
                            Layout.fillWidth: true; spacing: root.s(5)
                            Repeater {
                                model: [1, 2, 3, 4]
                                UI.ControlButton {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    palette: root.theme; factor: root.s(1)
                                    label: "P" + modelData; active: root.editorPriority === modelData
                                    onClicked: root.editorPriority = modelData
                                }
                            }
                        }
                        Text { text: "Description"; color: root.theme.subtext0; font.pixelSize: root.s(11) }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: root.s(86)
                            color: root.theme.surface0; radius: root.s(7)
                            border.color: root.theme.surface1
                            TextEdit {
                                anchors.fill: parent; anchors.margins: root.s(10)
                                text: root.editorDescription; color: root.theme.text
                                wrapMode: TextEdit.Wrap
                                font.pixelSize: root.s(12)
                                onTextChanged: if (activeFocus) root.editorDescription = text
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(8)
                            Item { Layout.fillWidth: true }
                            UI.ControlButton {
                                palette: root.theme; factor: root.s(1); label: "Annuler"
                                onClicked: root.editorOpen = false
                            }
                            UI.ControlButton {
                                palette: root.theme; factor: root.s(1)
                                label: root.editingExisting ? "Enregistrer" : "Ajouter"
                                primary: true; onClicked: root.submitEditor()
                            }
                        }
                    }
                }

                // Minimal plugin-specific settings. Generic Bar placement remains in Serpantinum.
                ColumnLayout {
                    visible: root.settingsOpen
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: root.s(13)
                    Text {
                        text: "Paramètres Todoist"
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.s(15)
                        font.weight: Font.DemiBold
                        color: root.theme.text
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: root.connected ? "Compte connecté" : "Compte non connecté"
                            font.pixelSize: root.s(12)
                            color: root.theme.text
                        }
                        UI.ControlButton {
                            palette: root.theme; factor: root.s(1)
                            label: root.connected ? "Déconnecter" : "Connecter"
                            danger: root.connected
                            onClicked: {
                                if (root.connected) root.action("logout", {});
                                else { root.settingsOpen = false; root.connectTodoist(); }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: root.s(1); color: root.theme.surface1 }
                    Text {
                        text: "Synchronisation : 5 min + ouverture + Refresh"
                        color: root.theme.subtext0
                        font.pixelSize: root.s(11)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Échéances proches"
                            color: root.theme.text
                            font.pixelSize: root.s(12)
                        }
                        UI.ControlButton {
                            palette: root.theme; factor: root.s(1)
                            label: root.setting("notifyDue", true) ? "Activé" : "Désactivé"
                            active: root.setting("notifyDue", true)
                            onClicked: root.setSetting("notifyDue", !root.setting("notifyDue", true))
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Tâches en retard"
                            color: root.theme.text
                            font.pixelSize: root.s(12)
                        }
                        UI.ControlButton {
                            palette: root.theme; factor: root.s(1)
                            label: root.setting("notifyOverdue", true) ? "Activé" : "Désactivé"
                            active: root.setting("notifyOverdue", true)
                            onClicked: root.setSetting("notifyOverdue", !root.setting("notifyOverdue", true))
                        }
                    }
                    Text { text: "Me prévenir avant l'échéance"; color: root.theme.subtext0; font.pixelSize: root.s(12) }
                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(5)
                        Repeater {
                            model: [5, 15, 30, 60, 120]
                            UI.ControlButton {
                                required property var modelData
                                Layout.fillWidth: true
                                palette: root.theme; factor: root.s(1)
                                label: (modelData < 60 ? modelData + " min" : modelData / 60 + " h")
                                active: Number(root.setting("reminderMinutes", 30)) === modelData
                                onClicked: root.setSetting("reminderMinutes", modelData)
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: "Les identifiants sont stockés dans le trousseau Linux (Secret Service)."
                        wrapMode: Text.Wrap
                        color: root.theme.subtext0
                        font.pixelSize: root.s(10)
                    }
                    UI.ControlButton {
                        Layout.alignment: Qt.AlignRight
                        palette: root.theme; factor: root.s(1); label: "Retour"
                        onClicked: root.settingsOpen = false
                    }
                }
            }
        }
    }
}
