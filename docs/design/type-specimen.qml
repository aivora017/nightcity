import Quickshell
import QtQuick

FloatingWindow {
    implicitWidth: 900
    implicitHeight: 560
    color: "#08090a"

    Column {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24

        Repeater {
            model: ["Michroma", "Chakra Petch", "Rajdhani"]

            delegate: Column {
                required property string modelData
                spacing: 6

                Text { text: modelData.toUpperCase(); color: "#6d7780"
                       font.family: "JetBrains Mono"; font.pixelSize: 11; font.letterSpacing: 2 }
                Text { text: "NIGHTCITY // SYSTEM MONITOR"; color: "#e1e4e6"
                       font.family: modelData; font.pixelSize: 20; font.letterSpacing: 3 }
                Text { text: "WS 03   MEMORY PRESSURE: ELEVATED"; color: "#e6a351"
                       font.family: modelData; font.pixelSize: 12; font.letterSpacing: 2 }
                Text { text: "MEM 2.41G / 3.72G   CPU 34%   14:32:07"; color: "#00c0e6"
                       font.family: "JetBrains Mono"; font.pixelSize: 13 }
                Rectangle { width: 836; height: 1; color: "#4c5359" }
            }
        }
    }
}
