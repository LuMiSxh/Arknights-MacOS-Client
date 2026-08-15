#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

usage() {
	echo "usage: $0 [--runtime DIRECTORY]" >&2
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
executable_name="ArknightsClient"
dist_dir="${project_dir}/dist"
app_bundle="${project_dir}/dist/${app_name}.app"

require_command codesign
require_command lipo
require_command plutil
require_command stat
require_command swift
require_command tar
require_command uv
require_file "${project_dir}/Resources/Info.plist"
require_file "${project_dir}/Resources/AppIcon.icns"
require_file "${project_dir}/Resources/Assets.car"
require_file "${project_dir}/LICENSE"
require_file "${project_dir}/CHANGELOG.md"
require_file "${project_dir}/runtime.json"
require_file "${project_dir}/docs/legal/source-code.md"
require_file "${project_dir}/docs/legal/third-party-notices.md"
require_file "${script_dir}/build-vuplex-shim.sh"
require_file "${python_scripts_dir}/patch-wine-runtime.py"
require_file "${python_scripts_dir}/runtime-config.py"
require_directory "${project_dir}/docs/legal/licenses"
uv run --no-project --python 3.13 \
	"${python_scripts_dir}/runtime-config.py" --validate "${project_dir}/runtime.json"

for required_license in \
	apache-2.0.txt \
	fdk-aac.txt \
	gpl-2.0.txt \
	gpl-3.0.txt \
	lgpl-2.1.txt \
	lgpl-3.0.txt \
	mit-dxmt.txt
do
	require_file "${project_dir}/docs/legal/licenses/${required_license}"
done

if [[ -n "${runtime_dir}" ]]; then
	require_directory "${runtime_dir}"
	runtime_dir="$(cd "${runtime_dir}" && pwd)"
fi

cd "${project_dir}"
swift build --configuration release --arch arm64
binary_dir="$(swift build --configuration release --arch arm64 --show-bin-path)"
binary_path="${binary_dir}/${executable_name}"

[[ -x "${binary_path}" ]] || fail "release executable not found: ${binary_path}"

mkdir -p "${dist_dir}"
staging_dir="$(mktemp -d "${dist_dir}/.app-build.XXXXXX")"
staged_app="${staging_dir}/${app_name}.app"

cleanup() {
	rm -rf "${staging_dir}"
}
trap cleanup EXIT

mkdir -p "${staged_app}/Contents/MacOS" "${staged_app}/Contents/Resources"
install -m 0755 "${binary_path}" "${staged_app}/Contents/MacOS/${executable_name}"
install -m 0644 "${project_dir}/Resources/Info.plist" "${staged_app}/Contents/Info.plist"
install -m 0644 \
	"${project_dir}/Resources/AppIcon.icns" \
	"${staged_app}/Contents/Resources/AppIcon.icns"
install -m 0644 \
	"${project_dir}/Resources/Assets.car" \
	"${staged_app}/Contents/Resources/Assets.car"
vuplex_shim="${project_dir}/.build/helpers/Vuplex WebView.vuplex"
"${script_dir}/build-vuplex-shim.sh" "${vuplex_shim}"
vuplex_userenv="$(dirname "${vuplex_shim}")/userenv.dll"
mkdir -p "${staged_app}/Contents/Resources/Compatibility"
install -m 0644 \
	"${vuplex_shim}" \
	"${staged_app}/Contents/Resources/Compatibility/Vuplex WebView.vuplex"
install -m 0644 \
	"${vuplex_userenv}" \
	"${staged_app}/Contents/Resources/Compatibility/userenv.dll"
plutil -lint "${staged_app}/Contents/Info.plist" >/dev/null

if [[ -n "${runtime_dir}" ]]; then
	[[ -x "${runtime_dir}/bin/wine64" ]] \
		|| fail "runtime executable not found: ${runtime_dir}/bin/wine64"
	[[ -x "${runtime_dir}/bin/wineserver" ]] \
		|| fail "runtime executable not found: ${runtime_dir}/bin/wineserver"
	[[ -d "${runtime_dir}/DXMT/x64" ]] \
		|| fail "runtime DXMT payload not found: ${runtime_dir}/DXMT/x64"

	runtime_destination="${staged_app}/Contents/Resources/Runtime"
	mkdir -p "${runtime_destination}"
	tar \
		--exclude='*.wine-original' \
		--exclude='./include' \
		--exclude='./share/man' \
		--exclude='./share/wine/mono' \
		-C "${runtime_dir}" \
		-cf - . | tar -C "${runtime_destination}" -xf -

	# The supported Wine process is x86_64 and runs through Rosetta. Universal
	# libraries only need their x86_64 slice in the bundled runtime.
	while IFS= read -r -d '' runtime_file; do
		architectures="$(lipo -archs "${runtime_file}" 2>/dev/null || true)"
		if [[ " ${architectures} " == *" x86_64 "* && " ${architectures} " == *" arm64 "* ]]; then
			thin_file="${runtime_file}.x86_64"
			mode="$(stat -f '%Lp' "${runtime_file}")"
			lipo "${runtime_file}" -thin x86_64 -output "${thin_file}"
			chmod "${mode}" "${thin_file}"
			mv "${thin_file}" "${runtime_file}"
		fi
	done < <(find "${runtime_destination}" -type f -print0)

	wine_mac_driver="${runtime_destination}/lib/wine/x86_64-unix/winemac.so"
	require_file "${wine_mac_driver}"
	uv run --python 3.13 "${python_scripts_dir}/patch-wine-runtime.py" "${wine_mac_driver}"
	codesign --force --sign - --timestamp=none "${wine_mac_driver}"
	ln -sfn wine64 "${runtime_destination}/bin/Arknights"
fi

install -m 0644 \
	"${project_dir}/docs/legal/third-party-notices.md" \
	"${staged_app}/Contents/Resources/THIRD_PARTY_NOTICES.md"
install -m 0644 "${project_dir}/LICENSE" "${staged_app}/Contents/Resources/LICENSE"
install -m 0644 "${project_dir}/CHANGELOG.md" "${staged_app}/Contents/Resources/CHANGELOG.md"
install -m 0644 "${project_dir}/runtime.json" "${staged_app}/Contents/Resources/RUNTIME.json"
install -m 0644 \
	"${project_dir}/docs/legal/source-code.md" \
	"${staged_app}/Contents/Resources/SOURCE_CODE.md"

third_party_licenses="${staged_app}/Contents/Resources/ThirdPartyLicenses"
mkdir -p "${third_party_licenses}"
license_count=0
for license_file in "${project_dir}/docs/legal/licenses/"*.txt; do
	[[ -f "${license_file}" ]] || continue
	install -m 0644 "${license_file}" "${third_party_licenses}/"
	license_count=$((license_count + 1))
done
[[ ${license_count} -gt 0 ]] || fail "no third-party license files found"

codesign --force --sign - --timestamp=none "${staged_app}"
codesign --verify --deep --strict --verbose=2 "${staged_app}"

rm -rf "${app_bundle}"
mv "${staged_app}" "${app_bundle}"
trap - EXIT
rmdir "${staging_dir}"

echo "Built ${app_bundle}"
