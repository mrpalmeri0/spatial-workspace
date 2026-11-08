# Spatial Workspace

[Italiano](README.it.md) · English

**Your Mac, beyond a single screen.** A native spatial desktop with one, two or three independent virtual displays, live preview, focus tools and an experimental iPhone companion.

![Spatial Workspace in English](docs/images/workspace-en.jpg)

**0.11.0 · development preview · Apple Silicon · macOS 26+**

Spatial Workspace is a generic project name. Head tracking currently has one implemented hardware driver: **RayNeo GT**. Other video-capable headsets are experimental display-only candidates; their tracking protocols are not implemented. This is an independent community project.

## What you can do

| Feature | Behavior |
| --- | --- |
| Cinema / Dual / Triple | 1–3 independent 1920 × 1080 macOS desktops |
| Head tracking | GT gyro integration, calibration, recentering and optional drift correction |
| Real Mac apps | Native windows, mouse, keyboard, scrolling and dragging |
| Preview | 3D layout or the glasses' live camera view on the Mac |
| Focus tools | Cursor recall, monitor radar, focus lock and quick keyboard panel |
| Companion | Experimental TLS/PSK + H.264 iPhone/iPad remote, trackpad and manual display selection |
| Languages | English and Italian; system language or an in-app language choice |

## Quick start

```sh
git clone https://github.com/mrpalmeri0/spatial-workspace.git
cd spatial-workspace
SIGNING_IDENTITY=- bash build.sh
open build/dev/RayNeoWorkspace-Dev.app
```

Requires Xcode with a macOS 26+ SDK. This builds an ad hoc signed local preview, not a notarized binary. Select Cinema, Dual or Triple, connect the headset, press **Start session**, and grant Screen & System Audio Recording when requested. The app captures no audio. Keep the GT still for calibration; recenter when needed. Stop the session before unplugging.

For normal input no Accessibility permission is needed. Window movement, synthetic keys and remote control require it. [Full setup](docs/en/quickstart.md).

## Devices and limits

| Component | Requirement / evidence |
| --- | --- |
| Mac | Apple Silicon, macOS 26+. Earlier M2 + GT sessions were reported working; current build is not certified on every chip. |
| RayNeo GT | Display output and HID tracking implemented; USB-C video + USB data, Follow mode. Current hardware acceptance remains pending. |
| Other headsets | Only experimental external-display use with tracking disabled. No XREAL/VITURE/Rokid/other RayNeo tracking driver is included. |
| iPhone/iPad | iOS/iPadOS 17+ target. External video requires a model supporting it. Full remote device workflow is still unverified. |
| Intel / Windows / Android | No supported target. |

The [device matrix](docs/en/compatibility.md) separates video capability, implemented tracking and actual test results. The app relies on private macOS virtual-display APIs; compatibility may change. Gyro tracking can drift and is not positional 6DoF. Remote 1080p/30 fps is a configured target, not a measured performance claim.

## Learn and contribute

| Guide | English | Italiano |
| --- | --- | --- |
| Setup and languages | [Start](docs/en/quickstart.md) | [Inizia](docs/it/quickstart.md) |
| Devices | [Compatibility](docs/en/compatibility.md) | [Compatibilità](docs/it/compatibility.md) |
| Screens and workflows | [User guide](docs/en/guide.md) | [Guida d'uso](docs/it/guide.md) |
| Architecture | [Architecture](docs/en/architecture.md) | [Architettura](docs/it/architecture.md) |
| Build, tests, diagnostics | [Development](docs/en/development.md) | [Sviluppo](docs/it/development.md) |
| Source and binary releases | [Release](docs/en/release.md) | [Pubblicazione](docs/it/release.md) |
| Permissions and privacy | [Privacy](docs/en/privacy.md) | [Privacy](docs/it/privacy.md) |

[Example presets](examples/README.md) · [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [Security](SECURITY.md) · [Notices](NOTICE.md)

Screen content stays local unless you enable remote sharing. Pairing codes grant desktop access: never post them publicly. Use a private VPN for access away from home. No firmware is flashed. See the privacy guide for storage, permissions and remote behavior.
