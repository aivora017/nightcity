//  nightcity — cold boot sequence, once per login
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-boot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: running ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    visible: running

    property bool running: false
    property var checks: []
    property int shown: 0
    readonly property string flag: Quickshell.env("XDG_RUNTIME_DIR") + "/nightcity-booted"

    // ---------- has this login already booted? ----------
    // /run/user/UID is wiped at logout, so the flag means "this session"
    Process {
        id: flagCheck
        command: ["test", "-f", root.flag]
        running: true
        onExited: code => { if (code !== 0) gather.running = true }
    }

    // ---------- real values ----------
    Process {
        id: gather
        command: ["sh", "-c",
            "echo \"KERNEL|$(uname -r)|ok\"; " +
            "echo \"CORE|$(sed -n 's/^model name[^:]*: //p' /proc/cpuinfo | head -1 | sed 's/(R)//g;s/(TM)//g;s/ CPU//;s/  */ /g')|ok\"; " +
            "echo \"MEMORY|$(awk '/MemTotal/{printf \"%.1fG\", $2/1048576}' /proc/meminfo)|ok\"; " +
            "sb=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | awk '{print $NF}'); " +
            "[ \"$sb\" = 1 ] && echo 'FIRMWARE KEYS|OWNER-ENROLLED|ok' || echo 'FIRMWARE KEYS|NOT ENFORCED|warn'; " +
            "ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && echo 'POWER|BATTERY PRESENT|ok' || echo 'POWER|MAINS ONLY · CELL ABSENT|warn'; " +
            "timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes && echo 'CLOCK|NET SYNCED|ok' || echo 'CLOCK|UNSYNCED|warn'; " +
            "sc=$(sed -n 's/.*\"score\": \\([0-9]*\\).*/\\1/p' $HOME/.cache/nightcity/health.json 2>/dev/null); " +
            "echo \"HEALTH|${sc:---}/100|$([ \"${sc:-0}\" -ge 90 ] && echo ok || echo warn)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.trim().split("\n")) {
                    const f = line.split("|");
                    if (f.length === 3) out.push({ key: f[0], value: f[1].toUpperCase(), status: f[2] });
                }
                root.checks = out;
                root.start();
            }
        }
    }

    function start() {
        running = true;
        shown = 0;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/nc-play", "boot"]);
        Quickshell.execDetached(["touch", flag]);
        seq.start();
        keys.forceActiveFocus();
    }
    function finish() {
        seq.stop();
        lineTimer.stop();
        running = false;
    }

    // ================= VISUALS =================
    Rectangle {                                   // the tube
        id: tube
        anchors.centerIn: parent
        width: parent.width
        height: 0
        color: "#05060a"
    }
    Rectangle {                                   // the power-on beam
        id: beam
        anchors.centerIn: parent
        width: 0
        height: 2
        color: "#e8f4ff"
        opacity: 0
    }

    Column {
        id: post
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.62, 760)
        spacing: 10
        opacity: 0
        transformOrigin: Item.Center

        Row {
            width: parent.width
            Text {
                text: "NIGHTCITY"
                color: "white"
                font.family: Theme.faceDisplay
                font.pixelSize: 26
                font.letterSpacing: 4
            }
            Item { width: parent.width - 420; height: 1 }
            Text {
                text: "FIELD TERMINAL · RE-KEYED BY OWNER"
                color: Theme.spot
                font.family: Theme.faceData
                font.pixelSize: 11
                anchors.bottom: parent.bottom
            }
        }
        Rectangle { width: parent.width; height: 1; color: Theme.hairline }

        Repeater {
            model: root.checks
            delegate: Item {
                required property var modelData
                required property int index
                width: post.width
                height: 24
                opacity: index < root.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                property int typed: 0
                Timer {
                    running: index < root.shown && parent.typed < modelData.value.length
                    interval: 16
                    repeat: true
                    onTriggered: parent.typed++
                }

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: modelData.key
                    color: Theme.muted
                    font.family: Theme.faceHeader
                    font.pixelSize: 13
                    font.letterSpacing: 1.5
                }
                Rectangle {
                    anchors { left: parent.left; leftMargin: 170; right: valueText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    height: 1
                    color: "#18ffffff"
                }
                Text {
                    id: valueText
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: modelData.value.substring(0, parent.typed)
                    color: modelData.status === "ok" ? Theme.accent : Theme.warnText
                    font.family: Theme.faceData
                    font.pixelSize: 13
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.hairline }
        Text {
            id: handoff
            text: "HANDING CONTROL TO OWNER"
            color: "white"
            opacity: 0
            font.family: Theme.faceHeader
            font.pixelSize: 13
            font.letterSpacing: 2
        }
    }

    Timer {                                        // reveal one check at a time
        id: lineTimer
        interval: 230
        repeat: true
        onTriggered: {
            if (root.shown < root.checks.length) root.shown++;
            else stop();
        }
    }

    // ================= TIMELINE =================
    SequentialAnimation {
        id: seq

        // 1. beam draws across the screen
        ParallelAnimation {
            NumberAnimation { target: beam; property: "opacity"; to: 1; duration: 60 }
            NumberAnimation { target: beam; property: "width"; from: 0; to: root.width; duration: 280; easing.type: Easing.OutCubic }
        }
        // 2. tube opens vertically, beam fades
        ParallelAnimation {
            NumberAnimation { target: tube; property: "height"; from: 2; to: root.height; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: beam; property: "opacity"; to: 0; duration: 260 }
        }
        // 3. degauss wobble as the text appears
        ParallelAnimation {
            NumberAnimation { target: post; property: "opacity"; to: 1; duration: 200 }
            SequentialAnimation {
                NumberAnimation { target: post; property: "x"; to: post.x - 8; duration: 70 }
                NumberAnimation { target: post; property: "x"; to: post.x + 6; duration: 70 }
                NumberAnimation { target: post; property: "x"; to: post.x; duration: 90 }
            }
        }
        ScriptAction { script: lineTimer.start() }
        PauseAnimation { duration: 230 * 7 + 400 }
        NumberAnimation { target: handoff; property: "opacity"; to: 1; duration: 200 }
        PauseAnimation { duration: 500 }

        // 4. collapse into a line and lift away
        ParallelAnimation {
            NumberAnimation { target: post; property: "scale"; to: 0.02; duration: 380; easing.type: Easing.InCubic }
            NumberAnimation { target: tube; property: "height"; to: 2; duration: 420; easing.type: Easing.InCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: tube; property: "width"; to: 0; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: post; property: "opacity"; to: 0; duration: 200 }
        }
        ScriptAction { script: root.finish()
 }
    }

    // ---------- skip ----------
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: root.finish()
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.running
        onClicked: root.finish()
    }
}
