import QtQuick

Rectangle {
    id: root
    property var palette: null
    property real factor: 1
    property string glyph: ""
    property string label: ""
    property bool primary: false
    property bool danger: false
    property bool active: false
    signal clicked()
    function spin() { spinRotation.restart(); }

    implicitWidth: Math.max(30 * factor, content.implicitWidth + 22 * factor)
    implicitHeight: 30 * factor
    radius: 8 * factor
    color: root.primary ? (root.palette ? root.palette.mauve : "#cba6f7")
         : root.active ? (root.palette ? root.palette.surface1 : "#45475a")
         : hover.hovered ? (root.palette ? root.palette.surface1 : "#45475a")
         : (root.palette ? root.palette.surface0 : "#313244")
    border.width: root.active ? factor : 0
    border.color: root.palette ? root.palette.mauve : "#cba6f7"
    scale: tap.pressed ? 0.975 : 1
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 170 } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6 * root.factor
        Text {
            id: glyphText
            visible: root.glyph.length > 0
            text: root.glyph
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 15 * root.factor
            color: root.primary ? (root.palette ? root.palette.base : "#1e1e2e")
                : root.danger ? "#f38ba8" : (root.palette ? root.palette.text : "#cdd6f4")
            RotationAnimation on rotation {
                id: spinRotation
                from: 0; to: 360; duration: 1200; loops: 1
                easing.type: Easing.InOutSine; running: false
            }
        }
        Text {
            visible: root.label.length > 0
            text: root.label
            font.family: root.palette ? root.palette.fontFamily : "sans-serif"
            font.pixelSize: 12 * root.factor
            font.weight: Font.DemiBold
            color: root.primary ? (root.palette ? root.palette.base : "#1e1e2e")
                : root.danger ? "#f38ba8" : (root.palette ? root.palette.text : "#cdd6f4")
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: root.clicked() }
}
