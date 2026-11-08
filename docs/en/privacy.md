# Permissions and privacy

[Italiano](../it/privacy.md) · [README](../../README.md)

| Permission / data | Purpose |
| --- | --- |
| Screen & System Audio Recording | Desktop images for local virtual displays or explicitly enabled remote video; no audio is captured. |
| Accessibility | Explicit window moves, cursor/key tools and remote input. Normal local mouse/keyboard input stays native. |
| Local network | iPhone-to-Mac remote connection. |
| Local settings/diagnostics | Preferences, original output position for recovery, CPU/memory/frame status. No recorded video/audio. |

Local files are under `~/Library/Application Support/RayNeoWorkspace-Dev/`: `settings.json`, `pending-layout.json`, `runtime-status.json`. Liquid Glass and language preferences also use app UserDefaults. Custom background paths and diagnostics may reveal personal filenames; review before sharing.

Sharing starts off. Each enable generates a new random secret. TLS 1.2/PSK protects one client on TCP port 9847. The code grants desktop access. Keep it private; do not forward the port to the Internet. Away from home use a private VPN you already control. The Mac stays awake while connected but must already have an open user session; forced sleep and lid closure are not bypassed. The client disconnects in background.

There is no independent security audit, cloud relay, automatic firmware update, firmware flashing, saved video/audio or Mac unlock feature. [Security reporting](../../SECURITY.md).
