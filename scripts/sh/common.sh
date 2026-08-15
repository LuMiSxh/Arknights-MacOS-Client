#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${scripts_dir}/../.." && pwd)"
python_scripts_dir="${project_dir}/scripts/python"
# Referenced by scripts that source this file.
# shellcheck disable=SC2034
readonly scripts_dir project_dir python_scripts_dir

fail() {
	echo "error: $*" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_file() {
	[[ -f "$1" ]] || fail "required file not found: $1"
}

require_directory() {
	[[ -d "$1" ]] || fail "required directory not found: $1"
}
