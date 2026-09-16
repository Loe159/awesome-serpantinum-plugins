import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var host: null
    property string providerId: "codex"
    readonly property var provider: host && host.pluginInstance ? host.pluginInstance.providerById(providerId) : null
    readonly property bool waiting: provider ? provider.activeSessions.some(s => s.state === "Waiting") : false
    readonly property var visibleQuotas: provider ? provider.quotaItems.filter(q => (q.id !== "primary" || provider.show5hQuota) && (q.id !== "secondary" || provider.showWeeklyQuota)) : []
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    SequentialAnimation on opacity {
        running: root.waiting
        loops: Animation.Infinite
        NumberAnimation { to: 0.48; duration: 650; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 650; easing.type: Easing.InOutSine }
    }

    GridLayout {
        id: content
        anchors.centerIn: parent
        columns: host && host.vertical ? 1 : 2
        rows: host && host.vertical ? 2 : 1
        rowSpacing: host ? host.s(1) : 1
        columnSpacing: host ? host.s(6) : 6
        Text {
            Layout.alignment: Qt.AlignCenter
            text: provider ? provider.icon : "󰚩"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: host ? host.s(13) : 13
            color: host ? (root.waiting ? host.theme.yellow : host.theme.green) : "#a6e3a1"
        }
        Text {
            Layout.alignment: Qt.AlignCenter
            text: {
                if (!provider) return "—";
                let parts=[String(provider.activeSessions.length)];
                if (root.visibleQuotas.length) parts.push(root.visibleQuotas.map(q => q.remainingPercent + "%").join(" / "));
                return parts.join(" · ");
            }
            font.family: host ? host.theme.fontFamily : "sans-serif"
            font.pixelSize: host ? host.s(host.compact ? 11 : 12) : 12
            font.weight: Font.Bold
            color: host ? (root.waiting ? host.theme.yellow : host.theme.text) : "#cdd6f4"
        }
    }
}
