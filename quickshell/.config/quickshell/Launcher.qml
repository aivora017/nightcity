//  nightcity — app drawer (grid) and search (list)
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: root
    WlrLayershell.namespace: "nightcity-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: NcState.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    visible: NcState.launcherOpen

    readonly property bool searchMode: NcState.launcherMode === "search"

    // every installed app, minus the hidden ones
    readonly property var allApps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // shell actions, searchable alongside apps
    readonly property var actions: [
        { name: "Next wallpaper",  hint: "Action",  run: () => Quickshell.execDetached(["nc-wall-next"]) },
        { name: "Reload shell",    hint: "Action",  run: () => Quickshell.execDetached(["sh", "-c", "pkill -x quickshell; quickshell & disown"]) },
        { name: "Lock screen",     hint: "Action",  run: () => Quickshell.execDetached(["loginctl", "lock-session"]) },
        { name: "Shortcuts",       hint: "Panel · SUPER+/",       run: () => NcState.keysOpen = true },
        { name: "Workspace overview", hint: "Panel · SUPER+Tab",  run: () => NcState.overviewOpen = true },
        { name: "Power menu",      hint: "Panel · SUPER+X",       run: () => NcState.powerOpen = true },
        { name: "Notes",           hint: "Panel · SUPER+SHIFT+N", run: () => NcState.notesOpen = true },
        { name: "System health",   hint: "Panel",                 run: () => NcState.docOpen = true },
        { name: "Connections",     hint: "Panel",                 run: () => NcState.netOpen = true },
        { name: "Toggle UI sounds", hint: "Action",                run: () => Quickshell.execDetached(["sh", "-c", "f=$HOME/.cache/nightcity/sounds-off; [ -f $f ] && rm $f || touch $f"]) }
    ]

    readonly property var results: {
        const q = input.text.trim().toLowerCase();
        const apps = allApps
            .filter(a => q === "" || (a.name + " " + (a.comment || "") + " " + (a.genericName || "")).toLowerCase().includes(q))
            .map(a => ({ name: a.name, hint: a.genericName || a.comment || "App", entry: a }));
        const acts = actions.filter(x => q !== "" && x.name.toLowerCase().includes(q));
        return searchMode ? acts.concat(apps).slice(0, 40) : apps;
    }

    function close() {
        NcState.launcherOpen = false;
        input.text = "";
    }
    function launch(item) {
        if (item.entry) item.entry.execute();
        else if (item.run) item.run();
        close();
    }

    onVisibleChanged: if (visible) { input.text = ""; grid.currentIndex = 0; list.currentIndex = 0; input.forceActiveFocus(); }

    // ---------- backdrop ----------
    Rectangle {
        anchors.fill: parent
        color: "#c405060a"
        opacity: NcState.launcherOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Column {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: root.searchMode ? parent.height * 0.13 : 96 }
        width: root.searchMode ? 660 : Math.min(parent.width - 140, 1040)
        spacing: 18

        // ---------- search field ----------
        Rectangle {
            width: parent.width
            height: 60
            radius: 18
            color: Theme.glassTint
            border.width: 1
            border.color: Theme.glassBorder

            Text {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: String.fromCodePoint(0xF0349)
                color: Theme.accent
                font.family: Theme.faceData
                font.pixelSize: 20
            }
            TextInput {
                id: input
                anchors { left: parent.left; leftMargin: 56; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                color: "white"
                font.family: Theme.faceHeader
                font.pixelSize: 18
                focus: true
                selectByMouse: true
                onTextChanged: { grid.currentIndex = 0; list.currentIndex = 0 }

                Text {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: root.searchMode ? "Search apps and actions" : "Search apps"
                    color: Theme.spot
                    font: input.font
                    verticalAlignment: Text.AlignVCenter
                }

                Keys.onEscapePressed: root.close()
                Keys.onReturnPressed: {
                    const i = root.searchMode ? list.currentIndex : grid.currentIndex;
                    if (root.results[i]) root.launch(root.results[i]);
                }
                Keys.onDownPressed: root.searchMode ? list.currentIndex++ : grid.moveCurrentIndexDown()
                Keys.onUpPressed:   root.searchMode ? list.currentIndex-- : grid.moveCurrentIndexUp()
                Keys.onLeftPressed:  if (!root.searchMode) grid.moveCurrentIndexLeft()
                Keys.onRightPressed: if (!root.searchMode) grid.moveCurrentIndexRight()
            }
        }

        // ---------- apps grid ----------
        GridView {
            id: grid
            visible: !root.searchMode
            width: parent.width
            height: Math.min(root.height - 220, 560)
            cellWidth: 130
            cellHeight: 124
            clip: true
            model: root.results
            currentIndex: 0
            keyNavigationEnabled: false

            delegate: Item {
                required property var modelData
                required property int index
                width: 130; height: 124

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 18
                    color: "white"
                    opacity: grid.currentIndex === index || appMouse.containsMouse ? 0.09 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: 52
                        source: Quickshell.iconPath(modelData.entry.icon, "application-x-executable")
                    }
                    Text {
                        width: 114
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.name
                        color: grid.currentIndex === index ? "white" : Theme.subtle
                        elide: Text.ElideRight
                        font.family: Theme.faceHeader
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    id: appMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: grid.currentIndex = index
                    onClicked: root.launch(modelData)
                }
            }
        }

        // ---------- search results ----------
        ListView {
            id: list
            visible: root.searchMode
            width: parent.width
            height: Math.min(contentHeight, 440)
            clip: true
            model: root.results
            currentIndex: 0
            keyNavigationEnabled: false

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width
                height: 52
                radius: 14
                color: list.currentIndex === index ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : "transparent"

                Row {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 14
                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 28
                        visible: modelData.entry !== undefined
                        source: modelData.entry ? Quickshell.iconPath(modelData.entry.icon, "application-x-executable") : ""
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: list.currentIndex === index ? "white" : Theme.subtle
                        font.family: Theme.faceHeader
                        font.pixelSize: 14
                    }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    text: modelData.hint
                    color: Theme.spot
                    font.family: Theme.faceData
                    font.pixelSize: 11
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = index
                    onClicked: root.launch(modelData)
                }
            }
        }
    }
}
