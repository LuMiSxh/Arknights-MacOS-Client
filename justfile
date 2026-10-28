# SPDX-License-Identifier: MPL-2.0

set shell := ["bash", "-euo", "pipefail", "-c"]

uv := "uv run --locked --no-dev"
uv_dev := "uv run --locked"
uv_packaging := "uv run --locked --no-dev --group packaging"
just := quote(just_executable()) + " --justfile " + quote(justfile())

# List the available commands.
default:
    @just --list

# Run the focused isolated debug simulator for safe launcher UI states.
[group('Development')]
preview:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ uv }} scripts/swift_build.py --configuration debug
    binary_dir="$({{ uv }} scripts/swift_build.py --configuration debug --show-bin-path)"
    "$binary_dir/$({{ uv }} scripts/project_config.py executable-name)" --developer-preview

# Start the website or download the verified runtime and build a local app bundle or dmg; add run to open app artifacts (default: app).
[group('Development')]
dev target='app' run='':
    #!/usr/bin/env bash
    set -euo pipefail
    case {{ quote(target) }} in
        web) cd web && exec pnpm dev ;;
        app) name="$({{ uv }} scripts/project_config.py app-bundle-name)" ;;
        dmg) name="$({{ uv }} scripts/project_config.py dmg-name)" ;;
        *) echo "unknown target: "{{ quote(target) }}"; use app, dmg, or web" >&2; exit 2 ;;
    esac
    {{ just }} runtime
    {{ just }} {{ quote(target) }} .build/runtime
    if [[ {{ quote(run) }} == "run" ]]; then open "dist/$name"; fi

# Check core sources (default: all) or one of swift, scripts, shim, web.
[group('Checks')]
check target='all':
    #!/usr/bin/env bash
    set -euo pipefail
    check_swift() {
        find Sources Tests -name '*.swift' -print0 | xargs -0 swift format lint --configuration .swift-format --strict
        {{ just }} swift-tests unit
    }
    check_scripts() {
        {{ uv_dev }} ruff check scripts
        {{ uv_dev }} ruff format --check scripts
        {{ uv_dev }} scripts/consistency.py
        {{ uv_dev }} actionlint .github/workflows/*.yml
        {{ uv_dev }} pytest -q
    }
    check_shim() {
        find RuntimeSupport \( -name '*.c' -o -name '*.m' \) -print0 | xargs -0 xcrun clang-format --dry-run --Werror
    }
    check_web() {
        (cd web && pnpm check && pnpm format:check)
    }
    target={{ quote(target) }}
    for name in $([[ $target == all ]] && echo swift scripts shim || echo "$target"); do
        [[ $name =~ ^(swift|scripts|shim|web)$ ]] || { echo "unknown target: $name; use all, swift, scripts, shim, or web" >&2; exit 2; }
        "check_$name"
    done
    echo "check complete ($target)"

# Format core sources (default: all) or one of swift, scripts, shim, web.
[group('Checks')]
format target='all':
    #!/usr/bin/env bash
    set -euo pipefail
    format_swift() {
        find Sources Tests -name '*.swift' -print0 | xargs -0 swift format format --configuration .swift-format --in-place
    }
    format_scripts() {
        {{ uv_dev }} ruff format scripts
    }
    format_shim() {
        find RuntimeSupport \( -name '*.c' -o -name '*.m' \) -print0 | xargs -0 xcrun clang-format -i
    }
    format_web() {
        (cd web && pnpm format)
    }
    target={{ quote(target) }}
    for name in $([[ $target == all ]] && echo swift scripts shim || echo "$target"); do
        [[ $name =~ ^(swift|scripts|shim|web)$ ]] || { echo "unknown target: $name; use all, swift, scripts, shim, or web" >&2; exit 2; }
        "format_$name"
    done
    echo "format complete ($target)"

# Regenerate the files built from support-codes.json and the license inventory.
[group('Checks')]
generate:
    {{ uv }} scripts/support_codes.py
    {{ uv }} scripts/licenses.py

# Build the Apple Silicon release binary.
[group('Checks')]
build:
    {{ uv }} scripts/swift_build.py --configuration release

# Run deterministic onboarding, API, installer, and persistence workflows without public network access.
[group('Checks')]
integration: (swift-tests 'integration')

# Run unit tests whose identifier matches FILTER (a regex inside the unit target).
[group('Checks')]
test filter: (swift-tests 'unit' filter)

# Run read-only contracts against live Yostar and Gryphline services; never part of normal source checks.
[group('Checks')]
live-contracts: (swift-tests 'live')

# Sample, compare, or export benchmark runs; sample takes CASE SECONDS TARGET NOTE, compare takes BASELINE CANDIDATE, export takes BASELINE CANDIDATE OUTPUT [EXTRA [EXTRA_LABEL]].
[group('Benchmarks')]
benchmark action='sample' first='' second='' third='' fourth='' fifth='':
    #!/usr/bin/env bash
    set -euo pipefail
    case {{ quote(action) }} in
        sample) exec {{ uv }} scripts/benchmark.py sample {{ quote(first) }} --seconds {{ quote(second) }} --target {{ if third == '' { 'arknights-client' } else { quote(third) } }} --note {{ quote(fourth) }} ;;
        compare) exec {{ uv }} scripts/benchmark.py compare {{ quote(first) }} {{ quote(second) }} ;;
        export) [[ -n {{ quote(third) }} ]] || { echo "export needs an output path" >&2; exit 2; }; exec {{ uv }} scripts/benchmark.py export {{ quote(first) }} {{ quote(second) }} --output {{ quote(third) }} {{ if fourth != '' { '--extra ' + quote(fourth) } else { '' } }} {{ if fifth != '' { '--extra-label ' + quote(fifth) } else { '' } }} ;;
        *) echo "unknown action: "{{ quote(action) }}"; use sample, compare, or export" >&2; exit 2 ;;
    esac

# Build, then run one Swift test level (unit, integration, live) with isolated HOME and TMPDIR; only live may use the network.
[private]
swift-tests level filter='':
    #!/usr/bin/env bash
    set -euo pipefail
    level={{ quote(level) }}
    filter={{ quote(filter) }}
    integration=ArknightsClientIntegrationTests
    live=ArknightsClientLiveContractTests
    gate=""
    case "$level" in
        unit)
            targets="$(perl -0ne 'print "$1\n" while /\.testTarget\(\s*name:\s*"([^"]+)"/g' Package.swift | grep -E 'Tests$' | grep -vxE "$integration|$live" | paste -sd'|' -)"
            ;;
        integration)
            targets="$integration"
            gate=ARKNIGHTS_CLIENT_INTEGRATION_TESTS=RUN_DETERMINISTIC_INTEGRATION_TESTS
            ;;
        live)
            targets="$live"
            gate=ARKNIGHTS_CLIENT_LIVE_CONTRACT_TESTS=RUN_YOSTAR_PUBLIC_NETWORK_SMOKE_TESTS
            ;;
        *) echo "unknown test level: $level" >&2; exit 2 ;;
    esac
    [[ -n $targets ]] || { echo "no test targets declared for $level in Package.swift" >&2; exit 1; }
    expression="^($targets)\\."
    [[ -z $filter ]] || expression+=".*$filter"
    read -ra architectures <<<"$({{ uv }} scripts/project_config.py swift-architecture-arguments)"
    swift build -q --build-tests "${architectures[@]}"
    listing="$(swift test list --skip-build --disable-sandbox --disable-automatic-resolution "${architectures[@]}")"
    count="$(grep -cE "$expression" <<<"$listing" || true)"
    if [[ $count -eq 0 ]]; then
        echo "Swift $level tests: no tests match ${filter:-$targets}" >&2
        exit 1
    fi
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/arknights-$level-tests-XXXXXX")"
    trap 'rm -rf "$scratch"' EXIT
    mkdir "$scratch/home" "$scratch/tmp"
    run=(env HOME="$scratch/home" CFFIXED_USER_HOME="$scratch/home" TMPDIR="$scratch/tmp/" $gate
        swift test -q --disable-xctest --skip-build --disable-sandbox --disable-automatic-resolution
        --filter "$expression" "${architectures[@]}")
    if [[ $level == live ]]; then
        "${run[@]}"
    else
        /usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network*)' "${run[@]}"
    fi
    echo "Swift $level tests passed ($count tests)"

# Run deterministic validation, integration tests, and build the release binary.
[group('Checks')]
ci: check integration build

# Download the pinned runtime (default), pin a release with update (tag or latest; add prerelease to allow prereleases), or verify the pin with check.
[group('Runtime')]
runtime action='download' tag='latest' prerelease='':
    @case {{ quote(action) }} in download) {{ uv }} scripts/download_runtime.py;; check) {{ uv }} scripts/update_runtime.py --check;; update) if [[ {{ quote(prerelease) }} == "prerelease" ]]; then {{ uv }} scripts/update_runtime.py --tag {{ quote(tag) }} --include-prerelease; else {{ uv }} scripts/update_runtime.py --tag {{ quote(tag) }}; fi;; *) echo "unknown action: "{{ quote(action) }}"; use download, update, or check" >&2; exit 2;; esac

# Build the application bundle; optionally embed a Wine runtime directory.
[group('Packaging')]
app runtime='':
    {{ uv_packaging }} scripts/build_app.py {{ if runtime != '' { '--runtime ' + quote(runtime) } else { '' } }}

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
    #!/usr/bin/env bash
    set -euo pipefail
    die() { echo "$1" >&2; exit 1; }
    {{ uv }} scripts/release.py validate {{ quote(version) }}
    [[ -z "$(git status --porcelain)" ]] || die "the working tree must be clean"
    [[ "$(git branch --show-current)" == main ]] || die "releases must be triggered from main after the release branch is merged"
    git fetch --quiet
    upstream="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)" || die "main has no upstream"
    [[ "$(git rev-parse HEAD)" == "$(git rev-parse "$upstream")" ]] || die "main must match $upstream"
    gh auth status >/dev/null
    gh workflow run release.yml --ref main --field version={{ quote(version) }}
    echo "Triggered draft release v"{{ quote(version) }}

# Show manual and Sparkle app-download statistics for published releases. Requires GitHub CLI access.
[group('Owner')]
stats:
    {{ uv }} scripts/release_statistics.py
