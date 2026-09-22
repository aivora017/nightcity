pragma Singleton
import Quickshell

Singleton {
    property bool launcherOpen: false
    property string launcherMode: "apps"   // "apps" or "search"
    property int unread: 0
    property bool centreOpen: false
    property var history: []

    function remember(entry) {
        const h = history.slice();      // copy, change, reassign: QML only notices a new array
        h.unshift(entry);
        if (h.length > 50) h.pop();
        history = h;
    }
    property bool netOpen: false
    property bool wifiEnabled: true
    property bool btPowered: false
    property bool docOpen: false
    property bool keysOpen: false
    property bool notesOpen: false
    property bool powerOpen: false
    property bool nightLight: false
    property bool vpnUp: false
    property bool btScanning: false
    property string governor: "powersave"
    property bool locationOn: false
    property bool overviewOpen: false

    // ---------- UI sounds ----------
    function play(name) {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/nc-play", name]);
    }
    onLauncherOpenChanged: play(launcherOpen ? "open" : "close")
    onNetOpenChanged:      play(netOpen ? "open" : "close")
    onCentreOpenChanged:   play(centreOpen ? "open" : "close")
    onDocOpenChanged:      play(docOpen ? "open" : "close")
    onKeysOpenChanged:     play(keysOpen ? "open" : "close")
    onNotesOpenChanged:    play(notesOpen ? "open" : "close")
    onPowerOpenChanged:    play(powerOpen ? "open" : "close")
    onOverviewOpenChanged: play(overviewOpen ? "open" : "close")
}
