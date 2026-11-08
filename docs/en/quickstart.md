# Start with Spatial Workspace

[Italiano](../it/quickstart.md) · [README](../../README.md)

1. Connect the glasses directly to an Apple Silicon Mac running macOS 26+. Use USB-C with video and USB data. For GT head tracking, select Follow mode on the glasses.
2. Build using README.md or open `RayNeoWorkspace.xcodeproj`. Internal target names are `RayNeoWorkspace` (Mac) and `RayNeoRemote` (iPhone/iPad); public app names are Spatial Workspace and Spatial Remote.
3. Choose Cinema, Dual or Triple before starting. Press **Start session**. Allow Screen & System Audio Recording in System Settings → Privacy & Security. Reopen the app if macOS requests it. There is no audio capture.
4. For GT tracking, keep the glasses still for at least two seconds and enough valid IMU samples. Wait for tracking ready, then recenter looking forward. With another headset, switch head tracking off; display-only operation is experimental.
5. Use native mouse and keyboard. Move the pointer past the Mac's right edge to reach virtual desktops; drag app windows there. Use Stop before disconnecting.

## Languages and appearance

Settings → Appearance → Language offers **System / English / Italiano**. Controls update immediately; restart to refresh all cached status messages and menus. The iPhone client also has a language picker. System per-app language is supported through English and Italian bundle resources. Liquid Glass is optional in the Mac settings.

## Signing and permissions

`SIGNING_IDENTITY=- bash build.sh` creates an ad hoc local build under `build/dev/`. For repeated use, configure an existing identity with `bash scripts/configure-signing.sh CERTIFICATE_SHA1` or create a dedicated local identity with `python3 scripts/setup-local-signing.py`. The latter changes your local signing/keychain configuration and can prompt macOS. Keep using the same identity during permission tests. Xcode uses its own signing settings; a build-script identity does not automatically change Xcode.

Normal mouse/keyboard input needs no Accessibility permission. Window-moving commands, the virtual keyboard and remote control do. Do not run several copies simultaneously.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| No output | Video-capable cable, external display visible in macOS, no competing app. With multiple external monitors the app can choose the wrong one: try connecting only the headset. |
| No head movement | GT HID connection, Follow mode, calibration, selected axis/direction. Other headsets have no tracking driver. |
| Black capture | Screen recording permission; quit/reopen if requested; try disabling GPU textures and restart the session. |
| Lost controls | Dock icon, menu bar or ⌘0. |
| Changed layout after crash | Reopen with the original output connected and use Restore physical layout. |

See [compatibility](compatibility.md) and [user guide](guide.md).
