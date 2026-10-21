import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    property var provider: null
    property var theme: null
    property var hostServices: null
    property var popupRootObj: null
    property real scaleFactor: 1
    property string projectPath: provider && provider.recentProjects.length ? provider.recentProjects[0].path : ""
    property string promptText: ""
    property string selectedModel: provider ? provider.defaultModel : ""
    property string selectedPermission: provider ? provider.defaultPermission : ""

    signal closeRequested()

    color: "transparent"

    function reusable(name) {
        return hostServices && hostServices.pluginManager
            ? hostServices.pluginManager.reusableUrl(name)
            : "";
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
        item.subTextColor = theme.subtext0;
        item.cornerRadius = theme.borderRadius;
        item.fontPixelSize = 11 * scaleFactor;
    }

    function styleButton(item, accent, textColor) {
        if (!item || !theme) return;
        item.accentColor = accent;
        item.textColor = textColor;
        item.cornerRadius = theme.borderRadius;
        item.textFontSize = 11 * scaleFactor;
        item.horizontalPadding = 12 * scaleFactor;
    }

    function projectOptions() {
        const items = provider ? provider.recentProjects.map(p => p.path) : [];
        if (projectPath && items.indexOf(projectPath) < 0) items.unshift(projectPath);
        items.push("Choose directory…");
        return items;
    }

    function syncProjectPicker() {
        if (!projectPicker.item) return;
        projectPicker.item.options = projectOptions();
        const idx = projectPicker.item.options.indexOf(projectPath);
        projectPicker.item.currentIndex = idx >= 0 ? idx : 0;
    }

    onProjectPathChanged: syncProjectPicker()

    function modelOptions() {
        return provider ? provider.availableModels.map(m => m.name || m.id) : [];
    }

    function modelIndex() {
        if (!provider) return 0;
        const ids = provider.availableModels.map(m => m.id);
        const idx = ids.indexOf(selectedModel);
        return idx >= 0 ? idx : 0;
    }

    function permissionOptions() {
        return provider ? provider.availablePermissions.map(p => p.name || p.id) : [];
    }

    function permissionIndex() {
        if (!provider) return 0;
        const ids = provider.availablePermissions.map(p => p.id);
        const idx = ids.indexOf(selectedPermission);
        return idx >= 0 ? idx : 0;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10 * root.scaleFactor

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "New agent"
                color: root.theme.text
                font.family: root.theme.fontFamily
                font.pixelSize: 14 * root.scaleFactor
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Loader {
                Layout.preferredHeight: 30 * root.scaleFactor
                source: root.reusable("ClickButton.qml")
                onLoaded: {
                    item.buttonText = "Back";
                    item.buttonIcon = "󰁍";
                    root.styleButton(item, root.theme.surface0, root.theme.text);
                    item.clicked.connect(root.closeRequested);
                }
            }
        }

        Text {
            text: "Project"
            color: root.theme.subtext0
            font.family: root.theme.fontFamily
            font.pixelSize: 10 * root.scaleFactor
            font.bold: true
        }

        Loader {
            id: projectPicker
            Layout.fillWidth: true
            Layout.preferredHeight: 34 * root.scaleFactor
            source: root.reusable("Dropdown.qml")
            onLoaded: {
                root.syncProjectPicker();
                root.styleDropdown(item);
                item.valueChanged.connect(function(index, value) {
                    if (value === "Choose directory…") {
                        if (folderPicker.item) folderPicker.item.openWithOptionalPath(root.projectPath);
                    } else {
                        root.projectPath = value;
                    }
                });
            }
        }

        Text {
            text: "Prompt"
            color: root.theme.subtext0
            font.family: root.theme.fontFamily
            font.pixelSize: 10 * root.scaleFactor
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100 * root.scaleFactor
            radius: root.theme.borderRadius
            color: promptHover.hovered ? Qt.darker(root.theme.surface0, 1.14) : root.theme.surface0
            border.width: promptEdit.activeFocus ? 1 : 0
            border.color: root.theme.mauve
            clip: true

            Behavior on color { ColorAnimation { duration: 180 } }

            HoverHandler { id: promptHover; cursorShape: Qt.IBeamCursor }

            Flickable {
                anchors.fill: parent
                anchors.margins: 10 * root.scaleFactor
                contentWidth: width
                contentHeight: Math.max(height, promptEdit.implicitHeight)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: promptEdit
                    width: parent.width
                    text: root.promptText
                    color: root.theme.text
                    selectionColor: root.theme.mauve
                    selectedTextColor: root.theme.crust
                    font.family: root.theme.fontFamily
                    font.pixelSize: 11 * root.scaleFactor
                    wrapMode: TextEdit.Wrap
                    onTextChanged: root.promptText = text
                }

                Text {
                    visible: promptEdit.text.length === 0
                    text: "Prompt"
                    color: root.theme.subtext0
                    opacity: 0.45
                    font.family: root.theme.fontFamily
                    font.pixelSize: 11 * root.scaleFactor
                    anchors.left: parent.left
                    anchors.top: parent.top
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.scaleFactor

            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: 34 * root.scaleFactor
                source: root.reusable("Dropdown.qml")
                onLoaded: {
                    item.options = Qt.binding(function() { return root.modelOptions(); });
                    item.currentIndex = Qt.binding(function() { return root.modelIndex(); });
                    root.styleDropdown(item);
                    item.valueChanged.connect(function(index, value) {
                        if (root.provider && index >= 0 && index < root.provider.availableModels.length)
                            root.selectedModel = root.provider.availableModels[index].id;
                    });
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: 34 * root.scaleFactor
                source: root.reusable("Dropdown.qml")
                onLoaded: {
                    item.options = Qt.binding(function() { return root.permissionOptions(); });
                    item.currentIndex = Qt.binding(function() { return root.permissionIndex(); });
                    root.styleDropdown(item);
                    item.valueChanged.connect(function(index, value) {
                        if (root.provider && index >= 0 && index < root.provider.availablePermissions.length)
                            root.selectedPermission = root.provider.availablePermissions[index].id;
                    });
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8 * root.scaleFactor

            Loader {
                Layout.preferredHeight: 32 * root.scaleFactor
                source: root.reusable("ClickButton.qml")
                onLoaded: {
                    item.buttonText = "Cancel";
                    root.styleButton(item, root.theme.surface0, root.theme.text);
                    item.clicked.connect(root.closeRequested);
                }
            }

            Loader {
                Layout.preferredHeight: 32 * root.scaleFactor
                source: root.reusable("ClickButton.qml")
                onLoaded: {
                    item.buttonText = "Launch";
                    item.buttonIcon = "󰐊";
                    root.styleButton(item, root.theme.mauve, root.theme.crust);
                    item.enabled = Qt.binding(function() { return root.projectPath.length > 0; });
                    item.clicked.connect(function() {
                        root.provider.launch(root.projectPath, root.promptText, root.selectedModel, root.selectedPermission);
                        root.closeRequested();
                    });
                }
            }
        }
    }

    Loader {
        id: folderPicker
        property string pickerUrl: root.reusable("FilePicker.qml")
        onPickerUrlChanged: {
            if (pickerUrl) setSource(pickerUrl, {
                rootObj: root.popupRootObj || root,
                selectFolder: true,
                titleText: "Choose project directory"
            });
        }
        onLoaded: {
            item.fileSelected.connect(function(path, name) {
                if (path) root.projectPath = path;
            });
        }
    }
}
