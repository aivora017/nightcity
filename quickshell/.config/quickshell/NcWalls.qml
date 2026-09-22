//  nightcity — wallpaper picker
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt.labs.folderlistmodel
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: NcState.wallsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.wallsOpen

    property string current: ""
    FileView {
        id: curFile
        path: Quickshell.env("HOME") + "/.cache/nightcity/wallpaper"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.current = text().trim()
    }
    Component.onCompleted: curFile.reload()

    FolderListModel {
        id: folder
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/walls"
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    function pick(path) {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/nc-wall", path]);
    }
    function close() { NcState.wallsOpen = false }

    Rectangle {
        anchors.fill: parent
        color: "#b005060a"
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 1040)
        height: Math.min(parent.height - 120, 580)
        radius: 24
        color: Theme.glassTint
        border.width: 1
        border.color: Theme.glassBorder
        scale: NcState.wallsOpen ? 1 : 0.95
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.35 } }

        Item {
            anchors.fill: parent
            focus: NcState.wallsOpen
            Keys.onEscapePressed: root.close()
        }

        Column {
            anchors { fill: parent; margins: 22 }
            spacing: 16

            Row {
                width: parent.width
                Text {
                    text: "Wallpapers"
                    color: "white"
                    font.family: Theme.faceHeader
                    font.pixelSize: 18
                    font.weight: Font.Medium
                }
                Item { width: parent.width - 330; height: 1 }
                Text {
                    text: "shuffle"
                    color: Theme.accent
                    font.family: Theme.faceData
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/nc-wall-next", "--random"])
                    }
                }
                Item { width: 18; height: 1 }
                Text {
                    text: folder.count + " in ~/Pictures/walls"
                    color: Theme.spot
                    font.family: Theme.faceData
                    font.pixelSize: 11
                }
            }

            GridView {
                id: grid
                width: parent.width
                height: parent.height - 50
                cellWidth: width / 4
                cellHeight: cellWidth * 0.62
                clip: true
                model: folder

                delegate: Item {
                    required property string filePath
                    required property string fileName
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool isCurrent: filePath === root.current

                    Rectangle {
                        id: frame
                        anchors { fill: parent; margins: 7 }
                        radius: 14
                        color: "#20ffffff"
                        border.width: isCurrent ? 3 : (hov.containsMouse ? 2 : 0)
                        border.color: isCurrent ? Theme.accent : Theme.glassHighlight
                        clip: true
                        scale: hov.containsMouse ? 1.03 : 1
                        Behavior on scale { SpringAnimation { spring: 4; damping: 0.3 } }

                        Image {
                            anchors { fill: parent; margins: frame.border.width }
                            source: "file://" + filePath
                            sourceSize.width: 320          // decode small: keeps memory low
                            sourceSize.height: 200
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 24
                            color: "#99000000"
                            visible: hov.containsMouse || isCurrent
                            Text {
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                width: parent.width - 20
                                text: isCurrent ? "current" : fileName
                                color: isCurrent ? Theme.accent : "white"
                                elide: Text.ElideRight
                                font.family: Theme.faceData
                                font.pixelSize: 10
                            }
                        }
                    }
                    MouseArea {
                        id: hov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(filePath)
                    }
                }
            }
        }
    }
}
