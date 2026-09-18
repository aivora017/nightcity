//  nightcity — system health dashboard (reads nc-doctor's JSON)
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.docOpen
    mask: Region { item: card }

    property var report: ({ score: 0, scanned: "never", counts: { ok: 0, info: 0, warn: 0, fail: 0 }, checks: [] })
    property bool scanning: false
    property int revealed: 0            // how many rows are shown, for the scan animation
    property int expanded: -1

    readonly property var areas: {
        const seen = [];
        for (const c of report.checks) if (!seen.includes(c.area)) seen.push(c.area);
        return seen;
    }
    readonly property color scoreColor: report.score >= 90 ? Theme.okColor
                                      : report.score >= 70 ? Theme.warnFill
                                      : Theme.alertFill

    function statusColor(s) {
        return s === "ok"   ? Theme.okColor
             : s === "warn" ? Theme.warnFill
             : s === "fail" ? Theme.alertFill
             : Theme.accent2;
    }
    function statusGlyph(s) {
        return s === "ok"   ? String.fromCodePoint(0xF012C)   // check
             : s === "warn" ? String.fromCodePoint(0xF0026)   // alert
             : s === "fail" ? String.fromCodePoint(0xF0159)   // close
             : String.fromCodePoint(0xF02FC);                 // info
    }

    // ---------- load the report ----------
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/nightcity/health.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.report = JSON.parse(text()) } catch (e) { console.log("doctor: bad json", e) }
            if (!root.scanning) root.revealed = root.report.checks.length;
        }
    }

    // ---------- run the scan ----------
    Process {
        id: scan
        command: ["nc-doctor"]
        onExited: {
            root.scanning = false;
            file.reload();
            reveal.start();
        }
    }
    function runScan() {
        if (scanning) return;
        scanning = true;
        expanded = -1;
        revealed = 0;
        scan.running = true;
    }
    Timer {                                  // rows appear one by one, like a scan in progress
        id: reveal
        interval: 60
        repeat: true
        onTriggered: {
            root.revealed++;
            if (root.revealed >= root.report.checks.length) stop();
        }
    }

    Component.onCompleted: file.reload()
    onVisibleChanged: if (visible && report.checks.length === 0) runScan()

    Rectangle {                              // dim backdrop
        anchors.fill: parent
        color: "#aa05060a"
        opacity: NcState.docOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: NcState.docOpen = false }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 940)
        height: Math.min(parent.height - 120, 620)
        radius: 24
        color: Theme.glassTint
        border.width: 1
        border.color: Theme.glassBorder
        opacity: NcState.docOpen ? 1 : 0
        scale: NcState.docOpen ? 1 : 0.95
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.35 } }

        Row {
            anchors { fill: parent; margins: 22 }
            spacing: 24

            // ================= LEFT: gauge =================
            Column {
                width: 250
                spacing: 14

                Item {
                    width: 220; height: 220
                    anchors.horizontalCenter: parent.horizontalCenter

                    Shape {                         // orbiting dashes, faster while scanning
                        anchors.fill: parent
                        ShapePath {
                            strokeColor: Theme.accent
                            strokeWidth: 1
                            fillColor: "transparent"
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [1, 5]
                            PathAngleArc { centerX: 110; centerY: 110; radiusX: 104; radiusY: 104; startAngle: 0; sweepAngle: 360 }
                        }
                        RotationAnimation on rotation {
                            from: 0; to: 360
                            duration: root.scanning ? 1400 : 22000
                            loops: Animation.Infinite
                            running: true
                        }
                    }
                    Shape {                         // track
                        anchors.fill: parent
                        ShapePath {
                            strokeColor: "#18ffffff"; strokeWidth: 12; fillColor: "transparent"
                            PathAngleArc { centerX: 110; centerY: 110; radiusX: 86; radiusY: 86; startAngle: 0; sweepAngle: 360 }
                        }
                    }
                    Shape {                         // score arc
                        anchors.fill: parent
                        ShapePath {
                            strokeColor: root.scoreColor
                            strokeWidth: 12
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 110; centerY: 110; radiusX: 86; radiusY: 86
                                startAngle: -90
                                sweepAngle: 360 * (root.scanning
                                    ? (root.report.checks.length ? root.revealed / root.report.checks.length : 0)
                                    : root.report.score / 100)
                                Behavior on sweepAngle { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.scanning ? "..." : root.report.score
                            color: "white"
                            font.family: Theme.faceDisplay
                            font.pixelSize: 44
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.scanning ? "scanning" : "health score"
                            color: Theme.spot
                            font.family: Theme.faceHeader
                            font.pixelSize: 12
                        }
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.scanning ? "Checking your system"
                        : root.report.counts.fail > 0 ? root.report.counts.fail + (root.report.counts.fail > 1 ? " things need fixing" : " thing needs fixing")
                        : root.report.counts.warn > 0 ? root.report.counts.warn + " warnings to review"
                        : "Everything is healthy"
                    color: "white"
                    font.family: Theme.faceHeader
                    font.pixelSize: 17
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Last scan " + root.report.scanned
                    color: Theme.spot
                    font.family: Theme.faceData
                    font.pixelSize: 11
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Repeater {
                        model: [
                            { n: root.report.counts.ok + root.report.counts.info, l: "healthy", c: Theme.okColor },
                            { n: root.report.counts.warn, l: "warnings", c: Theme.warnFill },
                            { n: root.report.counts.fail, l: "broken",   c: Theme.alertFill }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 76; height: 56; radius: 14
                            color: "#12ffffff"
                            Column {
                                anchors.centerIn: parent
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.n
                                    color: modelData.c
                                    font.family: Theme.faceDisplay
                                    font.pixelSize: 18
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.l
                                    color: Theme.spot
                                    font.family: Theme.faceData
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 46; radius: 15
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.accent }
                        GradientStop { position: 1; color: Theme.accent3 }
                    }
                    opacity: root.scanning ? 0.5 : 1
                    Text {
                        anchors.centerIn: parent
                        text: root.scanning ? "Scanning" : "Run full scan"
                        color: "#07080f"
                        font.family: Theme.faceHeader
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runScan() }
                }
            }

            // ================= RIGHT: report =================
            Item {
                width: parent.width - 274
                height: parent.height

                Text {
                    id: closeBtn
                    anchors { right: parent.right; top: parent.top }
                    text: "close"
                    color: Theme.spot
                    font.family: Theme.faceData
                    font.pixelSize: 11
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NcState.docOpen = false }
                }

                ListView {
                    anchors { fill: parent; topMargin: 22 }
                    clip: true
                    spacing: 6
                    model: root.report.checks

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: visible ? (row.height + (root.expanded === index ? detail.height + 12 : 0)) : 0
                        visible: index < root.revealed
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: hovr.containsMouse || root.expanded === index ? "#14ffffff" : "#0affffff"
                            border.width: 1
                            border.color: modelData.status === "fail" ? Qt.rgba(Theme.alertFill.r, Theme.alertFill.g, Theme.alertFill.b, 0.5) : "#10ffffff"
                        }

                        Row {
                            id: row
                            width: parent.width
                            height: 44
                            spacing: 12

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                leftPadding: 14
                                text: root.statusGlyph(modelData.status)
                                color: root.statusColor(modelData.status)
                                font.family: Theme.faceData
                                font.pixelSize: 16
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: modelData.name
                                    color: "white"
                                    font.family: Theme.faceHeader
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: modelData.area
                                    color: Theme.spot
                                    font.family: Theme.faceData
                                    font.pixelSize: 10
                                }
                            }
                            Item { width: parent.width - 320; height: 1 }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.result
                                color: root.statusColor(modelData.status)
                                font.family: Theme.faceData
                                font.pixelSize: 12
                            }
                        }

                        Column {
                            id: detail
                            visible: root.expanded === index
                            anchors { top: row.bottom; left: parent.left; right: parent.right; leftMargin: 46; rightMargin: 14 }
                            spacing: 8

                            Text {
                                width: parent.width
                                text: modelData.detail
                                color: Theme.subtle
                                wrapMode: Text.WordWrap
                                font.family: Theme.faceData
                                font.pixelSize: 12
                            }
                            Rectangle {
                                visible: modelData.fix !== ""
                                width: parent.width
                                height: 34
                                radius: 10
                                color: "#40000000"
                                border.width: 1
                                border.color: "#16ffffff"
                                Text {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    width: parent.width - 100
                                    text: modelData.fix
                                    color: Theme.accent3
                                    elide: Text.ElideRight
                                    font.family: Theme.faceData
                                    font.pixelSize: 11
                                }
                                Text {
                                    id: copyLabel
                                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: "copy"
                                    color: Theme.accent
                                    font.family: Theme.faceData
                                    font.pixelSize: 11
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(modelData.fix) + " | wl-copy"]);
                                            copyLabel.text = "copied";
                                            copyReset.restart();
                                        }
                                    }
                                    Timer { id: copyReset; interval: 1400; onTriggered: copyLabel.text = "copy" }
                                }
                            }
                        }

                        MouseArea {
                            id: hovr
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            height: 44
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expanded = root.expanded === index ? -1 : index
                        }
                    }
                }
            }
        }
    }
}
