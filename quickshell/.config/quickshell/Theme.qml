pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // Palette: verified with scripts/apca.py. Never edit by eye.
    readonly property color bg:        "#08090a"
    readonly property color body:      "#e1e4e6"
    readonly property color subtle:    "#c7ccd0"
    readonly property color muted:     "#8d969e"
    readonly property color spot:      "#6d7780"
    readonly property color hairline:  "#4c5359"
    readonly property color alertFill: "#e02b28"
    readonly property color alertText: "#f09a98"
    readonly property color dataFill:  "#00b4d8"
    readonly property color dataText:  "#00c0e6"
    readonly property color warnFill:  "#d9861f"
    readonly property color warnText:  "#e6a351"

    // Typefaces
    readonly property string faceDisplay: "Michroma"
    readonly property string faceHeader:  "Chakra Petch"
    readonly property string faceData:    "JetBrainsMono Nerd Font"

    // Scale
    readonly property int sizeDisplay: 48
    readonly property int sizeHeader:  14
    readonly property int sizeLabel:   12
    readonly property int sizeData:    13
    readonly property int sizeMicro:   10
}
