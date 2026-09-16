import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property var provider: null
    property var theme: null
    property real scaleFactor: 1
    property string projectPath: provider && provider.recentProjects.length ? provider.recentProjects[0].path : ""
    property string promptText: ""
    property string selectedModel: provider ? provider.defaultModel : ""
    property string selectedPermission: provider ? provider.defaultPermission : ""
    signal closeRequested()
    color: "transparent"

    ColumnLayout {
        anchors.fill: parent; spacing: 8*root.scaleFactor
        Text { text: "New agent"; color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: 14*root.scaleFactor; font.bold: true }
        ComboBox {
            Layout.fillWidth: true; model: root.provider ? root.provider.recentProjects.map(p => p.path).concat(["Choose folder…"]) : ["Choose folder…"]
            onActivated: function(index) { if (currentText === "Choose folder…") folderPicker.running=true; else root.projectPath=currentText; }
        }
        TextField { Layout.fillWidth: true; placeholderText: "Project path"; text: root.projectPath; onTextEdited: root.projectPath=text }
        TextArea { Layout.fillWidth: true; Layout.preferredHeight: 74*root.scaleFactor; placeholderText: "Prompt"; wrapMode: TextEdit.Wrap; onTextChanged: root.promptText=text }
        RowLayout { Layout.fillWidth: true
            ComboBox { Layout.fillWidth: true; model: root.provider ? root.provider.availableModels.map(m => m.name) : []; onActivated: function(index) { root.selectedModel=root.provider.availableModels[index].id; } }
            ComboBox { Layout.fillWidth: true; model: root.provider ? root.provider.availablePermissions.map(p => p.id) : []; onActivated: function(index) { root.selectedPermission=root.provider.availablePermissions[index].id; } }
        }
        RowLayout { Layout.alignment: Qt.AlignRight
            Button { text: "Cancel"; onClicked: root.closeRequested() }
            Button { text: "Launch"; enabled: root.projectPath.length>0; onClicked: { root.provider.launch(root.projectPath,root.promptText,root.selectedModel,root.selectedPermission); root.closeRequested(); } }
        }
    }
    Process {
        id: folderPicker
        command: ["bash","-lc","if command -v zenity >/dev/null; then zenity --file-selection --directory --title='Choose Codex project'; elif command -v kdialog >/dev/null; then kdialog --getexistingdirectory ~; fi"]
        stdout: StdioCollector { onStreamFinished: { const p=this.text.trim(); if (p) root.projectPath=p; } }
    }
}
