//  nightcity — bar v0.2
//  Colours and type come from Theme.qml. Never hardcode a hex value here.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

ShellRoot {

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    PanelWindow {
        anchors { top: true; left: true; right: true }
        implicitHeight: 30
        exclusiveZone: 30
        color: Theme.bg

        // single hairline under the bar: Neomilitarism, no boxes
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.hairline
        }

        // ---- left: workspaces, live from Hyprland ----
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                text: "WS"
                color: Theme.muted
                font.family: Theme.faceHeader
                font.weight: Font.Medium
                font.pixelSize: Theme.sizeLabel
                font.letterSpacing: 1.5
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: Hyprland.workspaces

                delegate: Text {
                    required property HyprlandWorkspace modelData
                    readonly property bool isFocused:
                        Hyprland.focusedWorkspace?.id === modelData.id

                    visible: modelData.id > 0          // hide special workspaces
                    text: String(modelData.id).padStart(2, "0")
                    color: isFocused ? Theme.body : Theme.spot
                    font.family: Theme.faceData
                    font.pixelSize: Theme.sizeData
                    anchors.verticalCenter: parent.verticalCenter

                    // cyan tick under the focused workspace (cyan = activity)
                    Rectangle {
                        visible: parent.isFocused
                        anchors.top: parent.bottom
                        anchors.topMargin: 2
                        width: parent.width
                        height: 2
                        color: Theme.dataFill
                    }
                }
            }
        }

        // ---- centre: memory ----
        Row {
            anchors.centerIn: parent
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
                width: 140
                height: 2
                color: Theme.hairline
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: parent.width * mem.fraction
                    height: parent.height
                    color: mem.state === "alert" ? Theme.alertFill
                         : mem.state === "warn"  ? Theme.warnFill
                         : Theme.dataFill
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

        // ---- right: clock ----
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
            color: Theme.body
            font.family: Theme.faceData
            font.pixelSize: Theme.sizeData
        }
    }

    // ---- memory: awk reads /proc/meminfo directly, no shell in between ----
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
