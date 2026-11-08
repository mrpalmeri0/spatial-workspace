# Contributing

Start with README.md, docs/NATIVE_APP.md and docs/COMPATIBILITY.md. The host requires Apple Silicon and a macOS 26+ SDK. The companion targets iOS/iPadOS 17+. There are no third-party packages to install.

Keep ordinary Mac input native, remote sharing opt-in and pairing secrets out of logs. Do not add firmware writes or assume another glasses model shares the GT protocol.

Before proposing changes:

```sh
bash Tests/run-tests.sh
bash Tests/run-remote-tests.sh
git diff --check
```

Build the affected target with the unsigned commands in README.md. Run texture tests on a working Metal device when changing rendering. Add focused tests for meaningful behavior changes. State which hardware was actually tested; compilation alone is not acceptance.

When adding/removing sources, update `scripts/generate-xcode-project.py` and regenerate the project. Preserve intentional Xcode settings and review the generated diff; the generator and a hand-edited project can otherwise diverge. Signing certificates and local secrets must stay untracked.

For bugs, include version/commit, OS, device model, cable/adapter, exact steps, expected/actual behavior and reproducibility. Remove pairing codes and personal screen content. For compatibility reports use the provided template. Security concerns follow SECURITY.md. Licensing status is recorded in NOTICE.md; do not assume an open-source grant while it is unresolved.
