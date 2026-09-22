//  nightcity — shared panel body: glass, brackets, hologram materialize
import QtQuick

Item {
    id: card
    property bool open: false
    property int radius: 22
    default property alias content: inner.data

    // the body is revealed from a thin line at the centre outward
    Item {
        id: clipper
        property real reveal: 1
        anchors.centerIn: parent
        width: parent.width
        height: Math.max(2, parent.height * reveal)
        clip: true

        Rectangle {
            width: card.width
            height: card.height
            y: -(card.height - clipper.height) / 2
            radius: card.radius
            color: Theme.glassTint
            border.width: 1
            border.color: Theme.glassBorder

            // faint top-lit sheen
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#14ffffff" }
                    GradientStop { position: 0.4; color: "#00ffffff" }
                }
            }

            Item { id: inner; anchors.fill: parent }

            // corner brackets, the same language as the bar
            Repeater {
                model: 4
                delegate: Item {
                    required property int index
                    width: 12; height: 12
                    x: index % 2 === 0 ? 8 : card.width - 20
                    y: index < 2 ? 8 : card.height - 20
                    opacity: 0.75
                    Rectangle { width: 12; height: 2; color: Theme.accent; y: index < 2 ? 0 : 10 }
                    Rectangle { width: 2; height: 12; color: Theme.accent; x: index % 2 === 0 ? 0 : 10 }
                }
            }
        }
    }

    // accent flash and scan line, only during the reveal
    Rectangle {
        id: flash
        anchors.fill: clipper
        radius: card.radius
        color: Theme.accent
        opacity: 0
    }
    Rectangle {
        id: scan
        x: 12
        width: card.width - 24
        height: 2
        radius: 1
        color: Theme.accent
        opacity: 0
    }

    onOpenChanged: if (open) materialize.restart()
    Component.onCompleted: if (open) materialize.restart()

    SequentialAnimation {
        id: materialize
        ScriptAction { script: { clipper.reveal = 0.01; card.opacity = 1 } }
        ParallelAnimation {
            NumberAnimation { target: clipper; property: "reveal"; from: 0.01; to: 1; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: flash; property: "opacity"; from: 0.30; to: 0; duration: 460; easing.type: Easing.OutQuad }
            SequentialAnimation {
                PropertyAction { target: scan; property: "opacity"; value: 0.85 }
                NumberAnimation { target: scan; property: "y"; from: 0; to: card.height; duration: 440; easing.type: Easing.InOutQuad }
                PropertyAction { target: scan; property: "opacity"; value: 0 }
            }
        }
        NumberAnimation { target: card; property: "opacity"; to: 0.55; duration: 45 }
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 70 }
    }
}
