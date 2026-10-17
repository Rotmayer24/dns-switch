pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// The pick panel — one file for everything: the bar button's popup (BarPopup) and the settings
// page (Settings → Plugins → Смена DNS) host it with their own `settingsSkin`, so the shared
// controls (PxGroup, SettingRow, PxButton, PxText) draw the right look by themselves.
Column {
    id: root

    property var plugin

    spacing: Skin.px(10)
    width: parent.width

    PxGroup {
        title: I18n.t("Что сейчас", "Right now")
        icon: "cloud"
        width: parent.width

        SettingRow {
            label: I18n.t("Соединение", "Connection")
            PxText {
                text: Dns.haveCon ? Dns.conName : I18n.t("нет активной сети", "no active network")
                color: Dns.haveCon ? Skin.text : Skin.textDim
                font.bold: true
            }
        }
        SettingRow {
            label: I18n.t("Провайдер DNS", "DNS provider")
            PxText {
                text: Dns.currentLabel
                color: Dns.currentId === "" || Dns.currentId === "auto" ? Skin.textDim : Skin.accent
                font.bold: true
            }
        }
        SettingRow {
            label: I18n.t("Серверы", "Servers")
            hint: Dns.now.length ? I18n.t("IPv4 → синим", "IPv4 → blue") : I18n.t("пока пусто", "nothing yet")
            Column {
                spacing: Skin.px(1)
                PxText {
                    text: Dns.list4.join(", ")
                    kind: "tiny"
                    color: Skin.text
                    visible: Dns.list4.length > 0
                }
                PxText {
                    text: Dns.list6.join(", ")
                    kind: "tiny"
                    color: Skin.textDim
                    visible: Dns.list6.length > 0
                }
                PxText {
                    text: "—"
                    kind: "tiny"
                    color: Skin.textFaint
                    visible: Dns.haveCon && !Dns.list4.length && !Dns.list6.length
                }
            }
        }
    }

    PxGroup {
        title: I18n.t("Кто отвечает", "Who answers")
        icon: "layers"
        width: parent.width

        Repeater {
            model: Dns.rows
            delegate: SettingRow {
                id: row
                required property var modelData

                label: modelData.label
                hint: modelData.note
                PxButton {
                    property bool isNow: row.modelData.id === Dns.currentId

                    compact: true
                    checked: isNow
                    accent: !isNow
                    enabled: !Dns.busy && (row.modelData.id === "auto" || row.modelData.v4.length || row.modelData.v6.length)
                    icon: isNow ? "check" : ""
                    text: isNow ? I18n.t("стоит", "on") : I18n.t("выбрать", "pick")
                    onClicked: Dns.apply(row.modelData.id)
                }
            }
        }
    }

    PxText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Dns.phase === "applying" ? I18n.t("меняю DNS…", "switching DNS…") : Dns.message
        kind: "tiny"
        color: Dns.phase === "applying" ? Skin.textDim : Skin.ok
        visible: Dns.phase === "applying" || Dns.message !== ""
    }
    PxText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: Dns.error !== "" ? "✕ " + Dns.error : ""
        kind: "tiny"
        color: Skin.danger
        visible: Dns.error !== ""
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Skin.px(10)

        PxButton {
            compact: true
            flat: true
            icon: "refresh"
            text: I18n.t("Обновить", "Refresh")
            enabled: !Dns.busy
            onClicked: Dns.scan()
        }
    }
}
