import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

Column {
    id: root

    property var plugin
    property string editId: ""      // which saved entry the form is editing ("" = new)
    width: parent ? parent.width : 400
    spacing: Skin.px(10)

    PxGroup {
        title: I18n.t("Смена DNS", "DNS Switch")
        icon: "cloud"
        width: parent.width
        Panel {
            width: parent.width
            plugin: root.plugin
        }
    }

    // saved custom entries
    PxGroup {
        title: I18n.t("Мои DNS", "My DNS")
        icon: "pin"
        width: parent.width
        visible: list.count > 0

        Repeater {
            id: list
            model: { Dns.customRev; return Dns.entries(); }

            Column {
                width: parent.width
                spacing: Skin.px(4)

                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: modelData.name + " — " + modelData.n4.concat(modelData.n6).join(", ")
                }
                Row {
                    spacing: Skin.px(8)
                    PxButton {
                        compact: true
                        accent: true
                        text: I18n.t("Включить", "Use")
                        enabled: !Dns.busy
                        onClicked: Dns.apply("custom:" + modelData.id)
                    }
                    PxButton {
                        compact: true
                        flat: true
                        text: I18n.t("Изменить", "Edit")
                        onClicked: {
                            root.editId = modelData.id;
                            nameField.text = modelData.rawName;
                            v4Field.text = modelData.v4text;
                            v6Field.text = modelData.v6text;
                        }
                    }
                    PxButton {
                        compact: true
                        flat: true
                        icon: "trash"
                        text: I18n.t("Удалить", "Delete")
                        enabled: !Dns.busy
                        onClicked: {
                            if (root.editId === modelData.id)
                                root.editId = "";
                            Dns.removeCustom(modelData.id);
                        }
                    }
                }
            }
        }
    }

    // add / edit form
    PxGroup {
        title: root.editId !== "" ? I18n.t("Изменить DNS", "Edit DNS") : I18n.t("Добавить свой DNS", "Add custom DNS")
        icon: "pin"
        width: parent.width

        SettingRow {
            label: I18n.t("Имя (можно пустое)", "Name (optional)")
            PxField {
                id: nameField
                width: parent.width
                placeholder: I18n.t("Мой DNS", "My DNS")
                onAccepted: v4Field.focusField()
            }
        }
        SettingRow {
            label: I18n.t("IPv4 серверы", "IPv4 servers")
            hint: I18n.t("через запятую, например 1.1.1.1, 1.0.0.1", "comma separated, e.g. 1.1.1.1, 1.0.0.1")
            PxField {
                id: v4Field
                width: parent.width
                placeholder: "1.1.1.1, 1.0.0.1"
                onAccepted: v6Field.focusField()
            }
        }
        SettingRow {
            label: I18n.t("IPv6 серверы", "IPv6 servers")
            hint: I18n.t("можно оставить пустым", "can stay empty")
            PxField {
                id: v6Field
                width: parent.width
                placeholder: "2606:4700:4700::1111, 2606:4700:4700::1001"
                onAccepted: applyBtn.forceActiveFocus()
            }
        }

        Row {
            spacing: Skin.px(10)

            PxButton {
                id: applyBtn
                accent: true
                icon: "check"
                text: I18n.t("Сохранить и включить", "Save and turn on")
                enabled: !Dns.busy
                onClicked: {
                    const r = Dns.saveCustom(nameField.text, v4Field.text, v6Field.text, root.editId);
                    if (!r.ok)
                        return;
                    root.editId = "";
                    nameField.text = "";
                    v4Field.text = "";
                    v6Field.text = "";
                    Dns.apply(r.rowId);
                }
            }
            PxButton {
                compact: true
                flat: true
                text: I18n.t("Только сохранить", "Save only")
                enabled: !Dns.busy
                onClicked: {
                    const r = Dns.saveCustom(nameField.text, v4Field.text, v6Field.text, root.editId);
                    if (!r.ok)
                        return;
                    root.editId = "";
                    nameField.text = "";
                    v4Field.text = "";
                    v6Field.text = "";
                }
            }
            PxButton {
                compact: true
                flat: true
                text: I18n.t("Очистить поля", "Clear fields")
                onClicked: {
                    root.editId = "";
                    nameField.text = "";
                    v4Field.text = "";
                    v6Field.text = "";
                }
            }
        }

        PxText {
            width: parent.width
            visible: Dns.error !== ""
            wrapMode: Text.Wrap
            kind: "tiny"
            color: Skin.textDim
            text: Dns.error
        }

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            color: Skin.textDim
            text: I18n.t("Принимаются только IP-адреса (DNS-over-TLS/HTTPS NetworkManager здесь не применяет). Хочешь быстрого переключения — добавь «Смена DNS» на панель: ПКМ по панели → Иконки.", "IP addresses only (Manager's DNS-over-TLS/HTTPS does not apply here). For a quick switch add 'DNS Switch' to the bar: right click on the bar → Icons.")
        }
    }
}
