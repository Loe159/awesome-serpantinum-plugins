import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var host: null
    readonly property var plugin: host ? host.pluginInstance : null
    readonly property var palette: host ? host.theme : null
    readonly property bool isVertical: host ? host.vertical : false

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    GridLayout {
        id: row
        anchors.centerIn: parent
        columns: root.isVertical ? 1 : 2
        rows: root.isVertical ? 2 : 1
        columnSpacing: root.host ? root.host.s(5) : 5
        rowSpacing: root.host ? root.host.s(3) : 3

        Image {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: root.host ? root.host.s(18) : 18
            Layout.preferredHeight: Layout.preferredWidth
            source: "../assets/todoist.svg"
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: !root.plugin || !root.plugin.connected ? "—" : String(root.plugin.todayCount)
            font.family: root.palette ? root.palette.fontFamily : "sans-serif"
            font.pixelSize: root.host ? root.host.s(12) : 12
            font.weight: Font.DemiBold
            color: root.plugin && root.plugin.stale
                ? (root.palette ? root.palette.yellow : "#f9e2af")
                : (root.palette ? root.palette.text : "#cdd6f4")
        }
    }
}
