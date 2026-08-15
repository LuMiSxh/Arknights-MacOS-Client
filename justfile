# SPDX-License-Identifier: MPL-2.0

set shell := ["bash", "-euo", "pipefail", "-c"]

# List the available commands.
default:
    @just --list

# Run the Arknights client from SwiftPM.
[group('Development')]
run:
    swift run ArknightsClient

# Download the verified runtime and build a local app bundle.
[group('Development')]
dev:
    runtime_dir="$(./scripts/sh/download-runtime.sh)"; ./scripts/sh/build-app.sh --runtime "$runtime_dir"

# Check Swift formatting using the project's strict configuration.
[group('Checks')]
format-check:
    swift format lint --configuration .swift-format --recursive --strict Sources Tests

# Lint the project shell scripts.
[group('Checks')]
shell-check:
    uv tool run --from 'shellcheck-py==0.11.0.1' shellcheck -x -P scripts/sh scripts/sh/*.sh

# Check and format-verify the Python packaging scripts.
[group('Checks')]
python-check:
    uv tool run --from 'ruff==0.16.3' ruff check scripts/python
    uv tool run --from 'ruff==0.16.3' ruff format --check scripts/python
    uv run --no-project --python 3.13 scripts/python/runtime-config.py --validate runtime.json
    uv run --python 3.13 python -m unittest discover --start-directory scripts/python/tests

# Run the Apple Silicon test suite.
[group('Checks')]
test:
    swift test --arch arm64

# Run all validation checks.
[group('Checks')]
check: format-check shell-check python-check test

# Build the Apple Silicon release binary.
[group('Checks')]
build:
    swift build --configuration release --arch arm64

# Run validation and build the release binary.
[group('Checks')]
ci: check build

# Download the runtime pinned in runtime.json to .build/runtime.
[group('Runtime')]
runtime:
    ./scripts/sh/download-runtime.sh

# Build the application bundle; optionally embed a Wine runtime directory.
[group('Packaging')]
app runtime='':
    if [[ -n {{ quote(runtime) }} ]]; then ./scripts/sh/build-app.sh --runtime {{ quote(runtime) }}; else ./scripts/sh/build-app.sh; fi

# Build a DMG with the required Wine runtime directory.
[group('Packaging')]
dmg runtime:
    ./scripts/sh/build-dmg.sh --runtime {{ quote(runtime) }}

# Download the verified runtime and build a local DMG.
[group('Packaging')]
dev-dmg:
    runtime_dir="$(./scripts/sh/download-runtime.sh)"; ./scripts/sh/build-dmg.sh --runtime "$runtime_dir"

# Regenerate the application icon assets.
[group('Packaging')]
icon:
    ./scripts/sh/generate-icon.sh

# Trigger a draft release for the required X.Y.Z version.
[group('Release')]
release version:
    ./scripts/sh/trigger-release.sh {{ quote(version) }}
