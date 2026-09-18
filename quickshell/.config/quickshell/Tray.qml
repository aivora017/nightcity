//  nightcity — right side of the bar
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Row {
    id: tray
    spacing: 4

    // ================= DATA =================

    // bind the default speaker so its volume is tracked live
    PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    // wifi link quality from the kernel: -1 = not connected
    property int wifiQuality: -1
    Process {
        id: wifiPoll
        command: ["awk", "NR==3 { gsub(/\\./, \"\", $3); print $3 }", "/proc/net/wireless"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                tray.wifiQuality = t === "" ? -1 : parseInt(t);
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: wifiPoll.running = true }

    // runs wpctl for volume changes
    Process { id: wp }
    function wpctl(args) {
        wp.command = ["wpctl"].concat(args);
        wp.running = true;
    }

    function icon(codepoint) { return String.fromCodePoint(codepoint) }

    // ================= REUSABLE BUTTON =================
    component TrayButton: Rectangle {
        id: btn
        property alias hovered: area.containsMouse
        signal clicked(var mouse)
        signal scrolled(var wheel)

        height: 36
        radius: 11
        anchors.verticalCenter: parent.verticalCenter
        color: area.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : "transparent"
        Behavior on color { ColorAnimation { duration: 180 } }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => btn.clicked(mouse)
            onWheel: wheel => btn.scrolled(wheel)
        }
    }

    // ================= SEARCH =================
    TrayButton {
        width: 190
        border.width: 1
        border.color: "#17ffffff"
        onClicked: { NcState.launcherMode = "search"; NcState.launcherOpen = true }

        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text {
                text: tray.icon(0xF0349)
                color: Theme.accent
                font.family: Theme.faceData
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Search"
                color: Theme.muted
                font.family: Theme.faceHeader
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Rectangle {
            anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
            width: keyHint.width + 12
            height: 22
            radius: 6
            color: "#1affffff"
            border.width: 1
            border.color: "#26ffffff"
            Text {
                id: keyHint
                anchors.centerIn: parent
                text: "Super Space"
                color: Theme.subtle
                font.family: Theme.faceData
                font.pixelSize: 9
            }
        }
    }

    // ================= HEALTH =================
    TrayButton {
        width: 36
        onClicked: console.log("health dashboard arrives in phase 8")
        Text {
            anchors.centerIn: parent
            text: tray.icon(0xF05F6)
            color: Theme.body
            font.family: Theme.faceData
            font.pixelSize: 17
        }
        Rectangle {
            width: 8; height: 8; radius: 4
            color: Theme.spot                   // grey until the doctor runs
            border.width: 2
            border.color: "#cc08090a"
            anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 6 }
        }
    }

    Rectangle {
        width: 1; height: 24
        color: "#22ffffff"
        anchors.verticalCenter: parent.verticalCenter
    }

    // ================= CONNECTIONS =================
    TrayButton {
        width: netRow.width + 22
        border.width: 1
        border.color: "#12ffffff"
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                tray.wpctl(["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
            else
                console.log("connections panel arrives in phase 7");
        }
        onScrolled: wheel => tray.wpctl(["set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@",
                                         wheel.angleDelta.y > 0 ? "5%+" : "5%-"])

        Row {
            id: netRow
            anchors.centerIn: parent
            spacing: 10

            Text {  // wifi
                text: tray.icon(tray.wifiQuality < 0 ? 0xF05AA : 0xF05A9)
                color: tray.wifiQuality < 0 ? Theme.spot : Theme.body
                font.family: Theme.faceData
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {  // bluetooth — goes live in phase 7
                text: tray.icon(0xF00AF)
                color: Theme.spot
                font.family: Theme.faceData
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {  // speaker
                text: tray.icon(tray.muted ? 0xF0581 : 0xF057E)
                color: tray.muted ? Theme.spot : Theme.body
                font.family: Theme.faceData
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: tray.muted ? "mute" : tray.volume + "%"
                color: Theme.subtle
                font.family: Theme.faceData
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ================= NOTIFICATIONS =================
    TrayButton {
        width: 36
                onClicked: { NcState.centreOpen = !NcState.centreOpen; NcState.unread = 0 }
        Text {
            anchors.centerIn: parent
            text: tray.icon(0xF009A)
            color: Theme.body
            font.family: Theme.faceData
            font.pixelSize: 17
        }
        Rectangle {
            visible: NcState.unread > 0
            anchors { top: parent.top; right: parent.right; topMargin: 3; rightMargin: 2 }
            width: Math.max(16, badge.width + 8); height: 16; radius: 8
            color: Theme.accent
            Text {
                id: badge
                anchors.centerIn: parent
                text: NcState.unread
                color: "#07080f"
                font.family: Theme.faceData
                font.pixelSize: 10
            }
        }
    }
}
