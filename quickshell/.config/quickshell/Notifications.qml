//  nightcity — orb + capsule notifications
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Shapes

Scope {
    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        onNotification: n => {
            n.tracked = true;
            NcState.unread++;
            NcState.play(n.urgency === NotificationUrgency.Critical ? "alert" : "notify");
            NcState.remember({
                app: n.appName,
                summary: n.summary,
                body: n.body,
                critical: n.urgency === NotificationUrgency.Critical,
                time: Qt.formatDateTime(new Date(), "HH:mm")
            });
        }
    }

    PanelWindow {
        id: win
        WlrLayershell.namespace: "nightcity-notifications"
        anchors { top: true; right: true }
        margins { top: 72; right: 16 }
        implicitWidth: 430
        implicitHeight: Math.max(1, stack.height)
        exclusiveZone: 0
        color: "transparent"
        visible: server.trackedNotifications.values.length > 0
        mask: Region { item: stack }      // clicks pass through empty space

        Column {
            id: stack
            anchors { right: parent.right; top: parent.top }
            spacing: 12

            Repeater {
                model: server.trackedNotifications

                delegate: Item {
                    id: toast
                    required property var modelData
                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    readonly property color kc: critical ? Theme.alertFill
                                              : modelData.urgency === NotificationUrgency.Low ? Theme.accent2
                                              : Theme.accent
                    property real life: 1.0

                    width: stack.width
                    height: 62
                    anchors.right: parent.right

                    // ---------- capsule ----------
                    Rectangle {
                        id: capsule
                        anchors { right: orb.horizontalCenter; verticalCenter: parent.verticalCenter }
                        width: Math.min(360, textCol.implicitWidth + 62)
                        height: 54
                        radius: 27
                        color: toast.critical ? Qt.rgba(Theme.alertFill.r, Theme.alertFill.g, Theme.alertFill.b, 0.20)
                                              : Theme.glassTint
                        border.width: 1
                        border.color: Theme.glassBorder

                        Rectangle {   // accent bar on the left edge
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            width: 3; height: 26; radius: 2
                            color: toast.kc
                        }

                        Column {
                            id: textCol
                            anchors { left: parent.left; leftMargin: 26; right: parent.right; rightMargin: 34; verticalCenter: parent.verticalCenter }
                            spacing: 1
                            Text {
                                width: parent.width
                                text: toast.modelData.summary
                                color: "white"
                                elide: Text.ElideRight
                                font.family: Theme.faceHeader
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width
                                text: toast.modelData.body
                                visible: text !== ""
                                color: Theme.subtle
                                elide: Text.ElideRight
                                font.family: Theme.faceData
                                font.pixelSize: 11
                            }
                        }
                    }

                    // ---------- orb ----------
                    Rectangle {
                        id: orb
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 54; height: 54; radius: 27
                        color: Theme.glassTint
                        border.width: 1
                        border.color: Theme.glassBorder

                        Text {
                            anchors.centerIn: parent
                            text: toast.modelData.appName.length > 0 ? toast.modelData.appName.charAt(0).toUpperCase() : "!"
                            color: toast.kc
                            font.family: Theme.faceDisplay
                            font.pixelSize: 16
                        }

                        // countdown ring
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: toast.kc
                                strokeWidth: 2.5
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 27; centerY: 27; radiusX: 25; radiusY: 25
                                    startAngle: -90
                                    sweepAngle: 360 * toast.life
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toast.modelData.tracked = false
                    }

                    // ---------- motion ----------
                    Component.onCompleted: appear.start()
                    ParallelAnimation {
                        id: appear
                        NumberAnimation { target: orb;     property: "scale"; from: 0.2; to: 1; duration: 520; easing.type: Easing.OutBack }
                        NumberAnimation { target: capsule; property: "scale"; from: 0.7; to: 1; duration: 420; easing.type: Easing.OutBack }
                        NumberAnimation { target: toast;   property: "opacity"; from: 0; to: 1; duration: 260 }
                        NumberAnimation { target: toast;   property: "x"; from: 60; to: 0; duration: 520; easing.type: Easing.OutCubic }
                    }

                    // lifetime: 8s for critical, 5s otherwise
                    NumberAnimation on life {
                        from: 1; to: 0
                        duration: toast.critical ? 8000 : 5000
                        running: true
                        onFinished: toast.modelData.tracked = false
                    }

                    // critical shake
                    SequentialAnimation on anchors.rightMargin {
                        running: toast.critical
                        loops: 2
                        NumberAnimation { to: 8; duration: 60 }
                        NumberAnimation { to: -6; duration: 60 }
                        NumberAnimation { to: 0; duration: 90 }
                        PauseAnimation { duration: 900 }
                    }
                }
            }
        }
    }
}
