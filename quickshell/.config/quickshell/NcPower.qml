//  nightcity — power menu
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: NcState.powerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.powerOpen

    property int armed: -1        // index waiting for a confirming second click

    readonly property var items: [
        { label: "Lock",      glyph: 0xF033E, cmd: "loginctl lock-session",  danger: false },
        { label: "Log out",   glyph: 0xF0343, cmd: "hyprctl dispatch 'hl.dsp.exit()'", danger: true },
        { label: "Suspend",   glyph: 0xF04B2, cmd: "systemctl suspend",      danger: false },
        { label: "Restart",   glyph: 0xF0709, cmd: "systemctl reboot",       danger: true },
        { label: "Shut down", glyph: 0xF0425, cmd: "systemctl poweroff",     danger: true }
    ]

    function close() { NcState.powerOpen = false; armed = -1 }
    function trigger(i) {
        const it = items[i];
        if (it.danger && armed !== i) { armed = i; disarm.restart(); return }
        Quickshell.execDetached(["sh", "-c", it.cmd]);
        close();
    }
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = -1 }
    onVisibleChanged: if (visible) { armed = -1; focusGrab.forceActiveFocus() }

    Rectangle {
        anchors.fill: parent
        color: "#cc05060a"
        opacity: NcState.powerOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Item {
        id: focusGrab
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
    }

    Column {
        anchors.centerIn: parent
        spacing: 26

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.armed >= 0 ? "Click again to confirm" : "Power"
            color: root.armed >= 0 ? Theme.warnFill : Theme.spot
            font.family: Theme.faceHeader
            font.pixelSize: 14
            font.letterSpacing: 3
        }

        Row {
            spacing: 18
            Repeater {
                model: root.items
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: 124; height: 124
                    radius: 24
                    color: root.armed === index ? Qt.rgba(Theme.warnFill.r, Theme.warnFill.g, Theme.warnFill.b, 0.22)
                         : hov.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                         : Theme.glassTint
                    border.width: 1
                    border.color: root.armed === index ? Theme.warnFill : (hov.containsMouse ? Theme.accent : Theme.glassBorder)
                    scale: hov.containsMouse ? 1.06 : 1
                    Behavior on scale { SpringAnimation { spring: 4; damping: 0.3 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String.fromCodePoint(modelData.glyph)
                            color: root.armed === index ? Theme.warnFill : (hov.containsMouse ? "white" : Theme.subtle)
                            font.family: Theme.faceData
                            font.pixelSize: 34
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: hov.containsMouse ? "white" : Theme.spot
                            font.family: Theme.faceHeader
                            font.pixelSize: 13
                        }
                    }
                    MouseArea {
                        id: hov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.trigger(index)
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Esc to cancel"
            color: Theme.spot
            font.family: Theme.faceData
            font.pixelSize: 11
        }
    }
}
