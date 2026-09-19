//  nightcity — connections panel v2: network + sound mixer
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: NcState.netOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; right: true }
    margins { top: 72; right: 16 }
    implicitWidth: 420
    implicitHeight: Math.min(660, Screen.height - 110)
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.netOpen
    mask: Region { item: card }

    property int tab: 0                       // 0 = network, 1 = sound
    property var networks: []
    property string busy: ""
    property string askSsid: ""               // ssid waiting for a password
    property real down: 0
    property real up: 0
    property var downHist: []

    // ---------- audio ----------
    PwObjectTracker { objects: Pipewire.nodes.values }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio && !n.isSink && !(n.properties && n.properties["stream.monitor"] === true) && (n.properties ? n.properties["application.name"] : "") !== "cava")

    // ---------- commands ----------
    Process { id: runner }
    function run(cmd) { runner.command = ["sh", "-c", cmd]; runner.running = true }

    Process {
        id: wifiScan
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [], seen = [];
                for (const line of this.text.trim().split("\n")) {
                    if (line === "") continue;
                    const f = line.split(":");
                    if (!f[1] || seen.includes(f[1])) continue;
                    seen.push(f[1]);
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
    // bytes in/out for every interface except loopback
    property real lastRx: 0
    property real lastTx: 0
    Process {
        id: netSpeed
        command: ["awk", "NR>2 && $1 !~ /^lo:/ { gsub(/:/,\" \"); rx += $2; tx += $10 } END { print rx, tx }", "/proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(/\s+/);
                const rx = parseFloat(p[0]), tx = parseFloat(p[1]);
                if (root.lastRx > 0) {
                    root.down = Math.max(0, (rx - root.lastRx) / 1048576 / 2);   // MB/s over a 2s window
                    root.up = Math.max(0, (tx - root.lastTx) / 1048576 / 2);
                    const h = root.downHist.slice();
                    h.push(root.down);
                    if (h.length > 40) h.shift();
                    root.downHist = h;
                }
                root.lastRx = rx; root.lastTx = tx;
            }
        }
    }

    function refresh() { wifiScan.running = true; statePoll.running = true }
    onVisibleChanged: if (visible) { refresh(); askSsid = "" }
    Component.onCompleted: refresh()
    Timer { interval: 10000; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: netSpeed.running = true }
    Timer { id: refreshSoon; interval: 1500; onTriggered: root.refresh() }
    Timer { id: connectDone; interval: 7000; onTriggered: { root.busy = ""; root.refresh() } }

    function appName(node) {
        const p = node.properties || {};
        return p["application.name"] || node.description || node.name || "audio";
    }

    // ================= UI =================
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 22
        color: Theme.glassTint
        border.width: 1
        border.color: Theme.glassBorder
        scale: NcState.netOpen ? 1 : 0.96
        transformOrigin: Item.TopRight
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.35 } }

        Column {
            anchors { fill: parent; margins: 18 }
            spacing: 14

            // ---------- tabs ----------
            Rectangle {
                width: parent.width
                height: 40
                radius: 13
                color: "#28000000"

                Rectangle {
                    width: parent.width / 2 - 4
                    height: 32
                    y: 4
                    x: root.tab === 0 ? 4 : parent.width / 2
                    radius: 10
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.accent }
                        GradientStop { position: 1; color: Theme.accent3 }
                    }
                    Behavior on x { SpringAnimation { spring: 4; damping: 0.3 } }
                }
                Row {
                    anchors.fill: parent
                    Repeater {
                        model: ["Network", "Sound"]
                        delegate: Item {
                            required property int index
                            required property string modelData
                            width: card.width / 2 - 18
                            height: 40
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: root.tab === index ? "#07080f" : Theme.subtle
                                font.family: Theme.faceHeader
                                font.pixelSize: 13
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = index }
                        }
                    }
                }
            }

            // ================= NETWORK TAB =================
            Column {
                width: parent.width
                spacing: 12
                visible: root.tab === 0

                Row {
                    spacing: 10
                    Repeater {
                        model: [
                            { label: "Wi-Fi",     on: NcState.wifiEnabled, cmd: NcState.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on" },
                            { label: "Bluetooth", on: NcState.btPowered,   cmd: NcState.btPowered ? "bluetoothctl power off" : "bluetoothctl power on" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 182; height: 56; radius: 16
                            color: modelData.on ? Theme.accent : "#20ffffff"
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
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.run(modelData.cmd); refreshSoon.start() } }
                        }
                    }
                }

                // ---------- live speed ----------
                Rectangle {
                    width: parent.width
                    height: 76
                    radius: 16
                    color: "#12ffffff"

                    Canvas {
                        id: spark
                        anchors { fill: parent; margins: 8 }
                        opacity: 0.55
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const h = root.downHist;
                            if (h.length < 2) return;
                            const peak = Math.max(0.25, Math.max.apply(null, h));
                            ctx.beginPath();
                            for (let i = 0; i < h.length; i++) {
                                const x = i / (h.length - 1) * width;
                                const y = height - (h[i] / peak) * height * 0.8;
                                i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                            }
                            ctx.strokeStyle = Theme.accent;
                            ctx.lineWidth = 1.5;
                            ctx.stroke();
                            ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath();
                            ctx.fillStyle = Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18);
                            ctx.fill();
                        }
                    }
                    Connections { target: root; function onDownChanged() { spark.requestPaint() } }

                    Row {
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        spacing: 22
                        Column {
                            Text { text: "DOWN"; color: Theme.spot; font.family: Theme.faceHeader; font.pixelSize: 10; font.letterSpacing: 1.5 }
                            Text {
                                text: root.down.toFixed(2) + " MB/s"
                                color: Theme.accent
                                font.family: Theme.faceData
                                font.pixelSize: 15
                            }
                        }
                        Column {
                            Text { text: "UP"; color: Theme.spot; font.family: Theme.faceHeader; font.pixelSize: 10; font.letterSpacing: 1.5 }
                            Text {
                                text: root.up.toFixed(2) + " MB/s"
                                color: Theme.accent2
                                font.family: Theme.faceData
                                font.pixelSize: 15
                            }
                        }
                    }
                }

                Text { text: "NETWORKS"; color: Theme.spot; font.family: Theme.faceHeader; font.pixelSize: 11; font.letterSpacing: 1.5 }

                ListView {
                    width: parent.width
                    height: 250
                    clip: true
                    spacing: 3
                    model: root.networks

                    delegate: Item {
                        required property var modelData
                        width: ListView.view.width
                        height: root.askSsid === modelData.ssid ? 88 : 40
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: hov.containsMouse || root.askSsid === modelData.ssid ? "#16ffffff" : "transparent"
                        }

                        Row {
                            anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 12 }
                            spacing: 10
                            Text {
                                text: String.fromCodePoint(0xF05A9)
                                color: modelData.active ? Theme.accent : modelData.signal > 55 ? Theme.body : Theme.muted
                                font.family: Theme.faceData
                                font.pixelSize: 14
                            }
                            Text {
                                text: modelData.ssid
                                color: modelData.active ? "white" : Theme.subtle
                                font.family: Theme.faceHeader
                                font.pixelSize: 13
                            }
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 13 }
                            text: root.busy === modelData.ssid ? "connecting" : modelData.active ? "connected" : modelData.signal + "%"
                            color: modelData.active ? Theme.accent : Theme.spot
                            font.family: Theme.faceData
                            font.pixelSize: 11
                        }

                        // password row
                        Rectangle {
                            visible: root.askSsid === modelData.ssid
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; bottomMargin: 10 }
                            height: 34
                            radius: 10
                            color: "#30000000"
                            border.width: 1
                            border.color: Theme.accent

                            TextInput {
                                id: pw
                                anchors { fill: parent; leftMargin: 12; rightMargin: 70 }
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: "white"
                                font.family: Theme.faceData
                                font.pixelSize: 12
                                focus: root.askSsid === modelData.ssid
                                Text {
                                    anchors.fill: parent
                                    visible: pw.text === ""
                                    text: "password"
                                    color: Theme.spot
                                    font: pw.font
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Keys.onEscapePressed: root.askSsid = ""
                                onAccepted: join()
                                function join() {
                                    if (pw.text === "") return;
                                    root.busy = modelData.ssid;
                                    root.run("nmcli device wifi connect " + JSON.stringify(modelData.ssid) + " password " + JSON.stringify(pw.text));
                                    root.askSsid = "";
                                    pw.text = "";
                                    connectDone.start();
                                }
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                text: "join"
                                color: Theme.accent
                                font.family: Theme.faceData
                                font.pixelSize: 12
                                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: pw.join() }
                            }
                        }

                        MouseArea {
                            id: hov
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            height: 40
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.active) return;
                                if (modelData.secure) {
                                    root.askSsid = root.askSsid === modelData.ssid ? "" : modelData.ssid;
                                } else {
                                    root.busy = modelData.ssid;
                                    root.run("nmcli device wifi connect " + JSON.stringify(modelData.ssid));
                                    connectDone.start();
                                }
                            }
                        }
                    }
                }
            }

            // ================= SOUND TAB =================
            Column {
                width: parent.width
                spacing: 12
                visible: root.tab === 1

                // master volume with moving level bars
                Rectangle {
                    width: parent.width
                    height: 108
                    radius: 18
                    color: "#12ffffff"

                    Row {
                        anchors { left: parent.left; leftMargin: 16; top: parent.top; topMargin: 14 }
                        spacing: 10
                        Text {
                            text: String.fromCodePoint(root.sink && root.sink.audio && root.sink.audio.muted ? 0xF0581 : 0xF057E)
                            color: Theme.accent
                            font.family: Theme.faceData
                            font.pixelSize: 18
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                            }
                        }
                        Text {
                            text: root.sink ? root.sink.description : "no output"
                            color: "white"
                            font.family: Theme.faceHeader
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            width: 240
                        }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 16 }
                        text: root.sink && root.sink.audio ? Math.round(root.sink.audio.volume * 100) + "%" : "--"
                        color: Theme.accent
                        font.family: Theme.faceDisplay
                        font.pixelSize: 15
                    }

                    // animated bars: tall when loud, still when muted or silent
                    Row {
                        anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16; top: parent.top; topMargin: 48 }
                        height: 26
                        spacing: 3
                        Repeater {
                            model: 40
                            delegate: Rectangle {
                                required property int index
                                width: (card.width - 68) / 40 - 3
                                radius: 2
                                anchors.verticalCenter: parent.verticalCenter
                                readonly property real vol: root.sink && root.sink.audio && !root.sink.audio.muted ? root.sink.audio.volume : 0
                                height: 3 + vol * 23 * (0.35 + 0.65 * Math.abs(Math.sin(index * 0.5 + pulse.phase)))
                                color: index / 40 < vol ? Theme.accent : "#22ffffff"
                                Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.InOutSine } }
                            }
                        }
                    }
                    QtObject { id: pulse; property real phase: 0 }
                    NumberAnimation {
                        target: pulse; property: "phase"
                        from: 0; to: Math.PI * 2
                        duration: 2600
                        loops: Animation.Infinite
                        running: root.visible && root.tab === 1
                    }

                    // drag anywhere on the bar row to set volume
                    MouseArea {
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 44 }
                        height: 34
                        cursorShape: Qt.PointingHandCursor
                        function set(x) {
                            const v = Math.max(0, Math.min(1, (x - 16) / (card.width - 68)));
                            root.run("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ " + Math.round(v * 100) + "%");
                        }
                        onPressed: mouse => set(mouse.x)
                        onPositionChanged: mouse => { if (pressed) set(mouse.x) }
                    }
                }

                // ---------- output devices ----------
                Text { text: "OUTPUT"; color: Theme.spot; font.family: Theme.faceHeader; font.pixelSize: 11; font.letterSpacing: 1.5 }

                Column {
                    width: parent.width
                    spacing: 3
                    Repeater {
                        model: root.sinks
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 38
                            radius: 12
                            readonly property bool current: root.sink && root.sink.id === modelData.id
                            color: current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : (outHov.containsMouse ? "#14ffffff" : "transparent")
                            border.width: 1
                            border.color: current ? Theme.accent : "transparent"

                            Text {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                width: parent.width - 100
                                text: modelData.description
                                color: current ? "white" : Theme.subtle
                                elide: Text.ElideRight
                                font.family: Theme.faceHeader
                                font.pixelSize: 13
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                text: current ? "active" : "switch"
                                color: current ? Theme.accent : Theme.spot
                                font.family: Theme.faceData
                                font.pixelSize: 11
                            }
                            MouseArea {
                                id: outHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.run("wpctl set-default " + modelData.id)
                            }
                        }
                    }
                }

                // ---------- per-app mixer ----------
                Text { text: "APPS"; color: Theme.spot; font.family: Theme.faceHeader; font.pixelSize: 11; font.letterSpacing: 1.5 }

                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        visible: root.streams.length === 0
                        text: "Nothing is playing"
                        color: Theme.spot
                        font.family: Theme.faceData
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: root.streams
                        delegate: Item {
                            required property var modelData
                            width: parent.width
                            height: 46

                            Text {
                                anchors { left: parent.left; top: parent.top }
                                text: root.appName(modelData)
                                color: Theme.subtle
                                font.family: Theme.faceHeader
                                font.pixelSize: 12
                            }
                            Text {
                                anchors { right: parent.right; top: parent.top }
                                text: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : ""
                                color: Theme.spot
                                font.family: Theme.faceData
                                font.pixelSize: 11
                            }
                            Rectangle {
                                id: strack
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 8 }
                                height: 6
                                radius: 3
                                color: "#1affffff"
                                Rectangle {
                                    width: parent.width * (modelData.audio ? modelData.audio.volume : 0)
                                    height: parent.height
                                    radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: Theme.accent }
                                        GradientStop { position: 1; color: Theme.accent2 }
                                    }
                                    Behavior on width { NumberAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    anchors { fill: parent; margins: -8 }
                                    cursorShape: Qt.PointingHandCursor
                                    function set(x) {
                                        if (modelData.audio)
                                            modelData.audio.volume = Math.max(0, Math.min(1, x / strack.width));
                                    }
                                    onPressed: mouse => set(mouse.x)
                                    onPositionChanged: mouse => { if (pressed) set(mouse.x) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

