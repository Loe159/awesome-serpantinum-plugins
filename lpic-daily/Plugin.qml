import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "ui" as LPICUI

Item {
    id: root
    width: 0
    height: 0

    property var pluginMetadata: ({})
    property string pluginDirectory: ""
    property var hostServices: null

    property var statusData: null
    property string errorMessage: ""
    property string processError: ""
    property bool statusStale: false
    property bool panelVisible: false
    property bool panelOpen: false
    property string panelSection: "center"
    property string panelBarPosition: "top"
    property real panelBarThickness: 40
    property var panelScreen: null

    readonly property bool hasStatus: statusData !== null
    readonly property int remaining: hasStatus ? Number(statusData.session.remaining || 0) : 0
    readonly property var session: hasStatus ? statusData.session : ({})
    readonly property var progress: hasStatus ? statusData.progress : ({})
    readonly property var activity: hasStatus ? statusData.activity : ({})
    readonly property var nextActivity: hasStatus ? (statusData.session.next || null) : null

    QtObject {
        id: fallbackTheme
        property color base: "#1e1e2e"
        property color surface0: "#313244"
        property color surface1: "#45475a"
        property color text: "#cdd6f4"
        property color subtext0: "#a6adc8"
        property color overlay1: "#7f849c"
        property color mauve: "#cba6f7"
        property color green: "#a6e3a1"
        property color yellow: "#f9e2af"
        property string fontFamily: "sans-serif"
        property real borderRadius: 10
    }

    readonly property var theme: hostServices && hostServices.theme ? hostServices.theme : fallbackTheme
    function s(value) { return hostServices && hostServices.scaler ? hostServices.scaler.s(value) : value; }
    function alpha(color, value) { return Qt.rgba(color.r, color.g, color.b, value); }

    // French labels shared by the three session counters.
    function counted(value, singular, plural) {
        const count = Math.max(0, Number(value) || 0);
        return count + " " + (count === 1 ? singular : plural);
    }

    function terminalCommand() {
        if (!hostServices || !hostServices.config) return "kitty -e";
        const config = hostServices.config.getSetting("launcher", {});
        return config && config.terminalCommand ? config.terminalCommand : "kitty -e";
    }

    function syncPanelContext(host) {
        if (host && host.barSection) {
            panelSection = host.barSection;
        } else if (hostServices && hostServices.pluginManager) {
            panelSection = hostServices.pluginManager.barModuleSection("plugin:lpic-daily") || "center";
        } else {
            panelSection = "center";
        }
        if (host && host.barWindow) {
            panelBarPosition = host.barWindow.barPosition || "top";
            panelBarThickness = host.barWindow.barHeight || 40;
            panelScreen = host.barWindow.screen || null;
        } else {
            const cfg = hostServices && hostServices.config ? hostServices.config.getSetting("bar", {}) : {};
            panelBarPosition = cfg && cfg.position ? cfg.position : "top";
            panelBarThickness = cfg && cfg.height ? Number(cfg.height) : 40;
            if (!panelScreen && Quickshell.screens && Quickshell.screens.length) {
                panelScreen = Quickshell.screens[0];
            }
        }
    }

    function refresh() {
        if (statusProcess.running) return;
        processError = "";
        statusProcess.command = ["lpic", "status", "--json"];
        statusProcess.running = true;
    }

    function activateBar(host) {
        if (panelOpen) {
            closePanel();
        } else {
            syncPanelContext(host);
            hideDelay.stop();
            panelVisible = true;
            openDelay.restart();
            refresh();
        }
    }

    function closePanel() {
        openDelay.stop();
        panelOpen = false;
        hideDelay.restart();
    }

    function launch(mode) {
        if (!hasStatus || statusStale) return;
        try {
            Quickshell.execDetached([
                "python3", pluginDirectory + "/services/launch.py",
                "--terminal", terminalCommand(), mode
            ]);
            closePanel();
        } catch (e) {
            errorMessage = "Impossible d'ouvrir le terminal : " + String(e);
        }
    }

    Timer { id: openDelay; interval: 12; repeat: false; onTriggered: root.panelOpen = true }
    Timer {
        id: hideDelay
        interval: 170
        repeat: false
        onTriggered: { if (!root.panelOpen) root.panelVisible = false; }
    }

    Timer {
        interval: root.panelVisible ? 5000 : 300000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    Process {
        id: statusProcess
        running: false
        command: ["lpic", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim();
                try {
                    const value = JSON.parse(raw);
                    if (value.schemaVersion !== 1 || !value.session || !value.progress || !value.activity) {
                        throw new Error("Format incompatible");
                    }
                    root.statusData = value;
                    root.statusStale = false;
                    root.errorMessage = "";
                } catch (e) {
                    root.statusStale = true;
                    root.errorMessage = "Statistiques LPIC Daily indisponibles";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.processError = this.text.trim()
        }
        onExited: function(code) {
            if (code !== 0) {
                root.statusStale = true;
                root.errorMessage = root.processError || "Commande lpic status indisponible";
            }
        }
    }

    PanelWindow {
        id: panel
        visible: root.panelVisible
        screen: root.panelScreen || (Quickshell.screens && Quickshell.screens.length ? Quickshell.screens[0] : null)
        color: "transparent"
        WlrLayershell.namespace: "serpantinum-plugin-lpic-daily"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors { top: true; bottom: true; left: true; right: true }

        // Full-screen input region allows one click outside to dismiss the popup.
        mask: Region { item: root.panelVisible ? dismissSurface : null }

        Item {
            id: dismissSurface
            anchors.fill: parent
            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) {
                    if (mouse.x < card.x || mouse.x > card.x + card.width
                            || mouse.y < card.y || mouse.y > card.y + card.height) {
                        root.closePanel();
                    }
                }
            }
        }

        Rectangle {
            id: card
            z: 1
            width: Math.min(root.s(370), Math.max(root.s(280), panel.width - root.s(24)))
            height: content.implicitHeight + root.s(36)
            radius: Math.max(root.s(12), root.s(root.theme.borderRadius * 1.7))
            color: root.theme.base
            border.width: root.s(1)
            border.color: root.theme.surface1

            x: {
                const gap = root.s(12);
                if (root.panelBarPosition === "left") return root.panelBarThickness + gap;
                if (root.panelBarPosition === "right") return Math.max(gap, panel.width - width - root.panelBarThickness - gap);
                if (root.panelSection === "left") return gap;
                if (root.panelSection === "right") return Math.max(gap, panel.width - width - gap);
                return Math.max(gap, (panel.width - width) / 2);
            }
            y: {
                const gap = root.s(12);
                if (root.panelBarPosition === "top") return root.panelBarThickness + gap;
                if (root.panelBarPosition === "bottom") return Math.max(gap, panel.height - height - root.panelBarThickness - gap);
                if (root.panelSection === "left") return gap;
                if (root.panelSection === "right") return Math.max(gap, panel.height - height - gap);
                return Math.max(gap, (panel.height - height) / 2);
            }
            opacity: root.panelOpen ? 1 : 0
            scale: root.panelOpen ? 1 : 0.975
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
            transform: Translate {
                y: root.panelOpen ? 0 : (root.panelBarPosition === "bottom" ? root.s(7) : -root.s(7))
                Behavior on y { NumberAnimation { duration: 230; easing.type: Easing.OutQuint } }
            }

            ColumnLayout {
                id: content
                x: root.s(18)
                y: root.s(17)
                width: parent.width - root.s(36)
                spacing: root.s(13)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(10)

                    Rectangle {
                        Layout.preferredWidth: root.s(34)
                        Layout.preferredHeight: root.s(34)
                        radius: root.s(9)
                        color: root.theme.surface0
                        LPICUI.LpiLogo {
                            anchors.centerIn: parent
                            width: root.s(23)
                            height: root.s(23)
                            tint: root.theme.mauve
                        }
                    }
                    Text {
                        text: "LPIC Daily"
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.s(15)
                        font.weight: Font.DemiBold
                        color: root.theme.text
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        id: refreshButton
                        Layout.preferredWidth: root.s(29)
                        Layout.preferredHeight: root.s(29)
                        radius: root.s(8)
                        color: refreshHover.hovered ? root.theme.surface1 : root.theme.surface0
                        Behavior on color { ColorAnimation { duration: 170 } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(15)
                            color: root.theme.text
                            RotationAnimation on rotation {
                                from: 0; to: 360; duration: 900; loops: Animation.Infinite
                                running: statusProcess.running
                            }
                        }
                        HoverHandler { id: refreshHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.refresh() }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.s(3)
                    RowLayout {
                        spacing: root.s(7)
                        Text {
                            text: root.hasStatus ? String(root.remaining) : "—"
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(31)
                            font.weight: Font.Bold
                            color: root.theme.text
                        }
                        Text {
                            text: root.hasStatus && root.remaining === 0 ? "aucune activité due" : (root.remaining === 1 ? "activité restante" : "activités restantes")
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(13)
                            color: root.theme.subtext0
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.hasStatus
                            ? ([root.counted(root.session.reviews, "révision", "révisions"), root.counted(root.session.practice, "consolidation", "consolidations"), root.counted(root.session.new, "nouveau", "nouveaux")].join(" · "))
                            : "En attente des statistiques"
                        elide: Text.ElideRight
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.s(11)
                        color: root.theme.subtext0
                    }
                }

                Rectangle {
                    id: nextCard
                    Layout.fillWidth: true
                    implicitHeight: root.s(85)
                    radius: root.s(10)
                    color: nextHover.hovered && root.nextActivity && !root.statusStale
                        ? root.theme.surface1 : root.theme.surface0
                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        spacing: root.s(5)
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "À SUIVRE"
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.s(10)
                                font.weight: Font.DemiBold
                                color: root.theme.subtext0
                            }
                            Text {
                                text: !root.nextActivity ? "" :
                                    (root.nextActivity.kind === "new" ? "Nouveau" :
                                    (root.nextActivity.kind === "review" ? "Révision" : "Consolidation"))
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.s(10)
                                color: root.theme.mauve
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.nextActivity
                                ? root.nextActivity.objectiveId + " · " + root.nextActivity.title
                                : (root.hasStatus ? "Tout est à jour" : "Chargement…")
                            elide: Text.ElideRight
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(13)
                            font.weight: Font.DemiBold
                            color: root.theme.text
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: !root.nextActivity ? "Aucune recommandation en attente" :
                                    (root.nextActivity.actionKind === "lab" ? "Lab pratique" :
                                    (root.nextActivity.actionKind === "lesson" ? "Cours" : "Question"))
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.s(11)
                                color: root.theme.subtext0
                            }
                            Text {
                                visible: !!root.nextActivity && root.nextActivity.actionKind !== "" && !root.statusStale
                                text: "󰁔"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(16)
                                color: root.theme.subtext0
                            }
                        }
                    }
                    HoverHandler { id: nextHover; enabled: !!root.nextActivity && !root.statusStale; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        enabled: !!root.nextActivity && root.nextActivity.actionKind !== "" && !root.statusStale
                        onTapped: root.launch("next")
                    }
                }

                Rectangle {
                    id: launchButton
                    Layout.fillWidth: true
                    implicitHeight: root.s(40)
                    radius: root.s(10)
                    opacity: root.hasStatus && !root.statusStale ? 1 : 0.48
                    color: launchHover.hovered ? Qt.lighter(root.theme.mauve, 1.09) : root.theme.mauve
                    Behavior on color { ColorAnimation { duration: 180 } }
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: root.s(9)
                        Text {
                            text: "󰆍"
                            color: root.theme.base
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(17)
                        }
                        Text {
                            text: "Ouvrir LPIC Daily"
                            color: root.theme.base
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                        }
                    }
                    HoverHandler { id: launchHover; enabled: root.hasStatus && !root.statusStale; cursorShape: Qt.PointingHandCursor }
                    TapHandler { enabled: root.hasStatus && !root.statusStale; onTapped: root.launch("dashboard") }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: root.s(1); color: root.theme.surface1 }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Progression"
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.s(13)
                        font.weight: Font.DemiBold
                        color: root.theme.text
                    }
                    Text {
                        text: "󰈑  " + (root.hasStatus ? root.activity.streakDays : 0) + " jours"
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.s(11)
                        color: root.theme.subtext0
                    }
                }

                Repeater {
                    model: [
                        {name: "Couverture", value: root.hasStatus ? root.progress.coveragePercent : 0},
                        {name: "Maîtrise", value: root.hasStatus ? root.progress.masteryPercent : 0}
                    ]
                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: root.s(5)
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.s(11)
                                color: root.theme.subtext0
                            }
                            Text {
                                text: modelData.value + "%"
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.s(11)
                                font.weight: Font.DemiBold
                                color: root.theme.text
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: root.s(5)
                            radius: height / 2
                            color: root.theme.surface1
                            Rectangle {
                                height: parent.height
                                width: parent.width * Math.max(0, Math.min(100, modelData.value)) / 100
                                radius: height / 2
                                color: root.theme.mauve
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: root.s(1); color: root.theme.surface1 }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "14 derniers jours"
                        color: root.theme.subtext0
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.s(11)
                    }
                    Row {
                        spacing: root.s(3)
                        Repeater {
                            model: root.hasStatus && root.activity.last14Days ? root.activity.last14Days : []
                            Rectangle {
                                required property var modelData
                                width: root.s(10)
                                height: root.s(15)
                                radius: root.s(3)
                                color: modelData.count === 0 ? root.theme.surface1 : root.theme.mauve
                                opacity: modelData.count === 0 ? 1 : 0.25 + 0.75 * Math.min(modelData.count / 4, 1)
                                Behavior on opacity { NumberAnimation { duration: 220 } }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.errorMessage !== ""
                    text: root.errorMessage + (root.statusStale && root.hasStatus ? " · dernières données conservées" : "")
                    wrapMode: Text.WordWrap
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.s(10)
                    color: root.theme.yellow
                }
            }
        }
    }
}
