//  nightcity — workspace overview: every workspace as a live map of its windows
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: NcState.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.overviewOpen

    property var clients: []
    property int selected: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property int count: 5

    Process {
        id: fetch
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.clients = JSON.parse(this.text) } catch (e) { root.clients = [] }
            }
        }
    }
    onVisibleChanged: if (visible) {
        selected = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
        fetch.running = true;
        keys.forceActiveFocus();
    }

    function close() { NcState.overviewOpen = false }
    function go(id) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        close();
    }
    function windowsOn(id) { return clients.filter(c => c.workspace && c.workspace.id === id) }

    // ---------- backdrop ----------
    Rectangle {
        anchors.fill: parent
        color: "#c405060a"
        opacity: NcState.overviewOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) root.close();
            else if (e.key === Qt.Key_Right) root.selected = Math.min(root.count, root.selected + 1);
            else if (e.key === Qt.Key_Left) root.selected = Math.max(1, root.selected - 1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.go(root.selected);
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_5) root.go(e.key - Qt.Key_0);
            else return;
            e.accepted = true;
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 22

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "WORKSPACES"
            color: Theme.spot
            font.family: Theme.faceHeader
            font.pixelSize: 12
            font.letterSpacing: 3
        }

        Row {
            spacing: 16

            Repeater {
                model: root.count

                delegate: Rectangle {
                    id: card
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property var wins: root.windowsOn(wsId)
                    readonly property bool isSel: root.selected === wsId
                    readonly property bool isCur: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId

                    width: Math.min(236, (root.width - 160) / root.count)
                    height: width * (Screen.height / Screen.width) + 34
                    radius: 18
                    color: Theme.glassTint
                    border.width: isSel ? 2 : 1
                    border.color: isSel ? Theme.accent : Theme.glassBorder
                    scale: isSel ? 1.06 : 1
                    Behavior on scale { SpringAnimation { spring: 4; damping: 0.3 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    // staggered entrance
                    opacity: 0
                    Connections {
                        target: root
                        function onVisibleChanged() {
                            if (root.visible) { card.opacity = 0; enter.start() }
                        }
                    }
                    SequentialAnimation {
                        id: enter
                        PauseAnimation { duration: card.index * 45 }
                        ParallelAnimation {
                            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 260 }
                            NumberAnimation { target: card; property: "y"; from: 24; to: 0; duration: 420; easing.type: Easing.OutBack }
                        }
                    }

                    // header
                    Row {
                        anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 9 }
                        spacing: 8
                        Text {
                            text: card.wsId
                            color: card.isCur ? Theme.accent : "white"
                            font.family: Theme.faceDisplay
                            font.pixelSize: 13
                        }
                        Text {
                            text: card.wins.length === 0 ? "empty" : card.wins.length + (card.wins.length === 1 ? " window" : " windows")
                            color: Theme.spot
                            font.family: Theme.faceData
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // the map: screen scaled into the card
                    Rectangle {
                        id: map
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                        height: parent.height - 34
                        radius: 11
                        color: "#30000000"
                        clip: true
                        readonly property real sx: width / Screen.width
                        readonly property real sy: height / Screen.height

                        Repeater {
                            model: card.wins
                            delegate: Rectangle {
                                required property var modelData
                                x: modelData.at[0] * map.sx
                                y: modelData.at[1] * map.sy
                                width: Math.max(18, modelData.size[0] * map.sx)
                                height: Math.max(14, modelData.size[1] * map.sy)
                                radius: 5
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                                border.width: 1
                                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: Math.min(22, parent.height - 6)
                                    source: Quickshell.iconPath((modelData.class || "").toLowerCase(), "application-x-executable")
                                }
                                Text {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 3 }
                                    visible: parent.height > 40
                                    text: modelData.title
                                    color: Theme.subtle
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Theme.faceData
                                    font.pixelSize: 8
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = card.wsId
                        onClicked: root.go(card.wsId)
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "← → select   ·   Enter or 1–5 to go   ·   Esc to close"
            color: Theme.spot
            font.family: Theme.faceData
            font.pixelSize: 11
        }
    }
}
