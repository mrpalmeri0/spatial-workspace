# Publishing sources and binaries

[Italiano](../it/release.md) · [README](../../README.md)

Repository: [mrpalmeri0/spatial-workspace](https://github.com/mrpalmeri0/spatial-workspace). Version 0.11.0 is a development preview. Source publishing and a downloadable notarized app are separate deliverables.

For sources, review `git status`, run the checks in development.md and inspect the public ZIP produced by `python3 scripts/package-source.py`. Preserve component notices. Current licensing status is in [NOTICE.md](../../NOTICE.md); no blanket license grant has been assumed.

For a directly distributed Mac binary, set the display names, version/build and your signing configuration in `Config/release.env`, regenerate the Xcode project, install a Developer ID Application identity and store a notarytool profile in your keychain. `bash scripts/release-mac.sh` performs archive, export, notarization, stapling and DMG creation. The final package still needs signature, Gatekeeper and hardware verification. A script existing does not mean a notarized release exists.

The current host uses private virtual-display APIs and non-sandboxed desktop control. Mac App Store submission is not the current distribution path. The iPhone companion has a separate signing/App Store process. Do not tag a stable 1.0 or claim other headset tracking until tested and implemented.

Never upload `.signing-config`, `.signing-identity`, private keys, provisioning profiles, pairing secrets or personal diagnostics. Public developer Team IDs are not private keys, but forks should set their own signing configuration.
