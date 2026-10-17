pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.config

Singleton {
    id: root

    signal applied(string id, bool ok, string message)

    readonly property var presets: [
        {
            "id": "auto", "label": I18n.t("Авто (сеть)", "Auto (network)"),
            "tag": I18n.t("сеть", "net"), "v4": [], "v6": [],
            "note": I18n.t("как у роутера или провайдера", "from the router or ISP")
        },
        {
            "id": "cloudflare", "label": "Cloudflare", "tag": "1.1.1",
            "v4": ["1.1.1.1", "1.0.0.1"],
            "v6": ["2606:4700:4700::1111", "2606:4700:4700::1001"],
            "note": I18n.t("самый быстрый, без фильтров", "fastest, no filtering")
        },
        {
            "id": "google", "label": "Google", "tag": "8.8.8",
            "v4": ["8.8.8.8", "8.8.4.4"],
            "v6": ["2001:4860:4860::8888", "2001:4860:4860::8844"],
            "note": I18n.t("стабильный", "reliable")
        },
        {
            "id": "quad9", "label": "Quad9", "tag": "9.9.9",
            "v4": ["9.9.9.9", "149.112.112.112"],
            "v6": ["2620:fe::fe", "2620:fe::9"],
            "note": I18n.t("блокирует вредные сайты", "blocks malicious sites")
        },
        {
            "id": "adguard", "label": "AdGuard", "tag": "94",
            "v4": ["94.140.14.14", "94.140.15.15"],
            "v6": ["2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff"],
            "note": I18n.t("режет рекламу", "cuts ads")
        },
        {
            "id": "yandex", "label": I18n.t("Яндекс", "Yandex"), "tag": "77",
            "v4": ["77.88.8.8", "77.88.8.1"],
            "v6": ["2a02:6b8::feed:bad", "2a02:6b8:0:1::feed:bad"],
            "note": I18n.t("работает в России", "works in Russia")
        }
    ]

    property var plugin: null

    property string phase: "idle"
    property string error: ""
    property string message: ""
    property string conName: ""
    property string conDevice: ""
    property var list4: []
    property var list6: []
    property bool profileAuto: true
    property string method4: "auto"
    property string method6: "auto"
    readonly property bool can4: method4 === "auto" || method4 === "dhcp" || method4 === "manual"
    readonly property bool can6: method6 === "auto" || method6 === "dhcp" || method6 === "manual"

    readonly property bool busy: active.running || dnsQ.running || profileQ.running || moder.running || reloader.running || bringup.running
    readonly property bool haveCon: conName !== ""
    readonly property var now: list4.concat(list6)

    // ---- helpers ----
    function parseServers(text) {
        return String(text || "").split(/[\s,;]+/).map(s => s.trim()).filter(s => s !== "");
    }
    function isV4(s) { return /^\d{1,3}(\.\d{1,3}){3}$/.test(s); }
    function isV6(s) { return s.includes(":") && /^[0-9a-fA-F:.]+$/.test(s); }

    property int customRev: 0
    function refresh() { customRev++; }

    // ---- custom DNS list: [{id, name, v4, v6}] stored as JSON in plugin "customList" ----
    // customOverride holds the list saved in this session (plugin.get() may lag behind set()).
    property var customOverride: null

    function loadCustom() {
        if (customOverride !== null)
            return customOverride;
        if (!plugin)
            return [];
        const raw = plugin.get("customList", "");
        if (raw) {
            try {
                const arr = JSON.parse(raw);
                if (Array.isArray(arr))
                    return arr;
            } catch (e) {}
        }
        // migration from the old single entry
        const c4 = plugin.get("custom4", ""), c6 = plugin.get("custom6", "");
        if (c4 || c6)
            return [{ id: "c1", name: plugin.get("customName", "") || "", v4: c4, v6: c6 }];
        return [];
    }

    function storeCustom(list) {
        customOverride = list;
        if (plugin)
            plugin.set("customList", JSON.stringify(list));
        refresh();
    }

    // normalized entries for the UI and apply()
    function entries() {
        customRev + 0;
        return loadCustom().map(e => {
            const a4 = parseServers(e.v4), a6 = parseServers(e.v6);
            return {
                "id": e.id,
                "name": e.name || I18n.t("Свой DNS", "Custom DNS"),
                "rawName": e.name || "",
                "v4text": e.v4 || "",
                "v6text": e.v6 || "",
                "n4": a4.filter(isV4),
                "n6": a6.filter(isV6),
                "bad": a4.concat(a6).filter(s => !isV4(s) && !isV6(s))
            };
        });
    }

    function findEntry(rowId) {
        const id = String(rowId).replace(/^custom:/, "");
        return entries().find(e => e.id === id) || null;
    }

    readonly property var rows: {
        const rev = customRev + 0;
        const list = entries();
        const custom = list.length
            ? list.map(e => ({
                "id": "custom:" + e.id,
                "label": e.name,
                "tag": "★",
                "v4": e.n4,
                "v6": e.n6,
                "note": e.n4.concat(e.n6).join(", ")
            }))
            : [{
                "id": "custom",
                "label": I18n.t("Свой DNS", "Custom DNS"),
                "tag": "★",
                "v4": [],
                "v6": [],
                "note": I18n.t("вставь адреса в настройках плагина", "put addresses on the plugin's settings page")
            }];
        return presets.concat(custom);
    }

    function calcCurrent(rev) {
        rev = rev + (customRev || 0);
        if (list4.length === 0 && list6.length === 0)
            return "";
        if (profileAuto)
            return "auto";
        const me = list4.map(s => s.trim()).join(" "), ms = list6.map(s => s.trim()).join(" ");
        for (const e of entries())
            if ((e.n4.length || e.n6.length) && me === e.n4.join(" ") && ms === e.n6.join(" "))
                return "custom:" + e.id;
        for (const p of presets)
            if (p.id !== "auto" && p.v4.length !== 0
                    && p.v4.join(" ") === me && p.v6.join(" ") === ms)
                return p.id;
        return "";
    }
    readonly property string currentId: calcCurrent(customRev + 0)
    readonly property string currentLabel: {
        if (currentId !== "") {
            const r = rows.find(r => r.id === currentId);
            if (r) return r.label;
        }
        return profileAuto && (list4.length || list6.length)
            ? I18n.t("Авто (сеть)", "Auto (network)")
            : I18n.t("свои адреса", "some addresses");
    }
    readonly property string serverText: now.length ? now.join(" · ") : "—"

    function shortTag(id) {
        const r = rows.find(r => r.id === id);
        if (!r)
            return "";
        if (String(r.id).startsWith("custom"))
            return r.v4.length ? r.v4[0] : "★";
        return r.tag;
    }

    // ---- scanning ----
    function scan() {
        if (busy)
            return;
        if (phase !== "applying")
            phase = "scanning";
        error = "";
        active.running = true;
    }

    Process {
        id: active
        command: ["nmcli", "-t", "-f", "NAME,DEVICE,STATE", "con", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: root._activeOut = text
        }
        stderr: StdioCollector {
            onStreamFinished: root._activeErr = text.trim()
        }
        onExited: code => {
            if (code === 127) { root._scanFail(I18n.t("nmcli не найден — нужен NetworkManager", "nmcli is missing — NetworkManager is needed")); return; }
            if (code !== 0) { root._scanFail(root._activeErr || "nmcli: " + code); return; }
            let name = "", dev = "";
            for (const l of root._activeOut.split("\n")) {
                const i1 = l.lastIndexOf(":");
                if (i1 < 0) continue;
                const state = l.slice(i1 + 1);
                const rest = l.slice(0, i1);
                const i2 = rest.lastIndexOf(":");
                if (i2 < 0) continue;
                if (state === "activated" && rest.slice(i2 + 1) !== "" && rest.slice(i2 + 1) !== "lo") {
                    name = rest.slice(0, i2);
                    dev = rest.slice(i2 + 1);
                }
            }
            root._activeOut = "";
            root.conName = name;
            root.conDevice = dev;
            if (name === "") {
                root.list4 = [];
                root.list6 = [];
                if (root.phase === "scanning") root.phase = "idle";
                return;
            }
            dnsQ.running = true;
            profileQ.running = true;
        }
    }

    Process {
        id: dnsQ
        command: ["nmcli", "-t", "-f", "IP4.DNS,IP6.DNS", "dev", "show", root.conDevice]
        property string out: ""
        stdout: StdioCollector {
            onStreamFinished: dnsQ.out = text
        }
        onExited: code => {
            root._devOut = code === 0 ? out : "";
            out = "";
            if (!profileQ.running) root._scanDone();
        }
    }

    Process {
        id: profileQ
        command: ["nmcli", "-t", "-f", "ipv4.method,ipv6.method,ipv4.ignore-auto-dns,ipv6.ignore-auto-dns", "con", "show", root.conName]
        property string out: ""
        stdout: StdioCollector {
            onStreamFinished: profileQ.out = text
        }
        onExited: code => {
            root._profileOut = code === 0 ? out : "";
            out = "";
            if (!dnsQ.running) root._scanDone();
        }
    }

    property string _activeOut: ""
    property string _activeErr: ""
    property string _devOut: ""
    property string _profileOut: ""

    function _scanFail(why) {
        phase = "error";
        error = why;
        _devOut = "";
        _profileOut = "";
    }

    function _scanDone() {
        const v4 = [], v6 = [];
        for (const l of (_devOut || "").split("\n")) {
            if (l.startsWith("IP4.DNS")) {
                const v = l.replace(/^IP4\.DNS\[\d+\]:\s*/, "").trim();
                if (v !== "") v4.push(v);
            } else if (l.startsWith("IP6.DNS")) {
                const v = l.replace(/^IP6\.DNS\[\d+\]:\s*/, "").trim();
                if (v !== "") v6.push(v);
            }
        }
        list4 = v4;
        list6 = v6;
        let auto = true;
        let m4 = "auto", m6 = "auto";
        for (const l of (_profileOut || "").split("\n")) {
            const v = l.split(":").slice(1).join(":").trim();
            if (l.startsWith("ipv4.method") || l.startsWith("ipv6.method")) {
                if (l.startsWith("ipv4.method")) m4 = v;
                else m6 = v;
                continue;
            }
            if (!l.startsWith("ipv4.ignore-auto-dns") && !l.startsWith("ipv6.ignore-auto-dns"))
                continue;
            if (v === "yes")
                auto = false;
        }
        profileAuto = auto;
        method4 = m4 !== "" ? m4 : method4;
        method6 = m6 !== "" ? m6 : method6;
        _devOut = "";
        _profileOut = "";
        if (phase === "scanning")
            phase = "idle";
    }

    // ---- applying: id is a preset id or "custom:<entry id>" ----
    function apply(id) {
        if (busy || !haveCon) {
            if (!haveCon) {
                phase = "error";
                error = I18n.t("нет активного соединения", "there is no active connection");
                applied(id, false, error);
            }
            return;
        }
        let v4, v6;
        if (String(id).startsWith("custom")) {
            const e = findEntry(id);
            if (!e) {
                phase = "error";
                error = I18n.t("свой DNS пуст — вставь адреса в настройках", "the custom DNS is empty — put addresses in the settings");
                applied(id, false, error);
                return;
            }
            v4 = e.n4;
            v6 = e.n6;
            if (e.bad.length) {
                phase = "error";
                error = I18n.t("не похоже на IP: ", "does not look like an IP: ") + e.bad.join(", ");
                applied(id, false, error);
                return;
            }
        } else {
            const p = presets.find(p => p.id === id);
            if (!p) return;
            v4 = p.v4.filter(isV4);
            v6 = p.v6.filter(isV6);
        }
        const isAuto = id === "auto";
        if (!isAuto && v4.length === 0 && v6.length === 0) {
            phase = "error";
            error = I18n.t("в наборе нет адресов", "the preset has no addresses");
            applied(id, false, error);
            return;
        }
        if (!can4 && !can6) {
            phase = "error";
            error = I18n.t("профиль запрещает свои DNS (метод disabled)", "the profile denies custom DNS (a disabled method)");
            applied(id, false, error);
            return;
        }
        phase = "applying";
        error = "";
        message = "";
        const cmd = ["nmcli", "con", "mod", conName];
        if (can4)
            cmd.push("ipv4.ignore-auto-dns", isAuto ? "no" : "yes", "ipv4.dns", v4.join(","));
        if (can6)
            cmd.push("ipv6.ignore-auto-dns", isAuto ? "no" : "yes", "ipv6.dns", v6.join(","));
        moder.command = cmd;
        moder.running = true;
    }

    Process {
        id: moder
        property string errOut: ""
        stderr: StdioCollector {
            onStreamFinished: moder.errOut = text.trim()
        }
        onExited: code => {
            if (code !== 0) {
                root.phase = "error";
                root.error = moder.errOut || ("nmcli: " + code);
                root.applied("apply", false, root.error);
                return;
            }
            reloader.command = ["nmcli", "device", "reapply", root.conDevice];
            reloader.running = true;
        }
    }

    Process {
        id: reloader
        property string errOut: ""
        stderr: StdioCollector {
            onStreamFinished: reloader.errOut = text.trim()
        }
        onExited: code => {
            if (code !== 0) {
                bringup.command = ["nmcli", "con", "up", root.conName];
                bringup.running = true;
                return;
            }
            root.finish();
        }
    }

    Process {
        id: bringup
        property string errOut: ""
        stderr: StdioCollector {
            onStreamFinished: bringup.errOut = text.trim()
        }
        onExited: code => {
            if (code !== 0) {
                root.phase = "error";
                root.error = I18n.t("переподключить не вышло: ", "could not reconnect: ") + (bringup.errOut || "nmcli " + code);
                root.applied("apply", false, root.error);
                return;
            }
            root.finish();
        }
    }

    function finish() {
        phase = "idle";
        Qt.callLater(() => {
            scan();
            const id = calcCurrent(customRev);
            const r = rows.find(r => r.id === id);
            message = (r ? r.label : "DNS") + I18n.t(" — готово ✓", " — done ✓");
            applied(id, true, message);
        });
    }

    // ---- custom DNS: save / remove ----
    // editId: id of an existing entry to overwrite, or "" to add a new one.
    // returns {ok, bad[], id, rowId}
    function saveCustom(name, v4text, v6text, editId) {
        const cleanV4 = String(v4text || "").trim();
        const cleanV6 = String(v6text || "").trim();
        const all = parseServers(cleanV4).concat(parseServers(cleanV6));
        const bad = all.filter(x => !isV4(x) && !isV6(x));
        if (bad.length) {
            error = I18n.t("Не IP: ", "Not an IP: ") + bad.join(", ");
            return { ok: false, bad: bad, id: "", rowId: "" };
        }
        if (all.length === 0) {
            error = I18n.t("введи хотя бы один IP-адрес", "enter at least one IP address");
            return { ok: false, bad: [], id: "", rowId: "" };
        }
        const list = loadCustom().slice();
        const entry = {
            id: editId || ("c" + Date.now()),
            name: String(name || "").trim(),
            v4: cleanV4,
            v6: cleanV6
        };
        const idx = list.findIndex(e => e.id === entry.id);
        if (idx >= 0) list[idx] = entry;
        else list.push(entry);
        error = "";
        storeCustom(list);
        return { ok: true, bad: [], id: entry.id, rowId: "custom:" + entry.id };
    }

    function removeCustom(entryId) {
        storeCustom(loadCustom().filter(e => e.id !== entryId));
        error = "";
    }

    function clearCustom() {
        storeCustom([]);
        error = "";
    }

    Timer {
        id: msgTimer
        onTriggered: root.message = ""
    }
    onMessageChanged: if (message !== "") {
        msgTimer.interval = 4000;
        msgTimer.restart();
    }
}
