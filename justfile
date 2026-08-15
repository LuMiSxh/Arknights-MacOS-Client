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
    runtime_dir="$(uv run scripts/download_runtime.py)"; uv run scripts/build_app.py --runtime "$runtime_dir"

# Check Swift formatting using the project's strict configuration.
[group('Checks')]
format-check:
    swift format lint --configuration .swift-format --recursive --strict Sources Tests

# Lint and format-check the repository automation.
[group('Checks')]
script-check:
    uv tool run --from 'ruff==0.16.3' ruff check scripts
    uv tool run --from 'ruff==0.16.3' ruff format --check scripts
    uv run scripts/runtime_config.py --validate runtime.json
    uv run --python 3.13 python -m unittest discover --start-directory scripts/tests

# Run the Apple Silicon test suite.
[group('Checks')]
test:
    swift test --arch arm64

# Run all validation checks.
[group('Checks')]
check: format-check script-check test

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
    uv run scripts/download_runtime.py

# Build the application bundle; optionally embed a Wine runtime directory.
[group('Packaging')]
app runtime='':
    if [[ -n {{ quote(runtime) }} ]]; then uv run scripts/build_app.py --runtime {{ quote(runtime) }}; else uv run scripts/build_app.py; fi

# Build a DMG with the required Wine runtime directory.
[group('Packaging')]
dmg runtime:
    uv run scripts/build_dmg.py --runtime {{ quote(runtime) }}

# Download the verified runtime and build a local DMG.
[group('Packaging')]
dev-dmg:
    runtime_dir="$(uv run scripts/download_runtime.py)"; uv run scripts/build_dmg.py --runtime "$runtime_dir"

# Regenerate the application icon assets.
[group('Packaging')]
icon:
    uv run scripts/generate_icon.py

# Trigger a draft release for the required X.Y.Z version.
[group('Release')]
release version:
    uv run scripts/trigger_release.py {{ quote(version) }}
