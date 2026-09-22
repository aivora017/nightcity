//  nightcity — media panel (MPRIS: Firefox, Chrome, Spotify, mpv...)
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { top: true }
    margins { top: 72 }
    implicitWidth: 460
    implicitHeight: 230
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.mediaOpen
    mask: Region { item: card }

    readonly property var players: Mpris.players.values
    property int chosen: 0
    readonly property var player: players.length > 0 ? players[Math.min(chosen, players.length - 1)] : null

    Timer {
        interval: 500
        running: root.visible && root.player !== null && root.player.isPlaying
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    function fmt(sec) {
        if (!sec || sec < 0) return "0:00";
        const s = Math.floor(sec);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 22
        color: Theme.glassTint
        border.width: 1
        border.color: Theme.glassBorder
        scale: NcState.mediaOpen ? 1 : 0.95
        transformOrigin: Item.Top
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.35 } }

        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: root.player === null
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: String.fromCodePoint(0xF075A)
                color: Theme.spot
                font.family: Theme.faceData
                font.pixelSize: 34
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing is playing"
                color: Theme.spot
                font.family: Theme.faceHeader
                font.pixelSize: 13
            }
        }

        Row {
            anchors { fill: parent; margins: 18 }
            spacing: 18
            visible: root.player !== null

            Item {
                width: 140; height: 140
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    clip: true
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.accent }
                        GradientStop { position: 1; color: Theme.accent2 }
                    }
                    Image {
                        anchors.fill: parent
                        source: root.player ? root.player.trackArtUrl : ""
                        sourceSize.width: 280
                        sourceSize.height: 280
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.player || root.player.trackArtUrl === ""
                        text: String.fromCodePoint(0xF075A)
                        color: "#07080f"
                        font.family: Theme.faceData
                        font.pixelSize: 44
                    }
                }
                Rectangle {
                    anchors { fill: parent; margins: -4 }
                    radius: 22
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    opacity: root.player && root.player.isPlaying ? 0.8 : 0.15
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    SequentialAnimation on scale {
                        running: root.player !== null && root.player.isPlaying && root.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.03; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                    }
                }
            }

            Column {
                width: parent.width - 158
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    width: parent.width
                    text: root.player ? (root.player.identity || "player").toUpperCase() : ""
                    color: Theme.accent
                    font.family: Theme.faceHeader
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.player ? (root.player.trackTitle || "Unknown title") : ""
                    color: "white"
                    font.family: Theme.faceHeader
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.player ? (root.player.trackArtist || "") : ""
                    color: Theme.subtle
                    font.family: Theme.faceData
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Item {
                    width: parent.width
                    height: 22
                    visible: root.player && root.player.length > 0
                    Rectangle {
                        id: bar
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        height: 4
                        radius: 2
                        color: "#1affffff"
                        Rectangle {
                            width: root.player && root.player.length > 0
                                   ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                            height: parent.height
                            radius: 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.accent }
                                GradientStop { position: 1; color: Theme.accent3 }
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.player && root.player.canSeek
                        function seekTo(x) {
                            root.player.position = Math.max(0, Math.min(1, x / bar.width)) * root.player.length;
                        }
                        onPressed: mouse => seekTo(mouse.x)
                        onPositionChanged: mouse => { if (pressed) seekTo(mouse.x) }
                    }
                }
                Row {
                    width: parent.width
                    visible: root.player && root.player.length > 0
                    Text { text: root.fmt(root.player ? root.player.position : 0); color: Theme.spot; font.family: Theme.faceData; font.pixelSize: 10 }
                    Item { width: parent.width - 60; height: 1 }
                    Text { text: root.fmt(root.player ? root.player.length : 0); color: Theme.spot; font.family: Theme.faceData; font.pixelSize: 10 }
                }

                Row {
                    spacing: 14
                    anchors.horizontalCenter: parent.horizontalCenter

                    component MediaBtn: Rectangle {
                        property int glyph: 0
                        property bool big: false
                        property bool active: true
                        signal clicked()
                        width: big ? 50 : 38
                        height: width
                        radius: width / 2
                        color: big ? Theme.accent : (h.containsMouse ? "#22ffffff" : "transparent")
                        opacity: active ? 1 : 0.3
                        scale: h.pressed ? 0.9 : 1
                        Behavior on scale { SpringAnimation { spring: 5; damping: 0.3 } }
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(parent.glyph)
                            color: parent.big ? "#07080f" : "white"
                            font.family: Theme.faceData
                            font.pixelSize: parent.big ? 24 : 18
                        }
                        MouseArea {
                            id: h
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: parent.active
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.clicked()
                        }
                    }

                    MediaBtn {
                        glyph: 0xF04AE
                        active: root.player && root.player.canGoPrevious
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.player.previous()
                    }
                    MediaBtn {
                        big: true
                        glyph: root.player && root.player.isPlaying ? 0xF03E4 : 0xF040A
                        active: root.player && root.player.canTogglePlaying
                        onClicked: root.player.togglePlaying()
                    }
                    MediaBtn {
                        glyph: 0xF04AD
                        active: root.player && root.player.canGoNext
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.player.next()
                    }
                }
            }
        }

        Row {
            anchors { right: parent.right; top: parent.top; margins: 12 }
            spacing: 6
            visible: root.players.length > 1
            Repeater {
                model: root.players
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: 8; height: 8; radius: 4
                    color: index === root.chosen ? Theme.accent : "#40ffffff"
                    MouseArea {
                        anchors { fill: parent; margins: -6 }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.chosen = index
                    }
                }
            }
        }
    }
}
