import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property var task
    property var palette: null
    property real factor: 1
    property bool editing: false
    signal completed(string taskId)
    signal renamed(string taskId, string title)
    signal editRequested(var task)
    signal postponed(string taskId)
    signal priorityRequested(var task)

    implicitHeight: 61 * factor
    radius: 9 * factor
    color: hover.hovered ? (palette ? palette.surface1 : "#45475a")
                         : (palette ? palette.surface0 : "#313244")
    Behavior on color { ColorAnimation { duration: 160 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10 * root.factor
        anchors.rightMargin: 8 * root.factor
        spacing: 10 * root.factor

        Rectangle {
            Layout.preferredWidth: 20 * root.factor
            Layout.preferredHeight: 20 * root.factor
            radius: width / 2
            color: "transparent"
            border.width: root.factor
            border.color: root.task.priority === 1 ? "#f38ba8"
                        : root.task.priority === 2 ? "#fab387"
                        : root.task.priority === 3 ? "#89b4fa"
                        : (root.palette ? root.palette.overlay1 : "#7f849c")
            Text { anchors.centerIn: parent; text: "✓"; opacity: boxTap.pressed ? 1 : 0; color: root.palette ? root.palette.text : "white" }
            TapHandler { id: boxTap; onTapped: root.completed(root.task.id) }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4 * root.factor
            TextInput {
                id: titleInput
                Layout.fillWidth: true
                visible: root.editing
                text: root.task.content
                color: root.palette ? root.palette.text : "#cdd6f4"
                font.family: root.palette ? root.palette.fontFamily : "sans-serif"
                font.pixelSize: 12 * root.factor
                selectByMouse: true
                onAccepted: { root.renamed(root.task.id, text); root.editing = false }
                Keys.onEscapePressed: root.editing = false
                onVisibleChanged: if (visible) { forceActiveFocus(); selectAll(); }
            }
            Text {
                visible: !root.editing
                Layout.fillWidth: true
                text: root.task.content
                elide: Text.ElideRight
                font.family: root.palette ? root.palette.fontFamily : "sans-serif"
                font.pixelSize: 12 * root.factor
                color: root.palette ? root.palette.text : "#cdd6f4"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 7 * root.factor
                Text {
                    visible: !!root.task.dueLabel
                    text: (root.task.overdue ? "󰃰 " : "󰃭 ") + root.task.dueLabel
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 10 * root.factor
                    color: root.task.overdue ? "#f38ba8" : (root.palette ? root.palette.subtext0 : "#a6adc8")
                }
                Text {
                    Layout.fillWidth: true
                    text: (root.task.projectName ? "● " + root.task.projectName : "")
                    font.family: root.palette ? root.palette.fontFamily : "sans-serif"
                    font.pixelSize: 10 * root.factor
                    elide: Text.ElideRight
                    color: root.palette ? root.palette.subtext0 : "#a6adc8"
                }
                Text {
                    visible: root.task.recurring
                    text: "󰑖"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 11 * root.factor
                    color: root.palette ? root.palette.subtext0 : "#a6adc8"
                }
            }
        }

        Row {
            spacing: 5 * root.factor
            opacity: hover.hovered ? 1 : 0
            enabled: hover.hovered
            Behavior on opacity { NumberAnimation { duration: 130 } }
            ControlButton { palette: root.palette; factor: root.factor; glyph: "󰏫"; onClicked: root.editing = true }
            ControlButton { palette: root.palette; factor: root.factor; glyph: "󰃯"; onClicked: root.postponed(root.task.id) }
            ControlButton { palette: root.palette; factor: root.factor; glyph: "󰐀"; onClicked: root.priorityRequested(root.task) }
            ControlButton { palette: root.palette; factor: root.factor; glyph: "󰇙"; onClicked: root.editRequested(root.task) }
        }
    }
    HoverHandler { id: hover }
}
