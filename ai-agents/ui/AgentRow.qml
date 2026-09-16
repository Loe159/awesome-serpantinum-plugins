import QtQuick

Rectangle {
    id: root
    property var session: ({})
    property var theme: null
    property real scaleFactor: 1
    signal activated()
    width: parent ? parent.width : 420
    height: 54 * scaleFactor
    radius: 8 * scaleFactor
    color: hover.hovered ? theme.surface0 : "transparent"

    function durationText(seconds) {
        const value = Number(seconds || 0);
        if (value < 60) return Math.floor(value) + "s";
        if (value < 3600) return Math.floor(value / 60) + "m";
        return Math.floor(value / 3600) + "h " + Math.floor((value % 3600) / 60) + "m";
    }
    function stateColor() {
        if (session.state === "Waiting") return theme.yellow;
        if (session.state === "Working") return theme.green;
        if (session.state === "Failed") return theme.red;
        return theme.overlay1;
    }
    Text { x: 8*root.scaleFactor; anchors.verticalCenter: parent.verticalCenter; text: root.session.state === "Waiting" ? "!" : "●"; color: root.stateColor(); font.pixelSize: 12*root.scaleFactor }
    Column {
        x: 28*root.scaleFactor; anchors.verticalCenter: parent.verticalCenter; width: parent.width-38*root.scaleFactor; spacing: 2*root.scaleFactor
        Text { width: parent.width; text: root.session.title || root.session.projectName || "Codex session"; elide: Text.ElideRight; color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: 12*root.scaleFactor; font.bold: true }
        Text { width: parent.width; text: (root.session.state || "Idle") + (root.session.model ? " · "+root.session.model : "") + (root.session.duration ? " · "+root.durationText(root.session.duration) : ""); elide: Text.ElideRight; color: root.theme.subtext0; font.family: root.theme.fontFamily; font.pixelSize: 10*root.scaleFactor }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.activated() }
    Rectangle {
        visible: hover.hovered && !!root.session.lastMessage
        z: 20; width: Math.min(360*root.scaleFactor, root.width-24*root.scaleFactor); height: msg.implicitHeight+18*root.scaleFactor
        x: root.width-width-6*root.scaleFactor; y: root.height+4*root.scaleFactor
        radius: 8*root.scaleFactor; color: root.theme.surface1; border.width: 1; border.color: root.theme.surface2
        Text { id: msg; anchors.fill: parent; anchors.margins: 9*root.scaleFactor; text: root.session.lastMessage || ""; wrapMode: Text.Wrap; maximumLineCount: 5; elide: Text.ElideRight; color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: 10*root.scaleFactor }
    }
}
