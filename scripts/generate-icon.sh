#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
source_svg="${project_dir}/Resources/AppIcon.svg"
iconset_dir="${project_dir}/.build/AppIcon.iconset"
output_icns="${project_dir}/Resources/AppIcon.icns"

command -v magick >/dev/null
command -v iconutil >/dev/null

rm -rf "${iconset_dir}"
mkdir -p "${iconset_dir}"

for size in 16 32 128 256 512; do
    double_size=$((size * 2))
    magick -background none "${source_svg}" -resize "${size}x${size}" "${iconset_dir}/icon_${size}x${size}.png"
    magick -background none "${source_svg}" -resize "${double_size}x${double_size}" "${iconset_dir}/icon_${size}x${size}@2x.png"
done

iconutil --convert icns --output "${output_icns}" "${iconset_dir}"
echo "Built ${output_icns}"
