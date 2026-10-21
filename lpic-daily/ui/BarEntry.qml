import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root
    property var host: null

    readonly property var plugin: host ? host.pluginInstance : null
    readonly property var palette: host ? host.theme : null
    readonly property bool isVertical: host ? host.vertical : false
    readonly property color accent: palette ? (plugin && plugin.errorMessage !== "" ? palette.yellow : (plugin && plugin.hasStatus && plugin.remaining === 0 ? palette.green : palette.mauve)) : "#cba6f7"

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    GridLayout {
        id: content
        anchors.centerIn: parent
        columns: root.isVertical ? 1 : 2
        rows: root.isVertical ? 2 : 1
        rowSpacing: host ? host.s(1) : 1
        columnSpacing: host ? host.s(6) : 6

        LpiLogo {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: host ? host.s(host.compact ? 18 : 20) : 20
            Layout.preferredHeight: host ? host.s(host.compact ? 18 : 20) : 20
            tint: root.accent
        }

        Text {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: !root.plugin || !root.plugin.hasStatus ? "—" : (root.plugin.remaining === 0 ? "✓" : String(root.plugin.remaining))
            font.family: root.palette ? root.palette.fontFamily : "sans-serif"
            font.pixelSize: host ? host.s(host.compact ? 11 : 12) : 12
            font.weight: Font.DemiBold
            color: root.accent
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }
    }
}
