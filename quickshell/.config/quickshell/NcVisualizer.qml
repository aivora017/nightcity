//  nightcity — audio visualizer window; cava runs only while this is open
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-viz"
    WlrLayershell.layer: WlrLayer.Top
    anchors { bottom: true }
    margins { bottom: 40 }
    implicitWidth: Math.min(Screen.width - 120, 980)
    implicitHeight: 300
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.vizOpen
    mask: Region { item: card }

    readonly property int n: 64
    property var levels: []
    property var peaks: []

    Process {
        id: cava
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/nightcity-viz.conf"]
        running: NcState.vizOpen
        stdout: SplitParser {
            onRead: data => {
                const v = data.split(";");
                if (v.length < root.n) return;
                const lv = v.slice(0, root.n).map(x => Number(x) / 1000);
                // peak caps rise instantly and fall slowly
                const pk = root.peaks.length === root.n ? root.peaks.slice() : new Array(root.n).fill(0);
                for (let i = 0; i < root.n; i++) pk[i] = Math.max(lv[i], pk[i] - 0.012);
                root.levels = lv;
                root.peaks = pk;
            }
        }
    }
    onVisibleChanged: if (!visible) { levels = []; peaks = [] }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 26
        color: Theme.glassTint
        border.width: 1
        border.color: Theme.glassBorder
        opacity: NcState.vizOpen ? 1 : 0
        scale: NcState.vizOpen ? 1 : 0.94
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.35 } }

        // corner brackets, same language as the bar
        Repeater {
            model: 4
            delegate: Item {
                required property int index
                width: 14; height: 14
                x: index % 2 === 0 ? 10 : card.width - 24
                y: index < 2 ? 10 : card.height - 24
                opacity: 0.8
                Rectangle { width: 14; height: 2; color: Theme.accent; y: index < 2 ? 0 : 12 }
                Rectangle { width: 2; height: 14; color: Theme.accent; x: index % 2 === 0 ? 0 : 12 }
            }
        }

        Text {
            anchors { left: parent.left; top: parent.top; leftMargin: 32; topMargin: 18 }
            text: "SIGNAL"
            color: Theme.spot
            font.family: Theme.faceHeader
            font.pixelSize: 11
            font.letterSpacing: 3
        }
        Text {
            anchors { right: parent.right; top: parent.top; rightMargin: 32; topMargin: 16 }
            text: "close"
            color: Theme.spot
            font.family: Theme.faceData
            font.pixelSize: 11
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: NcState.vizOpen = false }
        }

        // centre line the bars grow from
        Rectangle {
            id: axis
            anchors { left: parent.left; right: parent.right; leftMargin: 32; rightMargin: 32 }
            y: parent.height * 0.62
            height: 1
            color: Theme.hairline
        }

        Row {
            id: bars
            anchors { left: parent.left; right: parent.right; leftMargin: 32; rightMargin: 32 }
            y: axis.y
            spacing: 3
            readonly property real bw: (width - spacing * (root.n - 1)) / root.n
            readonly property real maxUp: axis.y - 50
            readonly property real maxDown: card.height - axis.y - 22

            Repeater {
                model: root.n
                delegate: Item {
                    required property int index
                    width: bars.bw
                    height: 1
                    readonly property real lv: root.levels[index] || 0
                    readonly property real pk: root.peaks[index] || 0

                    // main bar, growing upward
                    Rectangle {
                        width: parent.width
                        radius: width / 2
                        height: Math.max(3, parent.lv * bars.maxUp)
                        y: -height
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accent3 }
                            GradientStop { position: 0.55; color: Theme.accent }
                            GradientStop { position: 1.0; color: Theme.accent2 }
                        }
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }
                    // peak cap
                    Rectangle {
                        width: parent.width
                        height: 2
                        radius: 1
                        y: -Math.max(5, parent.pk * bars.maxUp) - 4
                        color: "white"
                        opacity: parent.pk > 0.02 ? 0.85 : 0
                    }
                    // reflection, fading downward
                    Rectangle {
                        width: parent.width
                        radius: width / 2
                        y: 3
                        height: Math.max(2, parent.lv * bars.maxDown)
                        opacity: 0.35
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accent }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.levels.length === 0 || Math.max.apply(null, root.levels) < 0.01
            text: "Waiting for audio"
            color: Theme.spot
            font.family: Theme.faceData
            font.pixelSize: 12
        }
    }
}
