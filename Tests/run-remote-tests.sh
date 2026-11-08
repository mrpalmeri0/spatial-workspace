#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_test_dir="$(mktemp -d /private/tmp/rayneo-remote-tests.XXXXXX)"
trap 'rm -rf "$task_test_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path /private/tmp/rayneo-swift-cache Shared/*.swift Sources/AsyncDeadline.swift Sources/RemoteVideoEncoder.swift Tests/RemoteTests.swift -o "$task_test_dir/remote-tests"
"$task_test_dir/remote-tests" "$@"
