//  nightcity — living desktop: shader overlay + HUD, only while the workspace is empty
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: root
    WlrLayershell.namespace: "ncdesk"          // deliberately NOT nightcity-*, so it isn't blurred
    WlrLayershell.layer: WlrLayer.Bottom       // above the wallpaper, below every window
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {}                            // never catches clicks

    property int windowCount: 1
    readonly property bool active: windowCount === 0

    // ---------- is the current workspace empty? ----------
    Process {
        id: wsQuery
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.windowCount = JSON.parse(this.text).windows } catch (e) { root.windowCount = 1 }
            }
        }
    }
    Timer { id: debounce; interval: 150; onTriggered: wsQuery.running = true }
    Connections {
        target: Hyprland
        function onRawEvent(event) { debounce.restart() }
    }
    Component.onCompleted: wsQuery.running = true

    // ---------- live system numbers, polled only while visible ----------
    property real cpu: 0
    property real mem: 0
    property real temp: 0
    property var lastCpu: null
    Process {
        id: stats
        command: ["sh", "-c",
            "head -1 /proc/stat; " +
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print (t-a)/t}' /proc/meminfo; " +
            "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n");
                const f = l[0].split(/\s+/).slice(1).map(Number);
                const idle = f[3] + f[4], total = f.reduce((x, y) => x + y, 0);
                if (root.lastCpu) {
                    const dt = total - root.lastCpu.total, di = idle - root.lastCpu.idle;
                    root.cpu = dt > 0 ? 1 - di / dt : 0;
                }
                root.lastCpu = { total: total, idle: idle };
                root.mem = parseFloat(l[1]) || 0;
                root.temp = (parseInt(l[2]) || 0) / 1000;
            }
        }
    }
    Timer { interval: 2000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: stats.running = true }

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    // ================= SHADER =================
    ShaderEffect {
        id: fx
        anchors.fill: parent
        opacity: root.active ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

        property real time: 0
        property vector2d res: Qt.vector2d(width, height)
        property color accent: Theme.accent
        property color accent2: Theme.accent2
        fragmentShader: Qt.resolvedUrl("shaders/desk.frag.qsb")

        NumberAnimation on time {
            from: 0; to: 100000
            duration: 100000000
            loops: Animation.Infinite
            running: root.active
        }
    }

    // ================= HUD =================
    Column {
        id: hud
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.16 }
        spacing: 18
        opacity: root.active ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 500 } }
        transform: Translate {
            y: root.active ? 0 : 24
            Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: "white"
            font.family: Theme.faceDisplay
            font.pixelSize: 92
            font.letterSpacing: 4
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd  ·  d MMMM").toUpperCase()
            color: Theme.subtle
            font.family: Theme.faceHeader
            font.pixelSize: 14
            font.letterSpacing: 4
        }

        Item { width: 1; height: 10 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 42

            Repeater {
                model: [
                    { label: "CPU",  value: root.cpu,                    text: Math.round(root.cpu * 100) + "%" },
                    { label: "MEM",  value: root.mem,                    text: Math.round(root.mem * 100) + "%" },
                    { label: "TEMP", value: Math.min(1, root.temp / 100), text: Math.round(root.temp) + "°" }
                ]
                delegate: Item {
                    required property var modelData
                    width: 92; height: 112
                    readonly property color ringColor: modelData.value > 0.85 ? Theme.alertFill
                                                     : modelData.value > 0.65 ? Theme.warnFill : Theme.accent
                    Shape {
                        width: 92; height: 92
                        ShapePath {
                            strokeColor: "#22ffffff"; strokeWidth: 5; fillColor: "transparent"
                            PathAngleArc { centerX: 46; centerY: 46; radiusX: 40; radiusY: 40; startAngle: 0; sweepAngle: 360 }
                        }
                        ShapePath {
                            strokeColor: ringColor; strokeWidth: 5; fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 46; centerY: 46; radiusX: 40; radiusY: 40
                                startAngle: -90
                                sweepAngle: 360 * Math.max(0.01, modelData.value)
                                Behavior on sweepAngle { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    Text {
                        x: 46 - width / 2; y: 46 - height / 2
                        text: modelData.text
                        color: "white"
                        font.family: Theme.faceData
                        font.pixelSize: 16
                    }
                    Text {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                        text: modelData.label
                        color: Theme.spot
                        font.family: Theme.faceHeader
                        font.pixelSize: 11
                        font.letterSpacing: 2
                    }
                }
            }
        }

        Item { width: 1; height: 6 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            visible: root.player !== null && root.player.trackTitle !== ""
            Text {
                text: String.fromCodePoint(root.player && root.player.isPlaying ? 0xF040A : 0xF03E4)
                color: Theme.accent
                font.family: Theme.faceData
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.player ? root.player.trackTitle + (root.player.trackArtist ? "  ·  " + root.player.trackArtist : "") : ""
                color: Theme.subtle
                font.family: Theme.faceHeader
                font.pixelSize: 13
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 520)
            }
        }
    }
}
