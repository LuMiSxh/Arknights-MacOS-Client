# SPDX-License-Identifier: MPL-2.0

set shell := ["bash", "-euo", "pipefail", "-c"]

# List the available commands.
default:
    @just --list

# Run an isolated debug preview with every simulated state available in Settings → Developer.
[group('Development')]
preview scenario='ready':
    swift run ArknightsClient --developer-scenario {{ quote(scenario) }}

# Download the verified runtime and build a local app bundle or dmg; add run to open it after (default: app).
[group('Development')]
dev target='app' run='':
    runtime_dir="$(uv run scripts/download_runtime.py)"; if [[ {{ quote(target) }} == "dmg" ]]; then uv run scripts/build_dmg.py --runtime "$runtime_dir"; path="dist/Arknights Client.dmg"; else uv run scripts/build_app.py --runtime "$runtime_dir"; path="dist/Arknights Client.app"; fi; if [[ {{ quote(run) }} == "run" ]]; then open "$path"; fi

# Check formatting, lint, and test swift, scripts, shim, or all (default: all).
[group('Checks')]
check target='all':
    uv run scripts/checks.py check {{ quote(target) }}

# Format swift, scripts, shim, or all in place (default: all).
[group('Checks')]
format target='all':
    uv run scripts/checks.py format {{ quote(target) }}

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

# Regenerate the application icon assets.
[group('Packaging')]
icon:
    uv run scripts/generate_icon.py

# Prepare, replace, or remove a repository-hosted announcement (set/remove). Commit the change to main to publish or withdraw it.
[group('Owner')]
announcement mode id title='' body_file='' action_title='' action_url='' min_version='' max_version='' starts_at='' ends_at='':
    if [[ {{ quote(mode) }} == "remove" ]]; then uv run scripts/manage_announcements.py remove {{ quote(id) }}; else uv run scripts/manage_announcements.py set {{ quote(id) }} {{ quote(title) }} {{ quote(body_file) }} --action-title {{ quote(action_title) }} --action-url {{ quote(action_url) }} --min-version {{ quote(min_version) }} --max-version {{ quote(max_version) }} --starts-at {{ quote(starts_at) }} --ends-at {{ quote(ends_at) }}; fi

# Trigger a draft release for the required X.Y.Z version. Requires repository write access.
[group('Owner')]
release version:
    uv run scripts/trigger_release.py {{ quote(version) }}

# Show DMG download statistics for all published releases. Requires GitHub CLI access.
[group('Owner')]
stats:
    uv run scripts/release_statistics.py

# Scan Yostar's wallpaper gallery for untagged artwork and file tagging issues. Requires GitHub CLI access.
[group('Owner')]
wallpaper-scan *args:
    uv run scripts/scan_untagged_wallpapers.py {{ args }}
