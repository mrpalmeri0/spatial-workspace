# Security and privacy

Version 0.11.0 is experimental. This project has not received an independent security audit.

ScreenCaptureKit processes desktop images locally. Enabling remote sharing sends the selected display to an authenticated companion over TLS 1.2/PSK. Each enable operation generates a new secret; TCP port 9847 accepts one client. Treat the pairing code as desktop access. Do not post it in issues, logs, screenshots or videos. Use a private VPN for remote access instead of exposing the port publicly.

Screen recording is needed for display capture; Accessibility is needed for window movement, synthetic keys and remote input. Ordinary local input remains native. The app does not capture audio, persist video recordings, flash firmware or unlock the Mac.

Preferences and diagnostics live under `~/Library/Application Support/RayNeoWorkspace-Dev/`. Check diagnostic files and custom background paths for personal information before sharing. Local signing material in `.signing-config/` and `.signing-identity` must never be committed.

For a suspected vulnerability, use GitHub's private vulnerability reporting if the repository owner has enabled it. Otherwise open a minimal issue requesting a private contact without exploit details, secrets or personal data. No monitored security email is configured in this source tree.
