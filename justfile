# SPDX-License-Identifier: MPL-2.0

set shell := ["bash", "-euo", "pipefail", "-c"]

uv := "uv run --locked --no-dev"
uv_dev := "uv run --locked"
uv_packaging := "uv run --locked --no-dev --group packaging"

# List the available commands.
default:
    @just --list

# Run the focused isolated debug simulator for safe launcher UI states.
[group('Development')]
preview scenario='ready':
    {{ uv }} scripts/localization.py prepare; swift build; binary_dir="$(swift build --show-bin-path)"; {{ uv }} scripts/localization.py compile "$binary_dir"; executable_name="$({{ uv }} scripts/project_config.py executable-name)"; swift run --skip-build "$executable_name" --developer-scenario {{ quote(scenario) }}

# Start the website or download the verified runtime and build a local app bundle or dmg; add run to open app artifacts (default: app).
[group('Development')]
dev target='app' run='':
    @if [[ {{ quote(target) }} == "web" ]]; then cd web && pnpm dev; else runtime_dir="$({{ uv }} scripts/download_runtime.py)"; if [[ {{ quote(target) }} == "dmg" ]]; then {{ uv_packaging }} scripts/build_dmg.py --runtime "$runtime_dir"; artifact_name="$({{ uv }} scripts/project_config.py dmg-name)"; else {{ uv_packaging }} scripts/build_app.py --runtime "$runtime_dir"; artifact_name="$({{ uv }} scripts/project_config.py app-bundle-name)"; fi; path="dist/$artifact_name"; if [[ {{ quote(run) }} == "run" ]]; then open "$path"; fi; fi

# Check core sources (default: all) or the website separately.
[group('Checks')]
check target='all':
    {{ uv_dev }} scripts/checks.py check {{ quote(target) }}

# Format core sources (default: all) or the website separately.
[group('Checks')]
format target='all':
    {{ uv_dev }} scripts/checks.py format {{ quote(target) }}

# Build the Apple Silicon release binary.
[group('Checks')]
build:
    {{ uv }} scripts/localization.py prepare; swift build --configuration release $({{ uv }} scripts/project_config.py swift-architecture-arguments); binary_dir="$(swift build --configuration release $({{ uv }} scripts/project_config.py swift-architecture-arguments) --show-bin-path)"; {{ uv }} scripts/localization.py compile "$binary_dir"

# Run deterministic onboarding, API, installer, and persistence workflows without public network access.
[group('Checks')]
integration:
    {{ uv }} scripts/swift_tests.py integration

# Run read-only contracts against the live Yostar services; never part of normal source checks.
[group('Checks')]
live-contracts:
    {{ uv }} scripts/swift_tests.py live

# Run deterministic validation, integration tests, and build the release binary.
[group('Checks')]
ci: check integration build

# Download the runtime pinned in runtime.json to .build/runtime.
[group('Runtime')]
runtime:
    {{ uv }} scripts/download_runtime.py

# Build the application bundle; optionally embed a Wine runtime directory.
[group('Packaging')]
app runtime='':
    if [[ -n {{ quote(runtime) }} ]]; then {{ uv_packaging }} scripts/build_app.py --runtime {{ quote(runtime) }}; else {{ uv_packaging }} scripts/build_app.py; fi

# Build a DMG with the required Wine runtime directory.
[group('Packaging')]
dmg runtime:
    {{ uv_packaging }} scripts/build_dmg.py --runtime {{ quote(runtime) }}

# Regenerate the application icon assets.
[group('Packaging')]
icon:
    {{ uv }} scripts/generate_icon.py

# Prepare, replace, or remove a repository-hosted announcement (set/remove). Commit the change to main to publish or withdraw it.
[group('Owner')]
announcement mode id title='' body_file='' action_title='' action_url='' min_version='' max_version='' starts_at='' ends_at='':
    if [[ {{ quote(mode) }} == "remove" ]]; then {{ uv }} scripts/manage_announcements.py remove {{ quote(id) }}; else {{ uv }} scripts/manage_announcements.py set {{ quote(id) }} {{ quote(title) }} {{ quote(body_file) }} --action-title {{ quote(action_title) }} --action-url {{ quote(action_url) }} --min-version {{ quote(min_version) }} --max-version {{ quote(max_version) }} --starts-at {{ quote(starts_at) }} --ends-at {{ quote(ends_at) }}; fi

# Trigger a draft release for the required X.Y.Z version. Requires repository write access.
[group('Owner')]
release version:
    {{ uv }} scripts/trigger_release.py {{ quote(version) }}

# Show manual and Sparkle app-download statistics for published releases. Requires GitHub CLI access.
[group('Owner')]
stats:
    {{ uv }} scripts/release_statistics.py
