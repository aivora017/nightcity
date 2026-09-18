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
}
