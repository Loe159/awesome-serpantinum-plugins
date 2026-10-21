import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var host: null
    property string providerId: "codex"
    readonly property var provider: host && host.pluginInstance ? host.pluginInstance.providerById(providerId) : null
    readonly property bool waiting: provider ? provider.activeSessions.some(s => s.state === "Waiting") : false
    readonly property var visibleQuotas: provider ? provider.quotaItems.filter(q => (q.id !== "primary" || provider.show5hQuota) && (q.id !== "secondary" || provider.showWeeklyQuota)) : []
    implicitWidth: content.implicitWidth > 0 ? content.implicitWidth : (provider ? (host ? host.s(92) : 92) : (host ? host.s(28) : 28))
    implicitHeight: content.implicitHeight > 0 ? content.implicitHeight : (host ? host.s(18) : 18)

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
        Image {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: host ? host.s(15) : 15
            Layout.preferredHeight: host ? host.s(15) : 15
            source: host && host.pluginInstance
                ? "file://" + host.pluginInstance.pluginDirectory + "/assets/openai.svg"
                : ""
            sourceSize: Qt.size(host ? host.s(30) : 30, host ? host.s(30) : 30)
            fillMode: Image.PreserveAspectFit
            opacity: root.waiting ? 0.9 : 1.0
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
