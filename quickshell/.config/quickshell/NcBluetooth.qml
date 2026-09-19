//  nightcity — bluetooth scan, pair and connect
import Quickshell
import Quickshell.Io
import QtQuick

Column {
    id: bt
    spacing: 6

    property var devices: []

    Process {
        id: scanProc
        command: ["sh", "-c",
            "bluetoothctl --timeout 8 scan on >/dev/null 2>&1; " +
            "bluetoothctl devices | while read -r _ mac name; do " +
            "  info=$(bluetoothctl info \"$mac\"); " +
            "  c=$(echo \"$info\" | grep -c 'Connected: yes'); " +
            "  p=$(echo \"$info\" | grep -c 'Paired: yes'); " +
            "  echo \"$mac|$name|$c|$p\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.trim().split("\n")) {
                    if (line === "") continue;
                    const f = line.split("|");
                    if (!f[0]) continue;
                    out.push({ mac: f[0], name: f[1] || f[0], connected: f[2] === "1", paired: f[3] === "1" });
                }
                out.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired));
                bt.devices = out;
                NcState.btScanning = false;
            }
        }
    }

    function scan() {
        if (NcState.btScanning) return;
        NcState.btScanning = true;
        scanProc.running = true;
    }
    function act(d) {
        // pair first if needed, then trust and connect
        const cmd = d.connected
            ? "bluetoothctl disconnect " + d.mac
            : (d.paired ? "" : "bluetoothctl pair " + d.mac + "; bluetoothctl trust " + d.mac + "; ")
              + "bluetoothctl connect " + d.mac;
        Quickshell.execDetached(["sh", "-c", cmd]);
        rescan.restart();
    }
    Timer { id: rescan; interval: 4000; onTriggered: bt.scan() }
    Component.onCompleted: scan()

    Row {
        width: parent.width
        Text {
            text: "BLUETOOTH"
            color: Theme.spot
            font.family: Theme.faceHeader
            font.pixelSize: 11
            font.letterSpacing: 1.5
        }
        Item { width: parent.width - 170; height: 1 }
        Text {
            text: NcState.btScanning ? "scanning" : "scan"
            color: Theme.accent
            font.family: Theme.faceData
            font.pixelSize: 11
            opacity: NcState.btScanning ? 0.6 : 1
            SequentialAnimation on opacity {
                running: NcState.btScanning
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 600 }
                NumberAnimation { to: 0.4; duration: 600 }
            }
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: bt.scan() }
        }
    }

    Text {
        visible: bt.devices.length === 0
        text: NcState.btPowered ? "No devices found yet" : "Bluetooth is off"
        color: Theme.spot
        font.family: Theme.faceData
        font.pixelSize: 11
    }

    Repeater {
        model: bt.devices
        delegate: Rectangle {
            required property var modelData
            width: bt.width
            height: 36
            radius: 11
            color: devHov.containsMouse ? "#16ffffff" : "transparent"

            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: parent.width - 120
                text: modelData.name
                color: modelData.connected ? "white" : Theme.subtle
                elide: Text.ElideRight
                font.family: Theme.faceHeader
                font.pixelSize: 13
            }
            Text {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: modelData.connected ? "connected" : (modelData.paired ? "connect" : "pair")
                color: modelData.connected ? Theme.accent : Theme.spot
                font.family: Theme.faceData
                font.pixelSize: 11
            }
            MouseArea {
                id: devHov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bt.act(modelData)
            }
        }
    }
}
