import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "providers"
import "ui" as AgentUI

Item {
    id: root
    width: 0; height: 0
    property var pluginMetadata: ({})
    property string pluginDirectory: ""
    property var hostServices: null
    property bool panelVisible: false
    property string panelSection: "center"
    property string panelBarPosition: "top"
    property real panelBarThickness: 40
    property var panelScreen: null
    property string activeProviderId: "codex"
    property bool showNewAgent: false
    property bool showSettings: false
    property int configRevision: 0

    QtObject {
        id: fallbackTheme
        property color base: "#1e1e2e"
        property color surface0: "#313244"
        property color surface1: "#45475a"
        property color surface2: "#585b70"
        property color text: "#cdd6f4"
        property color subtext0: "#a6adc8"
        property color overlay1: "#7f849c"
        property color green: "#a6e3a1"
        property color yellow: "#f9e2af"
        property color red: "#f38ba8"
        property string fontFamily: "sans-serif"
        property real borderRadius: 8
    }
    readonly property var theme: hostServices ? hostServices.theme : fallbackTheme
    function s(v) { return hostServices && hostServices.scaler ? hostServices.scaler.s(v) : v; }
    function settings() { return hostServices && hostServices.pluginManager ? hostServices.pluginManager.pluginSettings(pluginMetadata.id || "ai-agents") : {}; }
    function setting(key, fallback) { const x=settings(); return x[key] !== undefined ? x[key] : fallback; }
    function setSetting(key,value) { if (hostServices && hostServices.pluginManager) hostServices.pluginManager.updatePluginSetting(pluginMetadata.id || "ai-agents",key,value); configRevision++; applySettings(); }
    function providerById(id) { if (id === "codex") return codex; return null; }
    function reusable(name) {
        return hostServices && hostServices.pluginManager
            ? hostServices.pluginManager.reusableUrl(name)
            : "";
    }
    function styleClickButton(item, accent) {
        if (!item || !theme) return;
        item.accentColor = accent || theme.surface0;
        item.textColor = theme.text;
        item.cornerRadius = theme.borderRadius;
        item.textFontSize = s(11);
    }
    function styleIconButton(item) {
        if (!item || !theme) return;
        item.accentColor = theme.surface0;
        item.textColor = theme.text;
        item.cornerRadius = theme.borderRadius;
        item.size = s(30);
        item.iconFontSize = s(14);
    }
    function applySettings() {
        const dummy=configRevision;
        codex.enabled=setting("codexEnabled",true);
        codex.recentCount=Math.max(1,Number(setting("recentSessionsCount",10))||10);
        codex.notifyWaiting=setting("notifyWaiting",true);
        codex.show5hQuota=setting("show5hQuota",true);
        codex.showWeeklyQuota=setting("showWeeklyQuota",true);
        const dm=setting("defaultModel",""); if (dm) codex.defaultModel=dm;
        const dp=setting("defaultPermission",""); if (dp) codex.defaultPermission=dp;
    }
    function syncPanelContext(host) {
        panelSection=host && host.barSection ? host.barSection : "center";
        if (host && host.barWindow) { panelBarPosition=host.barWindow.barPosition||"top"; panelBarThickness=host.barWindow.barHeight||40; panelScreen=host.barWindow.screen||null; }
        else if (Quickshell.screens && Quickshell.screens.length) panelScreen=Quickshell.screens[0];
    }
    function activateBar(host) {
        activeProviderId = host && host.barEntryData
            ? (host.barEntryData.provider || host.barEntryData.id || "codex")
            : "codex";
        syncPanelContext(host);
        const opening = !panelVisible;
        if (opening) { showNewAgent = false; showSettings = false; }
        panelVisible = opening;
    }
    function hidePanel() { panelVisible = false; }

    readonly property var settingsProvider: codex

    CodexProvider { id: codex; pluginDirectory: root.pluginDirectory; services: root.hostServices }
    Component.onCompleted: applySettings()
    onHostServicesChanged: applySettings()

    PanelWindow {
        id: panel
        visible: root.panelVisible || card.animProgress > 0.001
        screen: root.panelScreen || ((Quickshell.screens && Quickshell.screens.length) ? Quickshell.screens[0] : null)
        color: "transparent"
        WlrLayershell.namespace: "serpantinum-plugin-ai-agents"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        mask: Region {
            Region { item: root.panelVisible ? outsideCatcher : null }
            Region { item: card.animProgress > 0.001 ? card : null }
        }

        Item {
            id: outsideCatcher
            anchors.fill: parent
            z: 0
            MouseArea {
                anchors.fill: parent
                enabled: root.panelVisible
                onClicked: mouse => {
                    const inside = mouse.x >= card.x && mouse.x <= card.x + card.width
                        && mouse.y >= card.y && mouse.y <= card.y + card.height;
                    if (!inside) root.hidePanel();
                }
            }
        }

        Rectangle {
            id: card
            z: 1
            width: root.s(460)
            height: root.s(610)
            radius: Math.max(root.s(12), root.theme ? root.theme.borderRadius * 2 : 12)
            color: root.theme ? root.theme.base : "#1e1e2e"
            border.width: 1
            border.color: root.theme ? root.theme.surface1 : "#45475a"

            property real animProgress: root.panelVisible ? 1.0 : 0.0
            Behavior on animProgress {
                NumberAnimation {
                    duration: root.panelVisible ? 280 : 220
                    easing.type: Easing.OutCubic
                }
            }

            readonly property real baseX: {
                const g = root.s(12);
                if (root.panelBarPosition === "left") return root.panelBarThickness + g;
                if (root.panelBarPosition === "right") return Math.max(g, panel.width - width - root.panelBarThickness - g);
                if (root.panelSection === "left") return g;
                if (root.panelSection === "right") return Math.max(g, panel.width - width - g);
                return Math.max(g, (panel.width - width) / 2);
            }
            readonly property real baseY: {
                const g = root.s(12);
                if (root.panelBarPosition === "top") return root.panelBarThickness + g;
                if (root.panelBarPosition === "bottom") return Math.max(g, panel.height - height - root.panelBarThickness - g);
                if (root.panelSection === "left") return g;
                if (root.panelSection === "right") return Math.max(g, panel.height - height - g);
                return Math.max(g, (panel.height - height) / 2);
            }
            readonly property real slideOffset: root.s(16) * (1.0 - animProgress)

            x: baseX + (root.panelBarPosition === "left" ? -slideOffset : (root.panelBarPosition === "right" ? slideOffset : 0))
            y: baseY + (root.panelBarPosition === "top" ? -slideOffset : (root.panelBarPosition === "bottom" ? slideOffset : 0))
            opacity: animProgress
            scale: 0.92 + (0.08 * animProgress)
            transformOrigin: root.panelBarPosition === "left" ? Item.Left
                : (root.panelBarPosition === "right" ? Item.Right
                : (root.panelBarPosition === "bottom" ? Item.Bottom : Item.Top))

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.s(16)
                spacing: root.s(10)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(8)
                    Image {
                        Layout.preferredWidth: root.s(20)
                        Layout.preferredHeight: root.s(20)
                        source: root.pluginDirectory ? "file://" + root.pluginDirectory + "/assets/openai.svg" : ""
                        sourceSize: Qt.size(root.s(40), root.s(40))
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "Codex"
                        color: root.theme.text
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.s(16)
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        id: refreshButton
                        Layout.preferredWidth: root.s(29)
                        Layout.preferredHeight: root.s(29)
                        radius: root.s(8)
                        color: refreshHover.hovered ? root.theme.surface1 : root.theme.surface0
                        Behavior on color { ColorAnimation { duration: 170 } }
                        scale: refreshTap.pressed ? 0.985 : (refreshHover.hovered ? 1.015 : 1)
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(15)
                            color: root.theme.text
                            RotationAnimation on rotation {
                                id: refreshRotation
                                from: 0; to: 360; duration: 1200; loops: 1
                                easing.type: Easing.InOutSine
                                running: false
                            }
                        }
                        HoverHandler { id: refreshHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            id: refreshTap
                            onTapped: {
                                refreshRotation.restart();
                                codex.refresh();
                            }
                        }
                    }
                    Loader {
                        Layout.preferredWidth: root.s(30)
                        Layout.preferredHeight: root.s(30)
                        source: root.reusable("IconButton.qml")
                        onLoaded: {
                            item.buttonIcon = "󰒓";
                            root.styleIconButton(item);
                            item.clicked.connect(function() { root.showSettings = !root.showSettings; root.showNewAgent = false; });
                        }
                    }
                    Loader {
                        Layout.preferredWidth: root.s(30)
                        Layout.preferredHeight: root.s(30)
                        source: root.reusable("IconButton.qml")
                        onLoaded: {
                            item.buttonIcon = "󰅖";
                            root.styleIconButton(item);
                            item.clicked.connect(function() { root.hidePanel(); });
                        }
                    }
                }
                Text {
                    visible: codex.error !== ""
                    Layout.fillWidth: true
                    text: codex.error
                    color: root.theme.red
                    wrapMode: Text.Wrap
                    font.pixelSize: root.s(10)
                }
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: root.showNewAgent ? newAgentComponent : (root.showSettings ? settingsComponent : sessionsComponent)
                }
            }
        }
    }

    Component { id:sessionsComponent
        Flickable { contentWidth:width; contentHeight:body.implicitHeight; clip:true
            Column { id:body; width:parent.width; spacing:root.s(8)
                Row { width:parent.width; spacing:root.s(8)
                    Repeater { model:codex.quotaItems.filter(q => (q.id!=="primary"||codex.show5hQuota)&&(q.id!=="secondary"||codex.showWeeklyQuota)); AgentUI.QuotaCard { required property var modelData; quota:modelData; theme:root.theme; scaleFactor:root.s(1) } }
                }
                RowLayout { width:parent.width
                    Text { text:"Active"; color:root.theme.subtext0; font.family:root.theme.fontFamily; font.bold:true }
                    Item { Layout.fillWidth:true }
                    Loader {
                        Layout.preferredHeight: root.s(30)
                        source: root.reusable("ClickButton.qml")
                        onLoaded: {
                            item.buttonText = "New agent";
                            item.buttonIcon = "+";
                            item.horizontalPadding = root.s(10);
                            root.styleClickButton(item, root.theme.surface0);
                            item.clicked.connect(function() { root.showNewAgent=true; });
                        }
                    }
                }
                Repeater { model:codex.activeSessions; AgentUI.AgentRow { required property var modelData; width:body.width; session:modelData; theme:root.theme; scaleFactor:root.s(1); onActivated:codex.resume(session) } }
                Text { visible:codex.activeSessions.length===0; text:"No active agents"; color:root.theme.overlay1; font.family:root.theme.fontFamily; font.pixelSize:root.s(10) }
                Text { text:"Recent"; color:root.theme.subtext0; font.family:root.theme.fontFamily; font.bold:true; topPadding:root.s(6) }
                Repeater { model:codex.recentSessions; AgentUI.AgentRow { required property var modelData; width:body.width; session:modelData; theme:root.theme; scaleFactor:root.s(1); onActivated:codex.resume(session) } }
            }
        }
    }
    Component { id:newAgentComponent; AgentUI.NewAgentView { provider:codex; theme:root.theme; hostServices:root.hostServices; popupRootObj:panel; scaleFactor:root.s(1); onCloseRequested:root.showNewAgent=false } }
    Component {
        id: settingsComponent
        Settings {
            pluginMetadata: root.pluginMetadata
            pluginDirectory: root.pluginDirectory
            pluginInstance: root
            hostServices: root.hostServices
            rootObj: root
        }
    }

}
