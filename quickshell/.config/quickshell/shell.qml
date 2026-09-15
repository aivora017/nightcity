//  nightcity — Quickshell test bar
//
//  PURPOSE: measure real-world RSS with actual content before committing to
//  Quickshell as the widget layer. This is a measurement harness, not a design.
//
//  Palette: every colour verified with scripts/apca.py. Do not change a colour
//  here without re-running that check.

import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    // ---- verified palette (see docs/design/RESEARCH-3-COLOUR.md) ----
    readonly property color cBg      : "#08090a"   // background
    readonly property color cBody    : "#e1e4e6"   // Lc -90.1  body
    readonly property color cSubtle  : "#c7ccd0"   // Lc -75.2  subtle
    readonly property color cMuted   : "#8d969e"   // Lc -45.0  muted
    readonly property color cSpot    : "#6d7780"   // Lc -30.0  spot
    readonly property color cRule    : "#4c5359"   // Lc -15.0  nontext
    readonly property color cAlert   : "#e02b28"   // fill only
    readonly property color cData    : "#00b4d8"   // fill only
    readonly property color cWarn    : "#d9861f"   // fill only

    PanelWindow {
        id: bar

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 26
        exclusiveZone: 26
        color: "transparent"

        // ---- background + single hairline rule (Neomilitarism: no boxes) ----
        Rectangle {
            anchors.fill: parent
            color: cBg

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: cRule
            }
        }

        // ---- left: workspace indicator ----
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 2
                height: 10
                color: cAlert
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "WS 01"
                color: cBody
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "02   03"
                color: cSpot
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ---- centre: memory, as a bar not a number ----
        Row {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "MEM"
                color: cMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 120
                height: 2
                color: "#2a2e33"
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: parent.width * memPoll.fraction
                    height: parent.height
                    color: memPoll.fraction > 0.85 ? cAlert
                         : memPoll.fraction > 0.65 ? cWarn
                         : cData
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
            }

            Text {
                text: memPoll.label
                color: cSubtle
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ---- right: clock ----
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: clockPoll.text
            color: cBody
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
        }
    }

    // ---- clock: poll `date` once a second ----
    Process {
        id: clockPoll
        property string text: "--:--:--"
        command: ["date", "+%H:%M:%S"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: clockPoll.text = this.text.trim()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockPoll.running = true
    }

    // ---- memory: parse /proc/meminfo ----
    Process {
        id: memPoll
        property real fraction: 0
        property string label: "-- / --"
        command: ["sh", "-c",
            "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"%.3f %.1f %.1f\", (t-a)/t, (t-a)/1048576, t/1048576}' /proc/meminfo"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(" ");
                if (p.length === 3) {
                    memPoll.fraction = parseFloat(p[0]);
                    memPoll.label = p[1] + " / " + p[2];
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: memPoll.running = true
    }
}
