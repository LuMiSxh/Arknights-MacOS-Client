#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

usage() {
	echo "usage: $0 --runtime DIRECTORY" >&2
}

runtime_dir=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--runtime)
			[[ $# -ge 2 ]] || {
				usage
				fail "--runtime requires a directory"
			}
			runtime_dir="$2"
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			usage
			fail "unknown argument: $1"
			;;
	esac
done

app_name="Arknights Client"
app_bundle="${project_dir}/dist/${app_name}.app"
dmg_path="${project_dir}/dist/${app_name}.dmg"

require_command hdiutil
require_command uv

[[ -n "${runtime_dir}" ]] || {
	usage
	fail "a Wine + DXMT runtime is required"
}
require_directory "${runtime_dir}"
runtime_dir="$(cd "${runtime_dir}" && pwd)"

"${script_dir}/build-app.sh" --runtime "${runtime_dir}"

mkdir -p "${project_dir}/dist"
staging_dir="$(mktemp -d "${project_dir}/dist/.dmg-build.XXXXXX")"
staged_dmg="${staging_dir}/${app_name}.dmg"

cleanup() {
	rm -rf "${staging_dir}"
}
trap cleanup EXIT

uv tool run --from 'dmgbuild==1.6.7' dmgbuild \
	--settings "${python_scripts_dir}/dmg-settings.py" \
	-D "app_bundle=${app_bundle}" \
	"${app_name}" \
	"${staged_dmg}"

hdiutil verify "${staged_dmg}"
rm -f "${dmg_path}"
mv "${staged_dmg}" "${dmg_path}"
trap - EXIT
rmdir "${staging_dir}"

echo "Built ${dmg_path}"
