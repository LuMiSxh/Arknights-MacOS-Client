#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

if [[ $# -gt 0 ]]; then
	if [[ "$1" == "-h" || "$1" == "--help" ]]; then
		echo "usage: $0" >&2
		exit 0
	fi
	fail "unknown argument: $1"
fi

source_icon="${project_dir}/Resources/AppIcon.icon"
asset_contents="${project_dir}/Resources/AppIconAssetContents.json"
rendered_icon="${project_dir}/.build/AppIcon.png"
preview_icon="${project_dir}/Resources/AppIcon.png"
catalog_dir="${project_dir}/.build/AppIcon.xcassets"
iconset_dir="${catalog_dir}/AppIcon.appiconset"
compiled_dir="${project_dir}/.build/AppIcon.compiled"
dynamic_dir="${project_dir}/.build/AppIcon.dynamic"
output_icns="${project_dir}/Resources/AppIcon.icns"
output_assets="${project_dir}/Resources/Assets.car"
icon_composer_tool="/Applications/Icon Composer.app/Contents/Executables/ictool"

require_command actool
require_command sips
require_directory "${source_icon}"
[[ -x "${icon_composer_tool}" ]] || fail "Icon Composer command not found: ${icon_composer_tool}"

rm -rf "${catalog_dir}" "${compiled_dir}" "${dynamic_dir}"
mkdir -p "${iconset_dir}" "${compiled_dir}" "${dynamic_dir}"

# Keep the README preview in sync with the layered Icon Composer source. The
# application itself uses Assets.car so macOS can render the dynamic layers.
"${icon_composer_tool}" "${source_icon}" \
	--export-image \
	--output-file "${rendered_icon}" \
	--platform macOS \
	--rendition Default \
	--width 1024 \
	--height 1024 \
	--scale 1
sips --resampleHeightWidth 512 512 "${rendered_icon}" --out "${preview_icon}" >/dev/null

# Prefer Apple's native layered icon compiler when the installed Xcode supports it.
if actool "${source_icon}" \
		--compile "${dynamic_dir}" \
		--output-partial-info-plist "${dynamic_dir}/Info.plist" \
		--app-icon AppIcon \
		--enable-on-demand-resources NO \
		--development-region en \
		--target-device mac \
		--minimum-deployment-target 26.0 \
		--platform macosx \
		--notices \
		--warnings \
		--errors \
		--output-format human-readable-text \
		>"${dynamic_dir}/actool.log" 2>&1 \
		&& test -f "${dynamic_dir}/AppIcon.icns" \
		&& test -f "${dynamic_dir}/Assets.car"; then
	cp "${dynamic_dir}/AppIcon.icns" "${output_icns}"
	cp "${dynamic_dir}/Assets.car" "${output_assets}"
	echo "Built layered ${output_icns} and ${output_assets}"
	exit 0
fi

# Some Xcode 26 toolchains cannot compile .icon sources reliably. Render the same
# composition and package it as an asset-catalog icon instead.
echo "Native .icon compilation unavailable; building the asset-catalog fallback."
echo "actool output: ${dynamic_dir}/actool.log"
require_command magick
require_file "${asset_contents}"

cp "${asset_contents}" "${iconset_dir}/Contents.json"

for size in 16 32 128 256 512; do
	double_size=$((size * 2))
	magick "${rendered_icon}" -resize "${size}x${size}" \
		"${iconset_dir}/icon_${size}x${size}.png"
	magick "${rendered_icon}" -resize "${double_size}x${double_size}" \
		"${iconset_dir}/icon_${size}x${size}@2x.png"
done

actool "${catalog_dir}" \
	--compile "${compiled_dir}" \
	--output-partial-info-plist "${compiled_dir}/Info.plist" \
	--app-icon AppIcon \
	--enable-on-demand-resources NO \
	--development-region en \
	--target-device mac \
	--minimum-deployment-target 26.0 \
	--platform macosx \
	--notices \
	--warnings \
	--errors \
	--output-format human-readable-text

test -f "${compiled_dir}/AppIcon.icns"
test -f "${compiled_dir}/Assets.car"
cp "${compiled_dir}/AppIcon.icns" "${output_icns}"
cp "${compiled_dir}/Assets.car" "${output_assets}"

echo "Built ${output_icns} and ${output_assets}"
