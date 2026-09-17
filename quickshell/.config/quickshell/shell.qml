//  nightcity — glass bar v0.3
//  Colours and type come from Theme.qml. Never hardcode an accent here.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

ShellRoot {

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    PanelWindow {
        id: bar
        WlrLayershell.namespace: "nightcity-bar"
        anchors { top: true; left: true; right: true }
        margins { top: 10; left: 12; right: 12 }
        implicitHeight: 52
        exclusiveZone: 52
        color: "transparent"

        // ================= GLASS BODY =================
        Rectangle {
            id: glass
            anchors.fill: parent
            radius: 18
            color: Theme.glassTint
            border.width: 1
            border.color: Theme.glassBorder

            // soft light from above
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0;  color: "#1fffffff" }
                    GradientStop { position: 0.45; color: "#05ffffff" }
                    GradientStop { position: 1.0;  color: "#00ffffff" }
                }
            }

            // bright rim along the top edge
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 22; rightMargin: 22 }
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // flowing accent edge along the bottom (pattern repeats, so the loop is seamless)
            Item {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 24; rightMargin: 24 }
                height: 2
                clip: true
                Rectangle {
                    id: flow
                    width: parent.width * 2
                    height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.000; color: Theme.accent }
                        GradientStop { position: 0.166; color: Theme.accent3 }
                        GradientStop { position: 0.333; color: Theme.accent2 }
                        GradientStop { position: 0.500; color: Theme.accent }
                        GradientStop { position: 0.666; color: Theme.accent3 }
                        GradientStop { position: 0.833; color: Theme.accent2 }
                        GradientStop { position: 1.000; color: Theme.accent }
                    }
                    NumberAnimation on x { from: 0; to: -flow.width / 2; duration: 9000; loops: Animation.Infinite }
                }
            }

            // corner brackets
            Repeater {
                model: 4
                delegate: Item {
                    required property int index
                    width: 12; height: 12
                    x: index % 2 === 0 ? 5 : glass.width - 17
                    y: index < 2 ? 5 : glass.height - 17
                    opacity: 0.85
                    Rectangle { width: 12; height: 2; color: Theme.accent; y: index < 2 ? 0 : 10 }
                    Rectangle { width: 2; height: 12; color: Theme.accent; x: index % 2 === 0 ? 0 : 10 }
                }
            }
        }

        // ================= LEFT =================
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 12

            // NC button — opens the app drawer in phase 6
            Item {
                id: ncButton
                width: 38; height: 38
                anchors.verticalCenter: parent.verticalCenter
                scale: ncMouse.containsMouse ? 1.1 : 1.0
                Behavior on scale { SpringAnimation { spring: 4; damping: 0.3 } }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Theme.accent
                    opacity: ncMouse.containsMouse ? 0.18 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                Shape {
                    anchors.centerIn: parent
                    width: 32; height: 32
                    ShapePath {
                        strokeColor: Theme.accent
                        strokeWidth: 1.5
                        fillColor: "transparent"
                        startX: 16; startY: 1
                        PathLine { x: 29; y: 8.5 }
                        PathLine { x: 29; y: 23.5 }
                        PathLine { x: 16; y: 31 }
                        PathLine { x: 3;  y: 23.5 }
                        PathLine { x: 3;  y: 8.5 }
                        PathLine { x: 16; y: 1 }
                    }
                    RotationAnimation on rotation { from: 0; to: 360; duration: 24000; loops: Animation.Infinite }
                }
                Text {
                    anchors.centerIn: parent
                    text: "NC"
                    color: "white"
                    font.family: Theme.faceDisplay
                    font.pixelSize: 9
                }
                MouseArea {
                    id: ncMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: console.log("NC clicked — app drawer arrives in phase 6")
                }
            }

            // workspaces 1–5 with a spring indicator
            Rectangle {
                id: wsTrack
                readonly property int slot: 32
                readonly property int gap: 4
                readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

                width: 5 * slot + 4 * gap + 8
                height: 36
                radius: 12
                color: "#40000000"
                border.width: 1
                border.color: "#12ffffff"
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    visible: wsTrack.focusedId >= 1 && wsTrack.focusedId <= 5
                    width: wsTrack.slot; height: 28; radius: 9
                    y: 4
                    x: 4 + (wsTrack.focusedId - 1) * (wsTrack.slot + wsTrack.gap)
                    Behavior on x { SpringAnimation { spring: 3.5; damping: 0.28 } }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.accent }
                        GradientStop { position: 1.0; color: Theme.accent3 }
                    }
                }

                Row {
                    x: 4; y: 4
                    spacing: wsTrack.gap
                    Repeater {
                        model: 5
                        delegate: Item {
                            required property int index
                            readonly property int wsId: index + 1
                            readonly property bool focused: wsTrack.focusedId === wsId
                            readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)
                            width: wsTrack.slot; height: 28

                            Text {
                                anchors.centerIn: parent
                                text: parent.wsId
                                color: parent.focused ? "#07080f" : (parent.occupied ? Theme.body : Theme.spot)
                                font.family: Theme.faceData
                                font.pixelSize: 13
                                font.bold: parent.focused
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }
                            Rectangle {
                                visible: parent.occupied && !parent.focused
                                width: 4; height: 4; radius: 2
                                color: Theme.accent2
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1
                            }
                        }
                    }
                }
            }
        }

        // ================= CENTRE: clock =================
        Row {
            anchors.centerIn: parent
            spacing: 10

            Shape {
                width: 30; height: 30
                anchors.verticalCenter: parent.verticalCenter
                ShapePath {
                    strokeColor: "#1fffffff"; strokeWidth: 2.5; fillColor: "transparent"
                    PathAngleArc { centerX: 15; centerY: 15; radiusX: 12; radiusY: 12; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: Theme.accent; strokeWidth: 2.5; fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 15; centerY: 15; radiusX: 12; radiusY: 12
                        startAngle: -90
                        sweepAngle: 360 * clock.date.getSeconds() / 60
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: "white"
                    font.family: Theme.faceDisplay
                    font.pixelSize: 17
                    font.letterSpacing: 1
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    color: Theme.muted
                    font.family: Theme.faceHeader
                    font.pixelSize: 11
                }
            }
        }

        // ================= RIGHT: memory =================
        Row {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 10

            Text {
                text: "MEM"
                color: Theme.muted
                font.family: Theme.faceHeader
                font.weight: Font.Medium
                font.pixelSize: Theme.sizeLabel
                font.letterSpacing: 1.5
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 90; height: 4; radius: 2
                color: "#1fffffff"
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: parent.width * mem.fraction
                    height: parent.height
                    radius: 2
                    color: mem.state === "alert" ? Theme.alertFill
                         : mem.state === "warn"  ? Theme.warnFill
                         : Theme.accent
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
            }
            Text {
                text: mem.label
                color: mem.state === "alert" ? Theme.alertText
                     : mem.state === "warn"  ? Theme.warnText
                     : Theme.subtle
                font.family: Theme.faceData
                font.pixelSize: Theme.sizeData
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ================= DATA =================
    Process {
        id: mem
        property real fraction: 0
        property string label: "-.-G / -.-G"
        readonly property string state:
            fraction > 0.85 ? "alert" : fraction > 0.65 ? "warn" : "ok"

        command: ["awk",
            "/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.3f %.1f %.1f\", (t-a)/t, (t-a)/1048576, t/1048576}",
            "/proc/meminfo"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(" ");
                if (p.length === 3) {
                    mem.fraction = parseFloat(p[0]);
                    mem.label = p[1] + "G / " + p[2] + "G";
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: mem.running = true
    }
}
