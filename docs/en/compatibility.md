# Device compatibility

[Italiano](../it/compatibility.md) · [README](../../README.md)

Version 0.11.0, development preview. Updated 8 November 2026. “Candidate” is not a passed hardware test.

| Device | Video/workspace | Head tracking | Evidence |
| --- | --- | --- | --- |
| RayNeo GT | Implemented | GT HID driver | Earlier M2 sessions reported working; current acceptance pending. |
| Other RayNeo models | Experimental external-display candidate | No matching driver | Not tested. |
| XREAL / VITURE / Rokid | Experimental external-display candidates | No driver | Not tested; turn tracking off. |
| Ordinary external monitor | Possible output through external-display fallback | No headset tracker | Useful for experimentation, not a headset certification. |
| Intel Mac | No arm64 host target | — | Not supported by this build. |
| Apple Silicon M1/M2/M3/M4 and later | arm64, macOS 26+ required | Depends on headset | Only M2 has historical reports; no per-chip certification. |

The app prefers an external display whose name contains `smartglasses` or `rayneo`, otherwise the first non-built-in/non-virtual display. It does not yet provide a manual output selector. With a desktop Mac or multiple external monitors, test output selection carefully; automatic choice can target the wrong display. A generic app name does not make tracking universal.

GT tracking matches VID `0x3941`, PID `0xAF50`, usage page `0xFF00`, usage `1`. USB-C must carry video and HID data; charging-only cables are insufficient. Hubs and HDMI adapters are not validated. No firmware-version matrix is available. Tracking integrates gyro yaw; this is not absolute positioning or positional 6DoF.

## Companion devices

| Device | Requirement / restriction |
| --- | --- |
| iPhone 15 family | Platform supports USB-C DisplayPort; app + glasses workflow unverified. |
| iPhone 16 / Plus / Pro / Pro Max | Platform supports external displays; app workflow unverified. |
| iPhone 16e | No USB-C external-display support; unsuitable for directly connected glasses. |
| iPhone 17 / Pro / Pro Max | Platform external-video candidates; no project device validation. |
| Other iPhone models | Check exact model video capability; USB-C alone is insufficient. |
| iPad | iPadOS 17+ target; output depends on exact model and adapter; untested. |
| Lightning devices | Direct USB-C glasses workflow unavailable; adapter configurations unverified. |
| Android / Windows | No companion/host target. |

The client requires iOS/iPadOS 17+. Apple's [USB-C guide](https://support.apple.com/en-us/105099) describes platform video support; it does not certify Spatial Workspace. The companion selects one monitor manually. Head tracking on iOS is not implemented. Mac must be awake with an open user session, reachable on the LAN or a private VPN. Codec/network roundtrip and latency still need device testing.

Report app commit, Mac/OS, glasses/firmware, cable/dock, video, tracking, reconnect/sleep and session duration separately. Include phone model/OS for remote reports. Never include pairing secrets.
