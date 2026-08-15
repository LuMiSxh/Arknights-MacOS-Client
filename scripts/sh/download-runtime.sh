#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

# Prepare the pinned, prebuilt Wine + DXMT runtime used for local builds.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

runtime_config="${project_dir}/runtime.json"
runtime_config_reader="${python_scripts_dir}/runtime-config.py"

require_command uv
require_file "${runtime_config}"
require_file "${runtime_config_reader}"
uv run --no-project --python 3.13 "${runtime_config_reader}" --validate "${runtime_config}"

default_runtime_url="$(
	uv run --no-project --python 3.13 "${runtime_config_reader}" "${runtime_config}" runtime.url
)"
readonly default_runtime_url
default_runtime_sha256="$(
	uv run --no-project --python 3.13 "${runtime_config_reader}" "${runtime_config}" runtime.sha256
)"
readonly default_runtime_sha256

usage() {
	cat >&2 <<'EOF'
usage: download-runtime.sh [--url HTTPS_URL --sha256 CHECKSUM]

Downloads the prebuilt runtime pinned in runtime.json.
The URL and checksum flags are intended only for explicit local compatibility tests.
EOF
}

destination="${project_dir}/.build/runtime"
runtime_url="${default_runtime_url}"
runtime_sha256="${default_runtime_sha256}"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--url)
			[[ $# -ge 2 ]] || {
				usage
				fail "--url requires an HTTPS URL"
			}
			runtime_url="$2"
			shift 2
			;;
		--sha256)
			[[ $# -ge 2 ]] || {
				usage
				fail "--sha256 requires a checksum"
			}
			runtime_sha256="$2"
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

[[ "${runtime_url}" == https://* ]] || fail "runtime URL must be an HTTPS URL"
[[ "${runtime_sha256}" =~ ^[0-9a-fA-F]{64}$ ]] \
	|| fail "runtime checksum must be a 64-character SHA-256 value"

require_command curl
require_command shasum
require_file "${python_scripts_dir}/extract-runtime.py"

destination_parent="$(dirname "${destination}")"
mkdir -p "${destination_parent}"
destination_parent="$(cd "${destination_parent}" && pwd)"
destination="${destination_parent}/runtime"

cache_dir="${project_dir}/.build/runtime-downloads"
mkdir -p "${cache_dir}"
revision_file="${destination}/.arknights-runtime-archive-sha256"

runtime_is_valid() {
	local directory="$1"
	local architecture library runtime_command

	for runtime_command in bin/wine64 bin/wineserver; do
		[[ -x "${directory}/${runtime_command}" ]] || return 1
	done
	[[ -e "${directory}/lib/wine/x86_64-windows/winemetal.dll" ]] || return 1
	for architecture in x64 x32; do
		for library in d3d10core.dll d3d11.dll dxgi.dll winemetal.dll; do
			[[ -f "${directory}/DXMT/${architecture}/${library}" ]] || return 1
		done
	done
	[[ -L "${directory}/bin/Arknights" ]] \
		&& [[ "$(readlink "${directory}/bin/Arknights")" == "wine64" ]]
}

if [[ "$(cat "${revision_file}" 2>/dev/null || true)" == "${runtime_sha256}" ]] \
	&& runtime_is_valid "${destination}"
then
	echo "${destination}"
	exit 0
fi

staging_dir="$(mktemp -d "${destination_parent}/.runtime-download.XXXXXX")"

cleanup() {
	rm -rf "${staging_dir}"
}
trap cleanup EXIT

download_verified_archive() {
	local url="$1"
	local checksum="$2"
	local output="$3"
	local partial="${output}.part"

	if [[ -f "${output}" ]] \
		&& printf '%s  %s\n' "${checksum}" "${output}" | shasum -a 256 --check --status
	then
		return
	fi

	rm -f "${partial}"
	curl --fail --location --proto '=https' --tlsv1.2 "${url}" --output "${partial}"
	printf '%s  %s\n' "${checksum}" "${partial}" | shasum -a 256 --check --status \
		|| fail "downloaded archive failed SHA-256 verification: ${url}"
	mv "${partial}" "${output}"
}

archive_path="${cache_dir}/${runtime_sha256}.tar.gz"
download_verified_archive "${runtime_url}" "${runtime_sha256}" "${archive_path}"
libraries_dir="$(uv run --python 3.13 "${python_scripts_dir}/extract-runtime.py" \
	"${archive_path}" "${staging_dir}/runtime-archive")"
require_directory "${libraries_dir}/Wine"
require_directory "${libraries_dir}/DXMT"

runtime_dir="${staging_dir}/runtime"
mv "${libraries_dir}/Wine" "${runtime_dir}"
mv "${libraries_dir}/DXMT" "${runtime_dir}/DXMT"

ln -sfn wine64 "${runtime_dir}/bin/Arknights"
runtime_is_valid "${runtime_dir}" || fail "runtime archive is incomplete"
printf '%s\n' "${runtime_sha256}" > "${runtime_dir}/.arknights-runtime-archive-sha256"

rm -rf "${destination}"
mv "${runtime_dir}" "${destination}"
echo "${destination}"
