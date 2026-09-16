import QtQuick

Rectangle {
    id: root
    property var quota: ({})
    property var theme: null
    property real scaleFactor: 1
    width: parent ? (parent.width-8*scaleFactor)/2 : 200
    height: 72*scaleFactor
    radius: 10*scaleFactor
    color: theme.surface0
    function resetText() {
        if (!quota.resetsAt) return "";
        const sec=quota.resetsAt-Math.floor(Date.now()/1000);
        if (sec>0 && sec<86400) return "Reset in "+Math.floor(sec/3600)+"h "+Math.floor((sec%3600)/60)+"m";
        return "Reset "+new Date(quota.resetsAt*1000).toLocaleDateString(Qt.locale(), "MMM d");
    }
    Column { anchors.fill: parent; anchors.margins: 10*root.scaleFactor; spacing: 3*root.scaleFactor
        Text { text: root.quota.label || "Quota"; color: root.theme.subtext0; font.family: root.theme.fontFamily; font.pixelSize: 10*root.scaleFactor; font.bold: true }
        Text { text: (root.quota.remainingPercent !== undefined ? root.quota.remainingPercent : "—")+"% remaining"; color: root.theme.text; font.family: root.theme.fontFamily; font.pixelSize: 14*root.scaleFactor; font.bold: true }
        Text { text: root.resetText(); color: root.theme.overlay1; font.family: root.theme.fontFamily; font.pixelSize: 9*root.scaleFactor }
    }
}
