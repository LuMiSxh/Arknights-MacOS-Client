#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
app_name="Arknights Client"
executable_name="ArknightsClient"
app_bundle="${project_dir}/dist/${app_name}.app"

command -v swift >/dev/null
command -v codesign >/dev/null

cd "${project_dir}"
swift build --configuration release
binary_dir="$(swift build --configuration release --show-bin-path)"
binary_path="${binary_dir}/${executable_name}"

if [[ ! -x "${binary_path}" ]]; then
    echo "Release executable not found: ${binary_path}" >&2
    exit 1
fi

rm -rf "${app_bundle}"
mkdir -p "${app_bundle}/Contents/MacOS"
cp "${binary_path}" "${app_bundle}/Contents/MacOS/${executable_name}"
cp "${project_dir}/Resources/Info.plist" "${app_bundle}/Contents/Info.plist"

codesign --force --sign - --timestamp=none "${app_bundle}"
codesign --verify --deep --strict --verbose=2 "${app_bundle}"

echo "Built ${app_bundle}"
