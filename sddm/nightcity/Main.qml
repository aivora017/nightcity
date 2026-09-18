import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920; height: 1080
    color: config.background !== "" ? config.background : "#03040a"

    property color acc: config.accent !== "" ? config.accent : "#00d9f0"
    property color acc2: config.accent2 !== "" ? config.accent2 : "#7c6cf0"
    property bool busy: false

    // ---------- character rain ----------
    Canvas {
        id: rain
        anchors.fill: parent
        opacity: 0.32
        property var cols: []
        property string glyphs: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄ0123456789ABCDEF<>/{}#"
        property real speed: 1.0

        Component.onCompleted: {
            const n = Math.ceil(width / 18);
            const c = [];
            for (let i = 0; i < n; i++) c.push({ y: Math.random() * height, v: 0.4 + Math.random() });
            cols = c;
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.fillStyle = "rgba(3,4,10,0.12)";
            ctx.fillRect(0, 0, width, height);
            ctx.font = "18px 'JetBrainsMono Nerd Font', monospace";
            for (let i = 0; i < cols.length; i++) {
                const col = cols[i];
                ctx.fillStyle = "rgba(255,255,255,0.85)";
                ctx.fillText(glyphs.charAt(Math.floor(Math.random() * glyphs.length)), i * 18, col.y);
                ctx.fillStyle = root.acc;
                ctx.fillText(glyphs.charAt(Math.floor(Math.random() * glyphs.length)), i * 18, col.y - 18);
                col.y += 8 * col.v * speed;
                if (col.y > height + Math.random() * 300) { col.y = -Math.random() * 200; col.v = 0.4 + Math.random(); }
            }
        }
    }
    Timer { interval: 60; running: true; repeat: true; onTriggered: rain.requestPaint() }

    // ---------- vignette and corner brackets ----------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#cc03040a" }
            GradientStop { position: 0.5; color: "#5503040a" }
            GradientStop { position: 1.0; color: "#dd03040a" }
        }
    }
    Repeater {
        model: 4
        delegate: Item {
            width: 46; height: 46
            x: index % 2 === 0 ? 26 : root.width - 72
            y: index < 2 ? 26 : root.height - 72
            opacity: 0.7
            Rectangle { width: 46; height: 2; color: root.acc; y: index < 2 ? 0 : 44 }
            Rectangle { width: 2; height: 46; color: root.acc; x: index % 2 === 0 ? 0 : 44 }
        }
    }

    Text {
        anchors { top: parent.top; topMargin: 34; horizontalCenter: parent.horizontalCenter }
        text: "NIGHTCITY  SECURE TERMINAL  ·  " + Qt.formatDateTime(new Date(), "dddd d MMMM").toUpperCase()
        color: "#7d8898"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.letterSpacing: 4
    }

    // ---------- centre ----------
    Column {
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: "white"
            font.family: "Michroma"
            font.pixelSize: 96
            font.letterSpacing: 4
            text: Qt.formatDateTime(new Date(), "HH:mm")
        }
        Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm") }

        Item { width: 1; height: 26 }

        // avatar with rotating rings
        Item {
            width: 130; height: 130
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                id: ring1
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: root.acc
                opacity: 0.85
                RotationAnimation on rotation { from: 0; to: 360; duration: root.busy ? 900 : 16000; loops: Animation.Infinite; running: true }
            }
            Rectangle {
                anchors { fill: parent; margins: 10 }
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: root.acc2
                opacity: 0.6
                RotationAnimation on rotation { from: 360; to: 0; duration: 9000; loops: Animation.Infinite; running: true }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 84; height: 84
                radius: 42
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.acc }
                    GradientStop { position: 1.0; color: root.acc2 }
                }
                Text {
                    anchors.centerIn: parent
                    text: userField.text.length > 0 ? userField.text.charAt(0).toUpperCase() : "?"
                    color: "#07080f"
                    font.family: "Michroma"
                    font.pixelSize: 26
                }
            }
        }

        Item { width: 1; height: 12 }

        Text {
            id: status
            anchors.horizontalCenter: parent.horizontalCenter
            text: "AWAITING IDENTITY"
            color: root.acc
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.letterSpacing: 3
        }

        Item { width: 1; height: 14 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Rectangle {
                width: 180; height: 48; radius: 24
                color: "#18ffffff"
                border.width: 1
                border.color: "#26ffffff"
                TextInput {
                    id: userField
                    anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: "white"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    text: userModel.lastUser
                    KeyNavigation.tab: passField
                    onAccepted: passField.forceActiveFocus()
                }
            }

            Rectangle {
                id: passBox
                width: 300; height: 48; radius: 24
                color: "#18ffffff"
                border.width: 1
                border.color: passField.activeFocus ? root.acc : "#26ffffff"
                TextInput {
                    id: passField
                    anchors { fill: parent; leftMargin: 20; rightMargin: 56 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: "white"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    focus: true
                    onAccepted: root.tryLogin()
                }
                Rectangle {
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    width: 38; height: 38; radius: 19
                    color: root.acc
                    Text { anchors.centerIn: parent; text: "→"; color: "#07080f"; font.pixelSize: 18 }
                    MouseArea { anchors.fill: parent; onClicked: root.tryLogin() }
                }
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: passBox; property: "x"; to: passBox.x - 10; duration: 60 }
                    NumberAnimation { target: passBox; property: "x"; to: passBox.x + 10; duration: 60 }
                    NumberAnimation { target: passBox; property: "x"; to: passBox.x; duration: 60 }
                }
            }
        }

        Item { width: 1; height: 16 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20
            Text {
                text: "SESSION: " + sessionModel.data(sessionModel.index(sessionCombo.index, 0), Qt.DisplayRole)
                color: "#7d8898"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    onClicked: sessionCombo.index = (sessionCombo.index + 1) % sessionModel.rowCount()
                }
            }
            Text {
                text: "REBOOT"
                color: "#7d8898"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                MouseArea { anchors.fill: parent; onClicked: sddm.reboot() }
            }
            Text {
                text: "SHUT DOWN"
                color: "#7d8898"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                MouseArea { anchors.fill: parent; onClicked: sddm.powerOff() }
            }
        }
    }

    QtObject { id: sessionCombo; property int index: sessionModel.lastIndex }

    function tryLogin() {
        if (passField.text.length === 0) { status.text = "ENTER YOUR PASSWORD"; shake.start(); return }
        root.busy = true;
        status.text = "VERIFYING IDENTITY";
        sddm.login(userField.text, passField.text, sessionCombo.index);
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            status.text = "IDENTITY CONFIRMED";
            status.color = "#3ee0a1";
            rain.speed = 6;
        }
        function onLoginFailed() {
            root.busy = false;
            status.text = "ACCESS DENIED";
            status.color = "#ff5470";
            passField.text = "";
            shake.start();
            resetStatus.restart();
        }
    }
    Timer {
        id: resetStatus
        interval: 2200
        onTriggered: { status.text = "AWAITING IDENTITY"; status.color = root.acc }
    }

    Component.onCompleted: passField.forceActiveFocus()
}
