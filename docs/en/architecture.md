# Architecture

[Italiano](../it/architecture.md) · [README](../../README.md)

| Layer | Sources | Responsibility |
| --- | --- | --- |
| Mac lifecycle | `Sources/WorkspaceDelegate*.swift`, `main.swift` | Session creation/cleanup, output layout, native UI and preview |
| Display pipeline | `DesktopCapture.swift`, `WorkspaceView.swift`, `SpatialLayout.swift` | ScreenCaptureKit, Metal/Core Image and SceneKit panels |
| GT tracking | `GTTracker.swift`, `GyroIntegrator.swift` | Specific HID protocol, bias estimation and angular integration |
| Tools | `WorkspaceTools.swift`, `WindowShortcuts.swift`, `MonitorTarget.swift` | Explicit cursor/window/key actions and gaze-nearest display |
| Remote host | `RemoteWorkspaceHost.swift`, `RemoteVideoEncoder.swift` | TLS peer, selected screen capture and H.264 |
| Shared | `Shared/` | Framing, video samples and localized strings helper |
| iOS client | `iPhone/` | Connection, video, trackpad, keyboard and external scene |
| Localization | `Resources/en.lproj`, `Resources/it.lproj` | UI/status strings and privacy descriptions in both bundles |

Settings and diagnostics keep their existing `RayNeoWorkspace-Dev` storage directory to preserve user preferences. Internal target/file names and protocol identity also remain stable; these are not the public app name.

Output detection already permits a generic external display, but only the GT has an IMU driver. Future headset support needs a device-specific protocol adapter, sample decoding, units/axis validation, calibration and real reconnect tests. Do not simply add another product ID and claim support.

Session work is generation-checked to reject late callbacks. Bounded cleanup and timeout helpers cover cancellation and resource ordering; a blocked system service can still exceed expectations. Recovery should respect manual Stop. The original output position is persisted for layout recovery; app window restoration is process-local.

The remote path is optional and disabled initially. A random secret authenticates TLS 1.2/PSK. Video frames are bounded rather than queued indefinitely. Client/background and network handling do not unlock the Mac or guarantee recovery from forced sleep.
