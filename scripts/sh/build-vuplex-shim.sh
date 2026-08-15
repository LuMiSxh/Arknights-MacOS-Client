#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

usage() {
	echo "usage: $0 [OUTPUT_PATH]" >&2
}

if [[ $# -gt 1 ]]; then
	usage
	exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/../.." && pwd)"
output_path="${1:-${project_dir}/.build/helpers/Vuplex WebView.vuplex}"
source_path="${project_dir}/RuntimeSupport/VuplexShim/VuplexShim.c"
userenv_source_path="${project_dir}/RuntimeSupport/VuplexShim/UserenvCompat.c"
output_dir="$(dirname "${output_path}")"
userenv_output_path="${output_dir}/userenv.dll"

command -v uv >/dev/null 2>&1 || { echo "error: uv is required" >&2; exit 1; }
[[ -f "${source_path}" ]] || { echo "error: shim source not found: ${source_path}" >&2; exit 1; }
[[ -f "${userenv_source_path}" ]] \
	|| { echo "error: compatibility source not found: ${userenv_source_path}" >&2; exit 1; }
mkdir -p "${output_dir}"
output_dir="$(cd "${output_dir}" && pwd)"
output_path="${output_dir}/$(basename "${output_path}")"
userenv_output_path="${output_dir}/userenv.dll"
temporary_path="${output_path}.tmp"
temporary_dir="$(mktemp -d "${output_dir}/.vuplex-build.XXXXXX")"
userenv_temporary_path="${temporary_dir}/userenv.dll"
trap 'rm -f "${temporary_path}"; rm -rf "${temporary_dir}"' EXIT

uv run --no-project --with ziglang==0.15.1 python -m ziglang cc \
	-target x86_64-windows-gnu \
	-O2 \
	-Wl,/subsystem:windows \
	"${source_path}" \
	-lshell32 \
	-o "${temporary_path}"

uv run --no-project --with ziglang==0.15.1 python -m ziglang cc \
	-target x86_64-windows-gnu \
	-O2 \
	-shared \
	"${userenv_source_path}" \
	-ladvapi32 \
	-o "${userenv_temporary_path}"

uv run --no-project --with ziglang==0.15.1 python -c 'import pathlib, struct, sys; data = pathlib.Path(sys.argv[1]).read_bytes(); offset = struct.unpack_from("<I", data, 0x3C)[0] if len(data) >= 0x40 and data[:2] == b"MZ" else -1; valid = offset >= 0 and offset + 26 <= len(data) and data[offset:offset + 4] == bytes((80, 69, 0, 0)) and struct.unpack_from("<H", data, offset + 4)[0] == 0x8664 and struct.unpack_from("<H", data, offset + 24)[0] == 0x20B; (_ for _ in ()).throw(SystemExit(f"error: expected PE32+ x86-64 executable: {sys.argv[1]}")) if not valid else None' "${temporary_path}"
uv run --no-project --with ziglang==0.15.1 python -c 'import pathlib, struct, sys; data = pathlib.Path(sys.argv[1]).read_bytes(); offset = struct.unpack_from("<I", data, 0x3C)[0] if len(data) >= 0x40 and data[:2] == b"MZ" else -1; valid = offset >= 0 and offset + 26 <= len(data) and data[offset:offset + 4] == bytes((80, 69, 0, 0)) and struct.unpack_from("<H", data, offset + 4)[0] == 0x8664 and struct.unpack_from("<H", data, offset + 24)[0] == 0x20B; (_ for _ in ()).throw(SystemExit(f"error: expected PE32+ x86-64 DLL: {sys.argv[1]}")) if not valid else None' "${userenv_temporary_path}"

mv -f "${temporary_path}" "${output_path}"
mv -f "${userenv_temporary_path}" "${userenv_output_path}"
rm -rf "${temporary_dir}"
trap - EXIT
echo "Built ${output_path}"
echo "Built ${userenv_output_path}"
