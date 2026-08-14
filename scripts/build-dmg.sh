#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
app_name="Arknights Client"
app_bundle="${project_dir}/dist/${app_name}.app"
dmg_path="${project_dir}/dist/${app_name}.dmg"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/arknights-client-dmg.XXXXXX")"

cleanup() {
    rm -rf "${staging_dir}"
}
trap cleanup EXIT

command -v hdiutil >/dev/null

runtime_dir="${ARKNIGHTS_RUNTIME_DIR:-}"
if [[ -z "${runtime_dir}" || ! -d "${runtime_dir}" ]]; then
    echo "A Wine + DXMT runtime is required for the distributable DMG." >&2
    echo "Set ARKNIGHTS_RUNTIME_DIR to its directory." >&2
    exit 1
fi

ARKNIGHTS_RUNTIME_DIR="${runtime_dir}" "${script_dir}/build-app.sh"

mkdir -p "${project_dir}/dist"
cp -R "${app_bundle}" "${staging_dir}/${app_name}.app"
ln -s /Applications "${staging_dir}/Applications"

hdiutil create \
    -volname "${app_name}" \
    -srcfolder "${staging_dir}" \
    -ov \
    -format UDZO \
    "${dmg_path}"

echo "Built ${dmg_path}"
