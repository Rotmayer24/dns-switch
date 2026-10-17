# DNS Switch (dns-switch)

AngelOS plugin. Switches the active connection's DNS with one click.
Works through NetworkManager (`nmcli`), no root needed: polkit handles
user-level profile edits.

## Features

- Panel button with the current tag (`1.1.1`, `8.8.8`, `9.9.9`; for a custom DNS, its first IPv4 address, or `★` if it has no IPv4)
- Popup picker: Auto (DHCP), Cloudflare, Google, Quad9, AdGuard, Yandex and your own entries
- Custom DNS: save any number of named entries (IPv4/IPv6, comma-separated) in the plugin settings; each appears in the popup under its own name
- Reads the servers actually in use from NetworkManager (`nmcli dev show`), not a stored flag
- Works in both looks (pixel / Golden Gate) and both realms (heaven / hell)

## Install

**Local (no registry):**
```bash
cp -a ~/dns-switch ~/.config/angelos/plugins/dns-switch
# then reload via Settings → Plugins → ↻ or angelos restart
```

**From ZIP (angelOS loader):**
Import `dns-switch-root.zip` (`manifest.json` and `qmldir` at the root).

**From GitHub Release:**
Use the `source` link in the `plugins.json` registry entry.

## Use

1. Click the ☁ button on the bar.
2. Pick a provider. It is applied immediately (`nmcli device reapply`, Wi-Fi stays up).
3. Custom DNS: Settings → Plugins → DNS Switch → fill in the name and IPv4/IPv6 → "Save and turn on" (or "Save only"). Use Edit / Delete in the "My DNS" list to manage entries.

## Technical

- Service: `Dns.qml` singleton (declared in `qmldir` as `singleton Dns 1.0 Dns.qml`). It scans `nmcli` and applies via argv (no shell)
- Apply: `nmcli con mod <profile>`, then `nmcli device reapply <dev>`; falls back to reconnecting the connection
- Skips the IPv6 part when the profile's `ipv6.method` is `disabled` (same for IPv4)
- Custom entries are stored in the plugin settings as a JSON list
- No external dependencies beyond NetworkManager (usually preinstalled)

## Language

[Русский](README.ru.md)

## License

MIT, see `LICENSE`.
