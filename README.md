# DNS Switch (dns-switch)

AngelOS plugin. Switches the active connection's DNS with one click.
Works through NetworkManager (`nmcli`), no root needed — polkit handles
user-level profile edits.

## Features

- Panel button with current tag (`1.1.1`, `8.8.8`, `9.9.9`, `★` for custom)
- Popup picker: Auto (DHCP), Cloudflare, Google, Quad9, AdGuard, Yandex, Custom
- Custom DNS — IPv4/IPv6 fields in plugin settings (comma-separated)
- Reads current servers from `resolv.conf` via `nmcli`, not a stored flag
- Works in both looks (pixel / Golden Gate) and both realms (heaven / hell)

## Install

**Local (no registry):**
```bash
cp -a ~/dns-switch ~/.config/angelos/plugins/dns-switch
# then reload via Settings → Plugins → ↻ or angelos restart
```

**From ZIP (angelOS loader):**
Import `dns-switch-root.zip` — `manifest.json` at root.

**From GitHub Release:**
Use `source` link in `plugins.json` registry entry.

## Use

1. Click the ☁ button on the bar.
2. Pick a provider — applied immediately (`nmcli device reapply`, Wi-Fi stays up).
3. Custom DNS: Settings → Plugins → DNS Switch → fill IPv4/IPv6, apply.

## Technical

- Service: `Dns.qml` singleton — scans `nmcli`, applies via argv (no shell)
- Apply: `nmcli con mod <profile>` → `nmcli device reapply <dev>`; falls back to reconnect
- Handles `ipv6.method` disabled profiles safely (skips ipv6.dns if denied)
- No external dependencies beyond NetworkManager (usually preinstalled)

## License

MIT — see `LICENSE`.
