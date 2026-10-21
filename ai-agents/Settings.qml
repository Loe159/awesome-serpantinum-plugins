import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var pluginMetadata: ({})
    property string pluginDirectory: ""
    property var pluginInstance: null
    property var hostServices: null
    property var rootObj: null
    property int configRevision: 0

    readonly property var theme: hostServices ? hostServices.theme : null
    readonly property var provider: pluginInstance && pluginInstance.settingsProvider ? pluginInstance.settingsProvider : null

    function s(value) { return rootObj && rootObj.s ? rootObj.s(value) : value; }
    function pluginId() { return pluginMetadata && pluginMetadata.id ? pluginMetadata.id : "ai-agents"; }
    function settings() {
        if (!hostServices || !hostServices.pluginManager) return {};
        return hostServices.pluginManager.pluginSettings(pluginId());
    }
    function setting(key, fallback) {
        const all = settings();
        return all[key] !== undefined ? all[key] : fallback;
    }
    function setSetting(key, value) {
        if (!hostServices || !hostServices.pluginManager) return;
        hostServices.pluginManager.updatePluginSetting(pluginId(), key, value);
        configRevision++;
        if (pluginInstance && pluginInstance.applySettings) pluginInstance.applySettings();
    }
    function codexModuleId() { return "plugin:" + pluginId() + ":codex"; }
    function codexInBar() {
        if (!hostServices || !hostServices.pluginManager) return false;
        return hostServices.pluginManager.moduleIsPlaced(codexModuleId());
    }
    function setCodexInBar(enabled) {
        if (!hostServices || !hostServices.pluginManager) return;
        hostServices.pluginManager.setBarModuleEnabled(codexModuleId(), enabled, "center");
        configRevision++;
    }
    function modelOptions() {
        const names = ["Automatic / habitual"];
        if (provider && provider.availableModels) {
            for (let i = 0; i < provider.availableModels.length; ++i)
                names.push(provider.availableModels[i].name || provider.availableModels[i].id);
        }
        return names;
    }
    function modelIds() {
        const ids = [""];
        if (provider && provider.availableModels) {
            for (let i = 0; i < provider.availableModels.length; ++i)
                ids.push(provider.availableModels[i].id);
        }
        return ids;
    }
    function permissionOptions() {
        if (provider && provider.availablePermissions && provider.availablePermissions.length > 0)
            return provider.availablePermissions.map(p => p.name || p.id);
        return ["workspace-write", "read-only", "danger-full-access"];
    }
    function permissionIds() {
        if (provider && provider.availablePermissions && provider.availablePermissions.length > 0)
            return provider.availablePermissions.map(p => p.id);
        return ["workspace-write", "read-only", "danger-full-access"];
    }
    function reusable(name) {
        return hostServices && hostServices.pluginManager
            ? hostServices.pluginManager.reusableUrl(name)
            : "";
    }
    function styleToggle(item) {
        if (!item || !theme) return;
        item.accentColor = theme.mauve;
        item.baseColor = theme.surface1;
        item.handleColor = theme.crust;
        item.handleOffColor = theme.text;
    }
    function styleDropdown(item) {
        if (!item || !theme) return;
        item.accentColor = theme.mauve;
        item.baseColor = theme.surface0;
        item.hoverColor = theme.surface1;
        item.dropdownColor = theme.surface0;
        item.borderColor = Qt.alpha(theme.surface2, 0.6);
        item.textColor = theme.text;
        item.activeTextColor = theme.crust;
        item.fontPixelSize = s(11);
    }

    Connections {
        target: hostServices ? hostServices.config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: root.s(8)
        contentWidth: width
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: root.s(6)

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: codexRow.implicitHeight + root.s(24)
                radius: root.theme ? root.theme.borderRadius : 12
                color: root.theme ? Qt.alpha(root.theme.surface0, 0.4) : "#313244"
                RowLayout {
                    id: codexRow
                    anchors.left: parent.left; anchors.leftMargin: root.s(14)
                    anchors.right: parent.right; anchors.rightMargin: root.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.s(12)
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: root.s(2)
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Codex"; font.family: root.theme.fontFamily; font.pixelSize: root.s(13); color: root.theme.text }
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Monitor and launch Codex sessions"; font.family: root.theme.fontFamily; font.pixelSize: root.s(11); color: root.theme.subtext0 }
                    }
                    Loader {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        source: root.reusable("Toggle.qml")
                        onLoaded: {
                            item.checked = !!root.setting("codexEnabled", true);
                            root.styleToggle(item);
                            item.toggled.connect(function(val) { root.setSetting("codexEnabled", val); });
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: barRow.implicitHeight + root.s(24)
                radius: root.theme ? root.theme.borderRadius : 12
                color: root.theme ? Qt.alpha(root.theme.surface0, 0.4) : "#313244"
                RowLayout {
                    id: barRow
                    anchors.left: parent.left; anchors.leftMargin: root.s(14)
                    anchors.right: parent.right; anchors.rightMargin: root.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.s(12)
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: root.s(2)
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Show Codex in the Bar"; font.family: root.theme.fontFamily; font.pixelSize: root.s(13); color: root.theme.text }
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Add or remove the Codex provider module from the center section"; font.family: root.theme.fontFamily; font.pixelSize: root.s(11); color: root.theme.subtext0 }
                    }
                    Loader {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        source: root.reusable("Toggle.qml")
                        onLoaded: {
                            item.checked = root.codexInBar();
                            root.styleToggle(item);
                            item.toggled.connect(function(val) { root.setCodexInBar(val); });
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: recentRow.implicitHeight + root.s(24)
                radius: root.theme ? root.theme.borderRadius : 12
                color: root.theme ? Qt.alpha(root.theme.surface0, 0.4) : "#313244"
                RowLayout {
                    id: recentRow
                    anchors.left: parent.left; anchors.leftMargin: root.s(14)
                    anchors.right: parent.right; anchors.rightMargin: root.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.s(12)
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: root.s(2)
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Recent sessions"; font.family: root.theme.fontFamily; font.pixelSize: root.s(13); color: root.theme.text }
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Number of recent Codex sessions shown in the popup"; font.family: root.theme.fontFamily; font.pixelSize: root.s(11); color: root.theme.subtext0 }
                    }
                    Loader {
                        Layout.preferredWidth: root.s(150)
                        Layout.preferredHeight: root.s(32)
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        source: root.reusable("NumberSelector.qml")
                        onLoaded: {
                            item.from = 1; item.to = 50; item.stepSize = 1; item.decimals = 0;
                            item.value = Number(root.setting("recentSessionsCount", 10));
                            item.baseColor = root.theme.surface0;
                            item.accentColor = root.theme.mauve;
                            item.buttonColor = root.theme.surface1;
                            item.buttonTextColor = root.theme.text;
                            item.textColor = root.theme.text;
                            item.subTextColor = root.theme.subtext0;
                            item.borderColor = Qt.alpha(root.theme.surface2, 0.6);
                            item.cornerRadius = root.theme.borderRadius;
                            item.fontFamily = root.theme.fontFamily;
                            item.fontPixelSize = root.s(11);
                            item.triggered.connect(function() { root.setSetting("recentSessionsCount", Math.round(item.value)); });
                        }
                    }
                }
            }

            Repeater {
                model: [
                    { key: "notifyWaiting", title: "Notify when Waiting", desc: "Send a system notification when an agent starts waiting", fallback: true },
                    { key: "show5hQuota", title: "Show 5h quota", desc: "Display the short Codex quota in the Bar and popup", fallback: true },
                    { key: "showWeeklyQuota", title: "Show weekly quota", desc: "Display the weekly Codex quota in the Bar and popup", fallback: true }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: toggleRow.implicitHeight + root.s(24)
                    radius: root.theme ? root.theme.borderRadius : 12
                    color: root.theme ? Qt.alpha(root.theme.surface0, 0.4) : "#313244"
                    RowLayout {
                        id: toggleRow
                        anchors.left: parent.left; anchors.leftMargin: root.s(14)
                        anchors.right: parent.right; anchors.rightMargin: root.s(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.s(12)
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: root.s(2)
                            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: modelData.title; font.family: root.theme.fontFamily; font.pixelSize: root.s(13); color: root.theme.text }
                            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: modelData.desc; font.family: root.theme.fontFamily; font.pixelSize: root.s(11); color: root.theme.subtext0 }
                        }
                        Loader {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            source: root.reusable("Toggle.qml")
                            onLoaded: {
                                item.checked = !!root.setting(modelData.key, modelData.fallback);
                                root.styleToggle(item);
                                item.toggled.connect(function(val) { root.setSetting(modelData.key, val); });
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: modelRow.implicitHeight + root.s(24)
                radius: root.theme ? root.theme.borderRadius : 12
                color: root.theme ? Qt.alpha(root.theme.surface0, 0.4) : "#313244"
                RowLayout {
                    id: modelRow
                    anchors.left: parent.left; anchors.leftMargin: root.s(14)
                    anchors.right: parent.right; anchors.rightMargin: root.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.s(12)
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: root.s(2)
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Default model"; font.family: root.theme.fontFamily; font.pixelSize: root.s(13); color: root.theme.text }
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Model selected when launching a new Codex agent"; font.family: root.theme.fontFamily; font.pixelSize: root.s(11); color: root.theme.subtext0 }
                    }
                    Loader {
                        Layout.preferredWidth: root.s(220)
                        Layout.preferredHeight: root.s(32)
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        source: root.reusable("Dropdown.qml")
                        onLoaded: {
                            const names = root.modelOptions(); const ids = root.modelIds();
                            item.options = names;
                            const wanted = String(root.setting("defaultModel", ""));
                            const idx = ids.indexOf(wanted); item.currentIndex = idx >= 0 ? idx : 0;
                            root.styleDropdown(item);
                            item.valueChanged.connect(function(index, value) { if (index >= 0 && index < ids.length) root.setSetting("defaultModel", ids[index]); });
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: permissionRow.implicitHeight + root.s(24)
                radius: root.theme ? root.theme.borderRadius : 12
                color: root.theme ? Qt.alpha(root.theme.surface0, 0.4) : "#313244"
                RowLayout {
                    id: permissionRow
                    anchors.left: parent.left; anchors.leftMargin: root.s(14)
                    anchors.right: parent.right; anchors.rightMargin: root.s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.s(12)
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: root.s(2)
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Default permission"; font.family: root.theme.fontFamily; font.pixelSize: root.s(13); color: root.theme.text }
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Permission profile used for new Codex agents"; font.family: root.theme.fontFamily; font.pixelSize: root.s(11); color: root.theme.subtext0 }
                    }
                    Loader {
                        Layout.preferredWidth: root.s(220)
                        Layout.preferredHeight: root.s(32)
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        source: root.reusable("Dropdown.qml")
                        onLoaded: {
                            const names = root.permissionOptions(); const ids = root.permissionIds();
                            item.options = names;
                            const wanted = String(root.setting("defaultPermission", "workspace-write"));
                            let idx = ids.indexOf(wanted);
                            if (idx < 0 && wanted === ":workspace") idx = ids.indexOf("workspace-write");
                            item.currentIndex = idx >= 0 ? idx : 0;
                            root.styleDropdown(item);
                            item.valueChanged.connect(function(index, value) { if (index >= 0 && index < ids.length) root.setSetting("defaultPermission", ids[index]); });
                        }
                    }
                }
            }
        }
    }
}
