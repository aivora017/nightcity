
//  nightcity — glass bar v0.5
//  Colours and type come from Theme.qml. Right side lives in Tray.qml.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

ShellRoot {

    Notifications { }
    Launcher { }
    NotificationCentre { }
    Doctor { }
    KeyBoard { }
    NcPower { }
    NcOverview { }
    NcBoot { }
    NcWalls { }
    NcVisualizer { }
    NcMedia { }
    NcDesktop { }
    Notes { }
    NetPanel { }
    IpcHandler {
        target: "nc"
        function launcher(): void {
            NcState.launcherMode = "apps";
            NcState.launcherOpen = !NcState.launcherOpen;
        }
        function search(): void {
            NcState.launcherMode = "search";
            NcState.launcherOpen = !NcState.launcherOpen;
        }
        function keys(): void { NcState.keysOpen = !NcState.keysOpen }
        function notes(): void { NcState.notesOpen = !NcState.notesOpen }
        function power(): void { NcState.powerOpen = !NcState.powerOpen }
        function overview(): void { NcState.overviewOpen = !NcState.overviewOpen }
        function walls(): void { NcState.wallsOpen = !NcState.wallsOpen }
        function viz(): void { NcState.vizOpen = !NcState.vizOpen }
        function media(): void { NcState.mediaOpen = !NcState.mediaOpen }
       }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { NcState.play("ws") }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    function goToWorkspace(target) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + target + " })")
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

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0;  color: "#1fffffff" }
                    GradientStop { position: 0.45; color: "#05ffffff" }
                    GradientStop { position: 1.0;  color: "#00ffffff" }
                }
            }

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
                    onClicked: { NcState.launcherMode = "apps"; NcState.launcherOpen = true }
                }
            }

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

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => goToWorkspace(wheel.angleDelta.y < 0 ? '"e+1"' : '"e-1"')
                }

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
                            id: wsSlot
                            required property int index
                            readonly property int wsId: index + 1
                            readonly property bool focused: wsTrack.focusedId === wsId
                            readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)
                            width: wsTrack.slot; height: 28

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: "white"
                                opacity: slotMouse.containsMouse && !wsSlot.focused ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: wsSlot.wsId
                                color: wsSlot.focused ? "#07080f" : (wsSlot.occupied ? Theme.body : Theme.spot)
                                font.family: Theme.faceData
                                font.pixelSize: 13
                                font.bold: wsSlot.focused
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }
                            Rectangle {
                                visible: wsSlot.occupied && !wsSlot.focused
                                width: 4; height: 4; radius: 2
                                color: Theme.accent2
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1
                            }
                            MouseArea {
                                id: slotMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: goToWorkspace(wsSlot.wsId)
                            }
                        }
                    }
                }
            }
        }

        // ================= CENTRE: clock =================
        Row {
            id: centreRow
            anchors.centerIn: parent
            spacing: 10

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Row {
                    spacing: 1
                    Text {
                        text: Qt.formatDateTime(clock.date, "HH")
                        color: "white"
                        font.family: Theme.faceDisplay
                        font.pixelSize: 19
                    }
                    Text {
                        text: ":"
                        color: Theme.accent
                        font.family: Theme.faceDisplay
                        font.pixelSize: 19
                        opacity: clock.date.getSeconds() % 2 === 0 ? 1 : 0.25
                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutSine } }
                    }
                    Text {
                        text: Qt.formatDateTime(clock.date, "mm")
                        color: "white"
                        font.family: Theme.faceDisplay
                        font.pixelSize: 19
                    }
                }

                // 30 segments, one lights every 2 seconds across the minute
                Row {
                    spacing: 1
                    Repeater {
                        model: 30
                        delegate: Rectangle {
                            required property int index
                            width: 3
                            height: 3
                            radius: 1
                            color: index < Math.floor(clock.date.getSeconds() / 2) + 1 ? Theme.accent : "#22ffffff"
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: Qt.formatDateTime(clock.date, "ss")
                    color: Theme.accent
                    font.family: Theme.faceData
                    font.pixelSize: 11
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                    color: Theme.muted
                    font.family: Theme.faceHeader
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
            }
        }

        MouseArea {
            anchors.fill: centreRow
            cursorShape: Qt.PointingHandCursor
            onClicked: NcState.mediaOpen = !NcState.mediaOpen
        }

        // ================= RIGHT =================
        Tray {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        }
    }

    // ================= DATA =================
}
