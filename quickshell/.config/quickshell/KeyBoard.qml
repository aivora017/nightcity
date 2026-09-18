//  nightcity — shortcuts board, generated from hyprland.lua
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: NcState.keysOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.keysOpen
    mask: Region { item: card }

    property var binds: []
    readonly property var groups: {
        const g = [];
        for (const b of binds) if (!g.includes(b.group)) g.push(b.group);
        return g;
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/nightcity/keys.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.binds = JSON.parse(text()) } catch (e) { console.log("keys: bad json") } }
    }
    Process { id: regen; command: ["nc-keys"]; onExited: file.reload() }

    Component.onCompleted: { file.reload(); regen.running = true }
    onVisibleChanged: if (visible) { search.text = ""; search.forceActiveFocus(); regen.running = true }

    function matches(b) {
        const q = search.text.trim().toLowerCase();
        return q === "" || (b.key + " " + b.action + " " + b.group).toLowerCase().includes(q);
    }

    Rectangle {
        anchors.fill: parent
        color: "#aa05060a"
        MouseArea { anchors.fill: parent; onClicked: NcState.keysOpen = false }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 980)
        height: Math.min(parent.height - 120, 620)
        radius: 24
        color: Theme.glassTint
        border.width: 1
        border.color: Theme.glassBorder
        scale: NcState.keysOpen ? 1 : 0.95
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.35 } }

        Column {
            anchors { fill: parent; margins: 22 }
            spacing: 14

            Row {
                width: parent.width
                Text {
                    text: "Shortcuts"
                    color: "white"
                    font.family: Theme.faceHeader
                    font.pixelSize: 18
                    font.weight: Font.Medium
                }
                Item { width: parent.width - 260; height: 1 }
                Text {
                    text: "read from hyprland.lua"
                    color: Theme.spot
                    font.family: Theme.faceData
                    font.pixelSize: 11
                }
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: 14
                color: "#18ffffff"
                border.width: 1
                border.color: search.activeFocus ? Theme.accent : "#14ffffff"
                TextInput {
                    id: search
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: "white"
                    font.family: Theme.faceHeader
                    font.pixelSize: 14
                    focus: true
                    Keys.onEscapePressed: NcState.keysOpen = false
                    Text {
                        anchors.fill: parent
                        visible: search.text === ""
                        text: "Search, for example workspace or volume"
                        color: Theme.spot
                        font: search.font
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Flickable {
                width: parent.width
                height: parent.height - 120
                contentHeight: cols.height
                clip: true

                Column {
                    id: cols
                    width: parent.width
                    spacing: 16

                    Repeater {
                        model: root.groups
                        delegate: Column {
                            required property string modelData
                            width: cols.width
                            spacing: 4
                            visible: rep.count > 0

                            Text {
                                text: modelData
                                color: Theme.accent
                                font.family: Theme.faceHeader
                                font.pixelSize: 12
                                font.letterSpacing: 1.5
                            }

                            Repeater {
                                id: rep
                                model: root.binds.filter(b => b.group === modelData && root.matches(b))
                                delegate: Rectangle {
                                    required property var modelData
                                    width: cols.width
                                    height: 38
                                    radius: 11
                                    color: "#0affffff"

                                    Text {
                                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                        text: modelData.action
                                        color: Theme.subtle
                                        font.family: Theme.faceHeader
                                        font.pixelSize: 13
                                    }
                                    Row {
                                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                        spacing: 5
                                        Repeater {
                                            model: modelData.key.split(" ")
                                            delegate: Rectangle {
                                                required property string modelData
                                                width: cap.width + 16
                                                height: 24
                                                radius: 7
                                                color: "#1cffffff"
                                                border.width: 1
                                                border.color: "#26ffffff"
                                                Text {
                                                    id: cap
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    color: "white"
                                                    font.family: Theme.faceData
                                                    font.pixelSize: 11
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

