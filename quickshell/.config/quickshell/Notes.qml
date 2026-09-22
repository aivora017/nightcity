//  nightcity — scratch notes, saved to disk
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: NcState.notesOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; left: true }
    margins { top: 72; left: 16 }
    implicitWidth: 380
    implicitHeight: 440
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.notesOpen
    mask: Region { item: card }

    readonly property string path: Quickshell.env("HOME") + "/.local/share/nightcity/notes.md"

    FileView {
        id: file
        path: root.path
        onLoaded: if (!edit.activeFocus) edit.text = text()
    }
    Component.onCompleted: file.reload()
    onVisibleChanged: if (visible) { file.reload(); edit.forceActiveFocus() }

    // save without a shell quoting mess: the text is passed as an argument, not inside the command
    function save() {
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; printf '%s' \"$2\" > \"$1\"",
            "sh", root.path, edit.text]);
        saved.restart();
    }
    Timer { id: autosave; interval: 900; onTriggered: root.save() }
    Timer { id: saved; interval: 1500 }

    NcCard {
        id: card
        open: NcState.notesOpen
        anchors.fill: parent

        Column {
            anchors { fill: parent; margins: 18 }
            spacing: 10

            Row {
                width: parent.width
                Text {
                    text: "Notes"
                    color: "white"
                    font.family: Theme.faceHeader
                    font.pixelSize: 17
                    font.weight: Font.Medium
                }
                Item { width: parent.width - 150; height: 1 }
                Text {
                    text: saved.running ? "saved" : ""
                    color: Theme.accent
                    font.family: Theme.faceData
                    font.pixelSize: 11
                }
                Item { width: 12; height: 1 }
                Text {
                    text: "close"
                    color: Theme.spot
                    font.family: Theme.faceData
                    font.pixelSize: 11
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.save(); NcState.notesOpen = false } }
                }
            }

            Rectangle {
                width: parent.width
                height: parent.height - 50
                radius: 14
                color: "#28000000"
                border.width: 1
                border.color: edit.activeFocus ? Theme.accent : "#14ffffff"

                Flickable {
                    anchors { fill: parent; margins: 12 }
                    contentHeight: edit.implicitHeight
                    clip: true
                    TextEdit {
                        id: edit
                        width: parent.width
                        color: "white"
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        font.family: Theme.faceData
                        font.pixelSize: 13
                        onTextChanged: autosave.restart()
                        Keys.onEscapePressed: { root.save(); NcState.notesOpen = false }
                    }
                }
            }
        }
    }
}

