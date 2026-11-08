# Build, test and diagnose

[Italiano](../it/development.md) · [README](../../README.md)

Xcode with macOS 26+ and iOS SDKs, Python 3 and Apple Silicon are required. There are no third-party package dependencies. Both schemes are shared.

```sh
xcodebuild -project RayNeoWorkspace.xcodeproj -scheme RayNeoWorkspace \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/xcode-mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RayNeoWorkspace.xcodeproj -scheme RayNeoRemote \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/xcode-iphone CODE_SIGNING_ALLOWED=NO build
bash Tests/run-tests.sh
bash Tests/run-remote-tests.sh
bash Tests/run-texture-test.sh
python3 Tests/localization_tests.py
```

Texture checks need a working Metal device. Remote integration uses `bash Tests/run-remote-tests.sh --integration`; codec-only testing uses `--codec`. The preparation environment previously rejected the TLS listener and could not find a VideoToolbox encoder. Protocol checks do not establish a working network/video roundtrip.

When adding/removing sources or localized resource folders, update/review `scripts/generate-xcode-project.py`, then regenerate. It reads `Config/release.env`. Review signing settings because hand-edited Xcode settings can diverge from the generator. Debug uses a local identity; iPhone installation requires your own Team. The script build's bundle identifier is separate from the Xcode build's identifier.

`L` looks up readable Italian keys in bundled English/Italian resources. `LF` formats localized messages without putting runtime data in lookup keys. Keep both tables and format placeholders aligned. Do not translate protocol strings, settings keys, system symbols or persistence identifiers.

```sh
python3 scripts/collect-metrics.py --duration 60
python3 scripts/package-source.py
git diff --check
```

Metrics report local CPU/memory/frame status without images; they are not end-to-end latency tests. The source ZIP includes public docs, images, localization, both targets and configuration, excludes signing secrets/build products, and carries a SHA-256 manifest. Dirty working-tree state is recorded.

## Device acceptance still required

Check native input on all layouts, text readability, recenter/drift/slow turns, 10 start-stop cycles, reconnect, manual Stop precedence, sleep/wake, window recovery, Focus/panel input, both rendering paths and both languages. For remote tests check the correct and wrong secret, video readability, keyboard, external scene, VPN and background disconnect. Record exact app commit and devices; do not describe compilation as hardware acceptance.
