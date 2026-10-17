import QtQuick
import Quickshell
import qs.services
import "."

// Background service: while the plugin is on, Dns holds the state and reads it again now
// and then — the bar button, the popup and the settings page read the same singleton.
Item {
    id: root
    property var plugin

    Component.onCompleted: {
        Dns.plugin = plugin;
        Dns.scan();
    }

    // a Wi-Fi handover or a new connection: re-read at a calm pace, only while nothing is busy
    Timer {
        interval: 30000
        running: Dns.plugin !== null
        repeat: true
        onTriggered: if (!Dns.busy)
            Dns.scan()
    }
}
