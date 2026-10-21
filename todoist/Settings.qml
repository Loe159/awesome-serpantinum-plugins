import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "ui" as UI

// Native settingsEntry page, loaded by Serpantinum's PluginSettingsTab.
Item {
    id: root
    property var pluginMetadata: ({})
    property string pluginDirectory: ""
    property var pluginInstance: null
    property var hostServices: null
    property var rootObj: null
    property int revision: 0
    property bool connected: false
    property bool connecting: false
    property bool authorizing: false
    property bool disconnecting: false
    property bool confirmLogout: false
    property string errorMessage: ""
    property string feedback: ""
    property double loginStarted: 0

    readonly property var theme: hostServices && hostServices.theme ? hostServices.theme : fallbackTheme
    readonly property var manager: hostServices ? hostServices.pluginManager : null
    function s(n) { return rootObj && rootObj.s ? rootObj.s(n) : (hostServices && hostServices.scaler ? hostServices.scaler.s(n) : n); }
    function setting(name, fallback) {
        const rev = revision;
        const values = manager ? manager.pluginSettings("todoist") : {};
        return values[name] !== undefined ? values[name] : fallback;
    }
    function updateSetting(name, value) {
        if (!manager) return;
        manager.updatePluginSetting("todoist", name, value);
        revision++;
        if (pluginInstance && pluginInstance.refresh) pluginInstance.refresh();
    }
    function refreshAuth() {
        if (!pluginDirectory || statusProcess.running || disconnecting) return;
        statusProcess.command = ["python3", pluginDirectory + "/services/todoist.py", "auth-status"];
        statusProcess.running = true;
    }
    function beginLogin() {
        if (connecting || connected || !pluginDirectory) return;
        errorMessage = "";
        feedback = "Autorisez l'accès à vos tâches dans le navigateur.";
        loginStarted = Date.now();
        connecting = true;
        try {
            Quickshell.execDetached(["python3", pluginDirectory + "/services/todoist.py", "login"]);
        } catch (e) {
            connecting = false;
            errorMessage = "Impossible de lancer la connexion : " + String(e);
        }
    }
    function logout() {
        if (disconnecting || !connected || !pluginDirectory) return;
        confirmLogout = false;
        disconnecting = true;
        feedback = "";
        errorMessage = "";
        logoutProcess.command = ["python3", pluginDirectory + "/services/todoist.py", "logout"];
        logoutProcess.running = true;
    }
    function refreshTasks() {
        if (pluginInstance && pluginInstance.refresh) {
            pluginInstance.refresh();
            feedback = "Actualisation demandée.";
        } else feedback = "Activez le plugin pour actualiser ses tâches.";
    }

    onPluginDirectoryChanged: refreshAuth()
    onVisibleChanged: if (visible) refreshAuth()
    Component.onCompleted: refreshAuth()

    QtObject {
        id: fallbackTheme
        property color base: "#1e1e2e"
        property color surface0: "#313244"
        property color surface1: "#45475a"
        property color surface2: "#585b70"
        property color text: "#cdd6f4"
        property color subtext0: "#a6adc8"
        property color mauve: "#cba6f7"
        property color green: "#a6e3a1"
        property color yellow: "#f9e2af"
        property color red: "#f38ba8"
        property string fontFamily: "sans-serif"
        property real borderRadius: 10
    }
    Connections {
        target: hostServices ? hostServices.config : null
        ignoreUnknownSignals: true
        function onRawSettingsChanged() { root.revision++ }
        function onSettingsLoaded() { root.revision++ }
    }
    Timer {
        running: root.visible && root.pluginDirectory !== ""
        interval: root.connecting ? 2500 : 12000
        repeat: true
        onTriggered: root.refreshAuth()
    }
    Process {
        id: statusProcess
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.connected = !!data.connected;
                    root.authorizing = !!data.authorizing;
                    if (root.connected) {
                        if (root.connecting && root.pluginInstance && root.pluginInstance.refresh) root.pluginInstance.refresh();
                        root.connecting = false;
                        root.confirmLogout = false;
                        root.errorMessage = "";
                        root.feedback = "Compte connecté.";
                    } else if (root.connecting && !root.authorizing && data.error) {
                        root.connecting = false;
                        root.feedback = "";
                        root.errorMessage = data.error;
                    } else if (root.connecting && !root.authorizing && Date.now() - root.loginStarted > 12000) {
                        root.connecting = false;
                        root.feedback = "";
                        root.errorMessage = "Connexion interrompue. Réessayez.";
                    } else if (!root.connecting && data.error) {
                        root.errorMessage = data.error;
                    }
                } catch (e) { root.errorMessage = "Impossible de vérifier la connexion."; }
            }
        }
        onExited: function(code) {
            if (code !== 0) root.errorMessage = "Impossible de vérifier la connexion.";
        }
    }
    Process {
        id: logoutProcess
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    if (!data.ok) root.errorMessage = data.error || "Échec de déconnexion.";
                } catch (e) { root.errorMessage = "Réponse Todoist invalide."; }
            }
        }
        onExited: function(code) {
            root.disconnecting = false;
            if (code === 0) {
                root.connected = false;
                root.connecting = false;
                root.feedback = "Compte déconnecté.";
                if (root.pluginInstance && root.pluginInstance.refresh) root.pluginInstance.refresh();
            } else if (!root.errorMessage) root.errorMessage = "Déconnexion impossible.";
            root.refreshAuth();
        }
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.margins: root.s(8)
        contentWidth: width
        contentHeight: content.implicitHeight + root.s(14)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: scroll.width
            spacing: root.s(9)

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: root.s(7)
                spacing: root.s(12)
                Image {
                    Layout.preferredWidth: root.s(40)
                    Layout.preferredHeight: root.s(40)
                    source: "assets/todoist.svg"
                    sourceSize: Qt.size(120, 120)
                    smooth: true
                    mipmap: true
                }
                ColumnLayout {
                    spacing: root.s(2)
                    Layout.fillWidth: true
                    Text { text: "Todoist"; color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: root.s(22); font.weight: Font.Bold }
                    Text { text: "Compte, synchronisation et notifications"; color: root.theme.subtext0; font.family: root.theme.fontFamily; font.pixelSize: root.s(11) }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: root.errorMessage.length > 0
                text: root.errorMessage; wrapMode: Text.Wrap
                color: root.theme.red; font.family: root.theme.fontFamily; font.pixelSize: root.s(11)
            }
            Text {
                Layout.fillWidth: true
                visible: root.feedback.length > 0 && root.errorMessage.length === 0
                text: root.feedback; wrapMode: Text.Wrap
                color: root.theme.subtext0; font.family: root.theme.fontFamily; font.pixelSize: root.s(11)
            }

            Text { text: "Compte"; color: root.theme.subtext0; font.family: root.theme.fontFamily; font.pixelSize: root.s(11); font.weight: Font.DemiBold }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: accountRow.implicitHeight + root.s(28)
                radius: root.theme.borderRadius
                color: Qt.alpha(root.theme.surface0, 0.5)
                border.width: 1; border.color: root.theme.surface1
                RowLayout {
                    id: accountRow
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.s(14); anchors.rightMargin: root.s(14)
                    spacing: root.s(12)
                    Rectangle {
                        Layout.preferredWidth: root.s(9); Layout.preferredHeight: root.s(9); radius: width / 2
                        color: root.connected ? root.theme.green : root.connecting ? root.theme.yellow : root.theme.surface2
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: root.s(3)
                        Text {
                            text: root.connected ? "Compte connecté" : root.connecting ? "Connexion en cours…" : "Compte non connecté"
                            color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: root.s(13); font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            text: root.connected ? "Tâches et projets accessibles" : "Authentification sécurisée par navigateur"
                            color: root.theme.subtext0; font.family: root.theme.fontFamily; font.pixelSize: root.s(11)
                        }
                    }
                    UI.ControlButton {
                        palette: root.theme; factor: root.s(1)
                        label: root.connected ? "Déconnecter" : (root.connecting ? "Patientez…" : "Se connecter")
                        glyph: root.connected ? "󰍃" : "󰐕"
                        primary: !root.connected; danger: root.connected
                        enabled: !root.connecting && !root.disconnecting
                        opacity: enabled ? 1 : 0.5
                        onClicked: root.connected ? root.confirmLogout = true : root.beginLogin()
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                visible: root.confirmLogout
                implicitHeight: confirmation.implicitHeight + root.s(22)
                radius: root.theme.borderRadius; color: Qt.alpha(root.theme.surface1, 0.6)
                RowLayout {
                    id: confirmation
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.s(12); anchors.rightMargin: root.s(12); spacing: root.s(10)
                    Text { Layout.fillWidth: true; text: "Déconnecter Todoist ?"; color: root.theme.text; font.pixelSize: root.s(12) }
                    UI.ControlButton { palette: root.theme; factor: root.s(1); label: "Annuler"; onClicked: root.confirmLogout = false }
                    UI.ControlButton { palette: root.theme; factor: root.s(1); label: "Confirmer"; danger: true; onClicked: root.logout() }
                }
            }

            Text {
                text: "Synchronisation"; Layout.topMargin: root.s(8)
                color: root.theme.subtext0; font.family: root.theme.fontFamily
                font.pixelSize: root.s(11); font.weight: Font.DemiBold
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: syncRow.implicitHeight + root.s(28)
                radius: root.theme.borderRadius; color: Qt.alpha(root.theme.surface0, 0.5)
                RowLayout {
                    id: syncRow
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.s(14); anchors.rightMargin: root.s(14); spacing: root.s(9)
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: root.s(3)
                        Text { text: "Synchronisation automatique"; color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: root.s(13) }
                        Text { text: "Également à l'ouverture et après modification"; color: root.theme.subtext0; font.family: root.theme.fontFamily; font.pixelSize: root.s(11) }
                    }
                    Repeater {
                        model: [1, 5, 15, 30]
                        UI.ControlButton {
                            required property var modelData
                            palette: root.theme; factor: root.s(1)
                            label: modelData + " min"
                            active: Number(root.setting("syncIntervalMinutes", 5)) === modelData
                            onClicked: root.updateSetting("syncIntervalMinutes", modelData)
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: refreshRow.implicitHeight + root.s(24)
                radius: root.theme.borderRadius; color: Qt.alpha(root.theme.surface0, 0.5)
                RowLayout {
                    id: refreshRow
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.s(14); anchors.rightMargin: root.s(14)
                    Text { Layout.fillWidth: true; text: "Actualiser maintenant"; color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: root.s(13) }
                    UI.ControlButton {
                        palette: root.theme; factor: root.s(1); glyph: "󰑐"; label: "Refresh"
                        enabled: root.connected; opacity: enabled ? 1 : 0.5
                        onClicked: { spin(); root.refreshTasks(); }
                    }
                }
            }

            Text {
                text: "Notifications"; Layout.topMargin: root.s(8)
                color: root.theme.subtext0; font.family: root.theme.fontFamily
                font.pixelSize: root.s(11); font.weight: Font.DemiBold
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: dueRow.implicitHeight + root.s(28)
                radius: root.theme.borderRadius; color: Qt.alpha(root.theme.surface0, 0.5)
                RowLayout {
                    id: dueRow
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.s(14); anchors.rightMargin: root.s(14); spacing: root.s(10)
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: root.s(3)
                        Text { text: "Échéances proches"; color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: root.s(13) }
                        Text { text: "Notification avant l'heure prévue"; color: root.theme.subtext0; font.family: root.theme.fontFamily; font.pixelSize: root.s(11) }
                    }
                    Loader {
                        id: dueToggle
                        Layout.preferredWidth: root.s(64); Layout.preferredHeight: root.s(32)
                        source: root.manager ? root.manager.reusableUrl("Toggle.qml") : ""
                        onLoaded: {
                            if (!item) return;
                            item.checked = Qt.binding(() => !!root.setting("notifyDue", true));
                            item.accentColor = root.theme.mauve;
                            item.baseColor = root.theme.surface1;
                            item.handleColor = root.theme.base;
                            item.handleOffColor = root.theme.text;
                        }
                    }
                    Connections { target: dueToggle.item; ignoreUnknownSignals: true; function onToggled(value) { root.updateSetting("notifyDue", value) } }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: delayRow.implicitHeight + root.s(24)
                radius: root.theme.borderRadius; color: Qt.alpha(root.theme.surface0, 0.5)
                opacity: root.setting("notifyDue", true) ? 1 : 0.55
                RowLayout {
                    id: delayRow
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.s(14); anchors.rightMargin: root.s(14); spacing: root.s(9)
                    Text { Layout.fillWidth: true; text: "Délai de rappel"; color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: root.s(13) }
                    Repeater {
                        model: [5, 15, 30, 60, 120]
                        UI.ControlButton {
                            required property var modelData
                            palette: root.theme; factor: root.s(1)
                            label: modelData < 60 ? modelData + " min" : modelData / 60 + " h"
                            active: Number(root.setting("reminderMinutes", 30)) === modelData
                            enabled: root.setting("notifyDue", true)
                            onClicked: root.updateSetting("reminderMinutes", modelData)
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: lateRow.implicitHeight + root.s(28)
                radius: root.theme.borderRadius; color: Qt.alpha(root.theme.surface0, 0.5)
                RowLayout {
                    id: lateRow
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.s(14); anchors.rightMargin: root.s(14); spacing: root.s(10)
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: root.s(3)
                        Text { text: "Tâches en retard"; color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: root.s(13) }
                        Text { text: "Une alerte par tâche et échéance"; color: root.theme.subtext0; font.family: root.theme.fontFamily; font.pixelSize: root.s(11) }
                    }
                    Loader {
                        id: lateToggle
                        Layout.preferredWidth: root.s(64); Layout.preferredHeight: root.s(32)
                        source: root.manager ? root.manager.reusableUrl("Toggle.qml") : ""
                        onLoaded: {
                            if (!item) return;
                            item.checked = Qt.binding(() => !!root.setting("notifyOverdue", true));
                            item.accentColor = root.theme.mauve;
                            item.baseColor = root.theme.surface1;
                            item.handleColor = root.theme.base;
                            item.handleOffColor = root.theme.text;
                        }
                    }
                    Connections { target: lateToggle.item; ignoreUnknownSignals: true; function onToggled(value) { root.updateSetting("notifyOverdue", value) } }
                }
            }
            Text {
                Layout.fillWidth: true; Layout.topMargin: root.s(8)
                text: "Les identifiants OAuth restent dans le trousseau Linux et ne sont jamais enregistrés dans la configuration."
                color: root.theme.subtext0; font.family: root.theme.fontFamily; font.pixelSize: root.s(10)
                wrapMode: Text.Wrap
            }
        }
    }
}
