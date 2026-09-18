//  nightcity — connections panel (nmcli + bluetoothctl + wpctl + brightnessctl)
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { top: true; right: true }
    margins { top: 72; right: 16 }
    implicitWidth: 400
    implicitHeight: 640
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.netOpen
    mask: Region { item: card }

    property var networks: []
    property var btDevices: []
    property string busy: ""
    property int brightness: 80

    PwObjectTracker { objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // ================= COMMANDS =================
    Process { id: runner }
    function run(cmd) { runner.command = ["sh", "-c", cmd]; runner.running = true }

    Process {
        id: wifiScan
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.trim().split("\n")) {
                    if (line === "") continue;
                    const f = line.split(":");
                    if (!f[1]) continue;
                    out.push({ active: f[0] === "*", ssid: f[1], signal: parseInt(f[2]) || 0, secure: (f[3] || "") !== "" });
                }
                root.networks = out;
            }
        }
    }
    Process {
        id: statePoll
        command: ["sh", "-c", "nmcli radio wifi; bluetoothctl show | grep -c 'Powered: yes'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n");
                NcState.wifiEnabled = (l[0] || "").trim() === "enabled";
                NcState.btPowered = (l[1] || "0").trim() !== "0";
            }
        }
    }
    Process {
        id: btScan
        command: ["sh", "-c", "bluetoothctl devices Paired | while read -r _ mac name; do c=$(bluetoothctl info \"$mac\" | grep -c 'Connected: yes'); echo \"$mac|$name|$c\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.trim().split("\n")) {
                    if (line === "") continue;
                    const f = line.split("|");
                    out.push({ mac: f[0], name: f[1], connected: f[2] === "1" });
                }
                root.btDevices = out;
            }
        }
    }
    Process {
        id: briPoll
        command: ["sh", "-c", "echo $((100 * $(brightnessctl g) / $(brightnessctl m)))"]
        stdout: StdioCollector { onStreamFinished: root.brightness = parseInt(this.text.trim()) || 0 }
    }

    function refresh() {
        wifiScan.running = true; statePoll.running = true; btScan.running = true; briPoll.running = true;
    }
    onVisibleChanged: if (visible) refresh()
    Timer { interval: 10000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
    Timer { id: refreshSoon; interval: 1200; onTriggered: root.refresh() }
    Timer { id: connectDone; interval: 6000; onTriggered: { root.busy = ""; root.refresh() } }

    // ================= UI =================
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 22
        color: Theme.glassTint
        border.width: 1
        border.color: Theme.glassBorder
        opacity: NcState.netOpen ? 1 : 0
        scale: NcState.netOpen ? 1 : 0.96
        transformOrigin: Item.TopRight
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.35 } }

        Column {
            anchors { fill: parent; margins: 18 }
            spacing: 12

            Row {
                width: parent.width
                Text {
                    text: "Connections"
                    color: "white"
                    font.family: Theme.faceHeader
                    font.pixelSize: 17
                    font.weight: Font.Medium
                }
                Item { width: parent.width - 180; height: 1 }
                Text {
                    text: "close"
                    color: Theme.spot
                    font.family: Theme.faceData
                    font.pixelSize: 11
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NcState.netOpen = false }
                }
            }

            Row {
                spacing: 10
                Repeater {
                    model: [
                        { label: "Wi-Fi",     on: NcState.wifiEnabled, cmd: NcState.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on" },
                        { label: "Bluetooth", on: NcState.btPowered,   cmd: NcState.btPowered ? "bluetoothctl power off" : "bluetoothctl power on" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 172; height: 58; radius: 16
                        color: modelData.on ? Theme.accent : "#20ffffff"
                        border.width: 1
                        border.color: modelData.on ? "transparent" : "#1affffff"
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Column {
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            Text {
                                text: modelData.label
                                color: modelData.on ? "#07080f" : Theme.subtle
                                font.family: Theme.faceHeader
                                font.pixelSize: 14
                            }
                            Text {
                                text: modelData.on ? "On" : "Off"
                                color: modelData.on ? "#5507080f" : Theme.spot
                                font.family: Theme.faceData
                                font.pixelSize: 11
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.run(modelData.cmd); refreshSoon.start() }
                        }
                    }
                }
            }

            Text { text: "NETWORKS"; color: Theme.spot; font.family: Theme.faceHeader; font.pixelSize: 11; font.letterSpacing: 1.5 }

            ListView {
                width: parent.width
                height: 170
                clip: true
                spacing: 2
                model: root.networks
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 38
                    radius: 11
                    color: hov.containsMouse ? "#14ffffff" : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Text {
                            text: String.fromCodePoint(0xF05A9)
                            color: modelData.active ? Theme.accent
                                 : modelData.signal > 55 ? Theme.body : Theme.muted
                            font.family: Theme.faceData
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.ssid
                            color: modelData.active ? "white" : Theme.subtle
                            font.family: Theme.faceHeader
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: root.busy === modelData.ssid ? "connecting" : modelData.active ? "connected" : modelData.signal + "%"
                        color: modelData.active ? Theme.accent : Theme.spot
                        font.family: Theme.faceData
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: hov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.active) return;
                            root.busy = modelData.ssid;
                            root.run("nmcli device wifi connect '" + modelData.ssid.replace(/'/g, "") + "'");
                            connectDone.start();
                        }
                    }
                }
            }

            Text { text: "BLUETOOTH"; color: Theme.spot; font.family: Theme.faceHeader; font.pixelSize: 11; font.letterSpacing: 1.5 }

            ListView {
                width: parent.width
                height: 76
                clip: true
                spacing: 2
                model: root.btDevices
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 36
                    radius: 11
                    color: btHov.containsMouse ? "#14ffffff" : "transparent"
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: modelData.name
                        color: modelData.connected ? "white" : Theme.subtle
                        font.family: Theme.faceHeader
                        font.pixelSize: 13
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: modelData.connected ? "connected" : "connect"
                        color: modelData.connected ? Theme.accent : Theme.spot
                        font.family: Theme.faceData
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: btHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.run("bluetoothctl " + (modelData.connected ? "disconnect " : "connect ") + modelData.mac);
                            refreshSoon.start();
                        }
                    }
                }
            }
            Text {
                visible: root.btDevices.length === 0
                text: NcState.btPowered ? "No paired devices" : "Bluetooth is off"
                color: Theme.spot
                font.family: Theme.faceData
                font.pixelSize: 11
            }

            Text { text: "SOUND AND SCREEN"; color: Theme.spot; font.family: Theme.faceHeader; font.pixelSize: 11; font.letterSpacing: 1.5 }

            component NcSlider: Item {
                id: sl
                property string label: ""
                property real value: 0
                signal moved(real v)
                width: parent.width
                height: 40

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 86
                    text: sl.label
                    color: Theme.subtle
                    font.family: Theme.faceHeader
                    font.pixelSize: 13
                }
                Rectangle {
                    id: track
                    anchors { left: parent.left; leftMargin: 92; right: parent.right; rightMargin: 46; verticalCenter: parent.verticalCenter }
                    height: 6
                    radius: 3
                    color: "#1affffff"
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, sl.value))
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.accent }
                            GradientStop { position: 1; color: Theme.accent3 }
                        }
                    }
                    Rectangle {
                        x: parent.width * Math.max(0, Math.min(1, sl.value)) - 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16; radius: 8
                        color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => sl.moved(Math.max(0, Math.min(1, mouse.x / track.width)))
                        onPositionChanged: mouse => { if (pressed) sl.moved(Math.max(0, Math.min(1, mouse.x / track.width))) }
                    }
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: Math.round(sl.value * 100) + "%"
                    color: Theme.spot
                    font.family: Theme.faceData
                    font.pixelSize: 11
                }
            }

            NcSlider {
                label: "Volume"
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                onMoved: v => root.run("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ " + Math.round(v * 100) + "%")
            }
            NcSlider {
                label: "Mic"
                value: root.source && root.source.audio ? root.source.audio.volume : 0
                onMoved: v => root.run("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + Math.round(v * 100) + "%")
            }
            NcSlider {
                label: "Brightness"
                value: root.brightness / 100
                onMoved: v => { root.brightness = Math.round(v * 100); root.run("brightnessctl set " + root.brightness + "%") }
            }
        }
    }
}
