pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---------- adaptive palette, written by nc-wall ----------
    FileView {
        id: paletteFile
        path: Quickshell.env("HOME") + "/.cache/nightcity/palette.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: pal
            // defaults, used only if palette.json is missing
            property int hue: 190
            property string primary: "#4fd8f8"
            property string analogous: "#64a0f7"
            property string split: "#f7a064"
        }
    }

    // accents follow the wallpaper, and fade instead of jumping
    property color accent:  pal.primary
    property color accent2: pal.split
    property color accent3: pal.analogous
    Behavior on accent  { ColorAnimation { duration: 1200; easing.type: Easing.InOutCubic } }
    Behavior on accent2 { ColorAnimation { duration: 1200; easing.type: Easing.InOutCubic } }
    Behavior on accent3 { ColorAnimation { duration: 1200; easing.type: Easing.InOutCubic } }

    // ---------- fixed colours: never adapt ----------
    readonly property color bg:        "#08090a"
    readonly property color body:      "#e1e4e6"
    readonly property color subtle:    "#c7ccd0"
    readonly property color muted:     "#8d969e"
    readonly property color spot:      "#6d7780"
    readonly property color hairline:  "#4c5359"
    readonly property color okColor:   "#3ee0a1"    
    readonly property color alertFill: "#e02b28"
    readonly property color alertText: "#f09a98"
    readonly property color warnFill:  "#d9861f"
    readonly property color warnText:  "#e6a351"

    // old names kept so shell.qml keeps working, now adaptive
    readonly property color dataFill: accent
    readonly property color dataText: accent

    // ---------- glass (Qt colour format: #AARRGGBB) ----------
    readonly property color glassTint:      "#99080a14"   // 60% dark, keeps text readable on bright wallpapers
    readonly property color glassFill:      "#14ffffff"
    readonly property color glassBorder:    "#26ffffff"
    readonly property color glassHighlight: "#47ffffff"

    // ---------- type ----------
    readonly property string faceDisplay: "Michroma"
    readonly property string faceHeader:  "Chakra Petch"
    readonly property string faceData:    "JetBrainsMono Nerd Font"

    readonly property int sizeDisplay: 48
    readonly property int sizeHeader:  14
    readonly property int sizeLabel:   12
    readonly property int sizeData:    13
    readonly property int sizeMicro:   10
}
