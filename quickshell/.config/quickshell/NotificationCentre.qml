//  nightcity — notification history
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { top: true; right: true }
    margins { top: 72; right: 16 }
    implicitWidth: 400
    implicitHeight: 520
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.centreOpen
    mask: Region { item: card }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 22
        color: Theme.glassTint
        border.width: 1
        border.color: Theme.glassBorder
        opacity: NcState.centreOpen ? 1 : 0
        scale: NcState.centreOpen ? 1 : 0.96
        transformOrigin: Item.TopRight
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.35 } }

        Column {
            anchors { fill: parent; margins: 18 }
            spacing: 12

            Row {
                width: parent.width
                Text {
                    text: "Notifications"
                    color: "white"
                    font.family: Theme.faceHeader
                    font.pixelSize: 17
                    font.weight: Font.Medium
                }
                Item { width: parent.width - 220; height: 1 }
                Text {
                    text: NcState.history.length > 0 ? "clear all" : ""
                    color: Theme.accent
                    font.family: Theme.faceData
                    font.pixelSize: 11
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NcState.history = [] }
                }
                Item { width: 14; height: 1 }
                Text {
                    text: "close"
                    color: Theme.spot
                    font.family: Theme.faceData
                    font.pixelSize: 11
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NcState.centreOpen = false }
                }
            }

            Text {
                visible: NcState.history.length === 0
                text: "Nothing yet. Notifications from your apps land here."
                color: Theme.spot
                width: parent.width
                wrapMode: Text.WordWrap
                font.family: Theme.faceData
                font.pixelSize: 12
            }

            ListView {
                width: parent.width
                height: parent.height - 60
                clip: true
                spacing: 8
                model: NcState.history

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: col.implicitHeight + 22
                    radius: 14
                    color: "#12ffffff"
                    border.width: 1
                    border.color: modelData.critical ? Qt.rgba(Theme.alertFill.r, Theme.alertFill.g, Theme.alertFill.b, 0.45) : "#14ffffff"

                    Rectangle {
                        anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 14 }
                        width: 3; height: 22; radius: 2
                        color: modelData.critical ? Theme.alertFill : Theme.accent
                    }

                    Column {
                        id: col
                        anchors { left: parent.left; leftMargin: 26; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 3

                        Row {
                            width: parent.width
                            spacing: 8
                            Text {
                                text: modelData.app !== "" ? modelData.app : "system"
                                color: modelData.critical ? Theme.alertText : Theme.accent
                                font.family: Theme.faceHeader
                                font.pixelSize: 11
                                font.letterSpacing: 1
                            }
                            Item { width: parent.width - 120; height: 1 }
                            Text {
                                text: modelData.time
                                color: Theme.spot
                                font.family: Theme.faceData
                                font.pixelSize: 11
                            }
                        }
                        Text {
                            width: parent.width
                            text: modelData.summary
                            color: "white"
                            wrapMode: Text.WordWrap
                            font.family: Theme.faceHeader
                            font.pixelSize: 13
                        }
                        Text {
                            width: parent.width
                            visible: modelData.body !== ""
                            text: modelData.body
                            color: Theme.subtle
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.family: Theme.faceData
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
