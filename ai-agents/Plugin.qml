import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "providers"
import "ui"

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
    function activateBar(host) { activeProviderId=host && host.barEntryData ? (host.barEntryData.provider||host.barEntryData.id||"codex") : "codex"; syncPanelContext(host); panelVisible=!panelVisible; showNewAgent=false; showSettings=false; }

    CodexProvider { id: codex; pluginDirectory: root.pluginDirectory; services: root.hostServices }
    Component.onCompleted: applySettings()
    onHostServicesChanged: applySettings()

    PanelWindow {
        id: panel; visible: root.panelVisible; screen: root.panelScreen || ((Quickshell.screens&&Quickshell.screens.length)?Quickshell.screens[0]:null); color:"transparent"
        WlrLayershell.namespace: "serpantinum-plugin-ai-agents"; WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand; exclusionMode: ExclusionMode.Ignore
        anchors { top:true; bottom:true; left:true; right:true }
        mask: Region { item: root.panelVisible ? card : null }
        Rectangle {
            id: card; width: root.s(460); height: root.s(610); radius: Math.max(root.s(12),root.theme ? root.theme.borderRadius*2:12); color: root.theme ? root.theme.base : "#1e1e2e"; border.width:1; border.color: root.theme ? root.theme.surface1 : "#45475a"
            x: { const g=root.s(12); if(root.panelBarPosition==="left")return root.panelBarThickness+g; if(root.panelBarPosition==="right")return Math.max(g,panel.width-width-root.panelBarThickness-g); if(root.panelSection==="left")return g; if(root.panelSection==="right")return Math.max(g,panel.width-width-g); return Math.max(g,(panel.width-width)/2); }
            y: { const g=root.s(12); if(root.panelBarPosition==="top")return root.panelBarThickness+g; if(root.panelBarPosition==="bottom")return Math.max(g,panel.height-height-root.panelBarThickness-g); if(root.panelSection==="left")return g; if(root.panelSection==="right")return Math.max(g,panel.height-height-g); return Math.max(g,(panel.height-height)/2); }
            ColumnLayout { anchors.fill:parent; anchors.margins:root.s(16); spacing:root.s(10)
                RowLayout { Layout.fillWidth:true
                    Text { text:"󰚩  Codex"; color:root.theme.text; font.family:root.theme.fontFamily; font.pixelSize:root.s(16); font.bold:true }
                    Item { Layout.fillWidth:true }
                    Button { text:"Refresh"; onClicked:codex.refresh() }
                    Button { text:"⚙"; onClicked:{root.showSettings=!root.showSettings;root.showNewAgent=false} }
                    Button { text:"×"; onClicked:root.panelVisible=false }
                }
                Text { visible:codex.error!==""; Layout.fillWidth:true; text:codex.error; color:root.theme.red; wrapMode:Text.Wrap; font.pixelSize:root.s(10) }
                Loader { Layout.fillWidth:true; Layout.fillHeight:true; sourceComponent: root.showNewAgent ? newAgentComponent : (root.showSettings ? settingsComponent : sessionsComponent) }
            }
        }
    }

    Component { id:sessionsComponent
        Flickable { contentWidth:width; contentHeight:body.implicitHeight; clip:true
            Column { id:body; width:parent.width; spacing:root.s(8)
                Row { width:parent.width; spacing:root.s(8)
                    Repeater { model:codex.quotaItems.filter(q => (q.id!=="primary"||codex.show5hQuota)&&(q.id!=="secondary"||codex.showWeeklyQuota)); QuotaCard { required property var modelData; quota:modelData; theme:root.theme; scaleFactor:root.s(1) } }
                }
                Row { width:parent.width; Text { text:"Active"; color:root.theme.subtext0; font.family:root.theme.fontFamily; font.bold:true } Item { width:parent.width-root.s(100); height:1 } Button { text:"+ New agent"; onClicked:root.showNewAgent=true } }
                Repeater { model:codex.activeSessions; AgentRow { required property var modelData; width:body.width; session:modelData; theme:root.theme; scaleFactor:root.s(1); onActivated:codex.focus(session) } }
                Text { visible:codex.activeSessions.length===0; text:"No active agents"; color:root.theme.overlay1; font.family:root.theme.fontFamily; font.pixelSize:root.s(10) }
                Text { text:"Recent"; color:root.theme.subtext0; font.family:root.theme.fontFamily; font.bold:true; topPadding:root.s(6) }
                Repeater { model:codex.recentSessions; AgentRow { required property var modelData; width:body.width; session:modelData; theme:root.theme; scaleFactor:root.s(1); onActivated:codex.resume(session) } }
            }
        }
    }
    Component { id:newAgentComponent; NewAgentView { provider:codex; theme:root.theme; scaleFactor:root.s(1); onCloseRequested:root.showNewAgent=false } }
    Component { id:settingsComponent
        Flickable { contentWidth:width; contentHeight:settingsCol.implicitHeight; clip:true
            ColumnLayout { id:settingsCol; width:parent.width; spacing:root.s(10)
                Text { text:"Providers"; color:root.theme.text; font.family:root.theme.fontFamily; font.pixelSize:root.s(14); font.bold:true }
                CheckBox { text:"Codex enabled"; checked:root.setting("codexEnabled",true); onToggled:root.setSetting("codexEnabled",checked) }
                SpinBox { from:1; to:50; value:Number(root.setting("recentSessionsCount",10)); editable:true; onValueModified:root.setSetting("recentSessionsCount",value) }
                Text { text:"Recent sessions count"; color:root.theme.subtext0; font.family:root.theme.fontFamily }
                CheckBox { text:"Notify when Waiting"; checked:root.setting("notifyWaiting",true); onToggled:root.setSetting("notifyWaiting",checked) }
                CheckBox { text:"Show 5h quota"; checked:root.setting("show5hQuota",true); onToggled:root.setSetting("show5hQuota",checked) }
                CheckBox { text:"Show weekly quota"; checked:root.setting("showWeeklyQuota",true); onToggled:root.setSetting("showWeeklyQuota",checked) }
                Text { text:"Default model"; color:root.theme.subtext0; font.family:root.theme.fontFamily }
                ComboBox { Layout.fillWidth:true; model:codex.availableModels.map(m=>m.name); onActivated:function(i){root.setSetting("defaultModel",codex.availableModels[i].id)} }
                Text { text:"Default permission"; color:root.theme.subtext0; font.family:root.theme.fontFamily }
                ComboBox { Layout.fillWidth:true; model:codex.availablePermissions.map(p=>p.id); onActivated:function(i){root.setSetting("defaultPermission",codex.availablePermissions[i].id)} }
            }
        }
    }
}
