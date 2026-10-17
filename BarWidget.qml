import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "."

// The panel button — both looks (docs/PLUGINS.md → «Theme API»):
//   pixel  a PxButton next to the tray, a cloud with the short tag (1.1.1 / 8.8.8 / ★);
//   mac    a menu bar extra in Golden Gate: a line cloud icon, the tag in the bar's ink.
// A click opens the popup with the current DNS and the pick row for each preset + custom.
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow
    // the pixel bar's hooks: its padding and the hell bar's ink go to the button
    property int hpad: -1
    property bool barInk: false
    readonly property string icon: btn.icon
    readonly property string text: btn.text
    readonly property bool popupOpen: popup.visible

    // what the button shows: the tag of the preset in use ("1.1.1"), «★» for the custom one,
    // «сеть» for the auto one, or the cloud alone while nothing is known yet
    readonly property string tag: Dns.currentId === "" ? "" : (Dns.shortTag(Dns.currentId) || "")

    implicitWidth: Skin.mac ? macRow.implicitWidth + Skin.px(6) : btn.implicitWidth
    implicitHeight: Skin.mac ? Skin.px(18) : btn.implicitHeight

    PxButton {
        id: btn
        visible: !Skin.mac
        anchors.fill: parent
        compact: true
        flat: true
        hpad: root.hpad
        barInk: root.barInk
        hell: Theme.hell
        icon: "cloud"
        text: root.tag
        onClicked: popup.toggle()
    }

    Row {
        id: macRow
        visible: Skin.mac
        anchors.centerIn: parent
        spacing: Skin.px(4)

        MacIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "cloud"
            size: Skin.px(15)
            stroke: 2
            color: Skin.ink(root.screenName)
        }
        PxText {
            visible: root.tag !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.tag
            color: Skin.ink(root.screenName)
        }
    }
    MouseArea {
        visible: Skin.mac
        anchors.fill: parent
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        panelId: "dns-switch"
        anchorItem: root
        above: BarLayout.bottom && !root.mac
        title: Skin.title(I18n.t("Смена DNS", "DNS Switch"))
        icon: "cloud"
        contentWidth: Skin.px(310)
        contentHeight: Skin.px(430)

        PxScroll {
            anchors.fill: parent
            contentHeight: panel.implicitHeight

            Panel {
                id: panel
                width: parent.width
                plugin: root.plugin
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
