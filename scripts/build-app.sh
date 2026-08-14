#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
app_name="Arknights Client"
executable_name="ArknightsClient"
app_bundle="${project_dir}/dist/${app_name}.app"

command -v swift >/dev/null
command -v codesign >/dev/null

cd "${project_dir}"
swift build --configuration release --arch arm64
binary_dir="$(swift build --configuration release --arch arm64 --show-bin-path)"
binary_path="${binary_dir}/${executable_name}"

if [[ ! -x "${binary_path}" ]]; then
    echo "Release executable not found: ${binary_path}" >&2
    exit 1
fi

rm -rf "${app_bundle}"
mkdir -p "${app_bundle}/Contents/MacOS" "${app_bundle}/Contents/Resources"
cp "${binary_path}" "${app_bundle}/Contents/MacOS/${executable_name}"
cp "${project_dir}/Resources/Info.plist" "${app_bundle}/Contents/Info.plist"
cp "${project_dir}/Resources/AppIcon.icns" "${app_bundle}/Contents/Resources/AppIcon.icns"

runtime_dir="${ARKNIGHTS_RUNTIME_DIR:-}"
if [[ -n "${runtime_dir}" ]]; then
    if [[ ! -d "${runtime_dir}" ]]; then
        echo "ARKNIGHTS_RUNTIME_DIR must point to an existing directory: ${runtime_dir}" >&2
        exit 1
    fi

    runtime_destination="${app_bundle}/Contents/Resources/Runtime"
    mkdir -p "${runtime_destination}"
    rsync -a \
        --exclude='*.wine-original' \
        --exclude='include/' \
        --exclude='share/man/' \
        --exclude='share/wine/mono/' \
        "${runtime_dir}/" "${runtime_destination}/"
fi

if [[ -f "${project_dir}/docs/legal/third-party-notices.md" ]]; then
    cp "${project_dir}/docs/legal/third-party-notices.md" \
        "${app_bundle}/Contents/Resources/THIRD_PARTY_NOTICES.md"
fi

if [[ -f "${project_dir}/LICENSE" ]]; then
    cp "${project_dir}/LICENSE" "${app_bundle}/Contents/Resources/LICENSE"
fi

if [[ -f "${project_dir}/CHANGELOG.md" ]]; then
    cp "${project_dir}/CHANGELOG.md" "${app_bundle}/Contents/Resources/CHANGELOG.md"
fi

if [[ -f "${project_dir}/docs/legal/source-code.md" ]]; then
    cp "${project_dir}/docs/legal/source-code.md" \
        "${app_bundle}/Contents/Resources/SOURCE_CODE.md"
fi

if [[ -d "${project_dir}/docs/legal/licenses" ]]; then
    third_party_licenses="${app_bundle}/Contents/Resources/ThirdPartyLicenses"
    mkdir -p "${third_party_licenses}"
    cp "${project_dir}/docs/legal/licenses/lgpl-2.1.txt" "${third_party_licenses}/"
fi

codesign --force --sign - --timestamp=none "${app_bundle}"
codesign --verify --deep --strict --verbose=2 "${app_bundle}"

echo "Built ${app_bundle}"
