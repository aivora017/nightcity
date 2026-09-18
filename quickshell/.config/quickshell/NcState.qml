pragma Singleton
import Quickshell

Singleton {
    property bool launcherOpen: false
    property string launcherMode: "apps"   // "apps" or "search"
    property int unread: 0
}
