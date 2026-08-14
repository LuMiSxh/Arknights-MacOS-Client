#!/usr/bin/env bash
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

"${script_dir}/build-app.sh"

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
