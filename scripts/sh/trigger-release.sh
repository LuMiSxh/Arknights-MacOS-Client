#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

usage() {
	echo "usage: $0 X.Y.Z" >&2
}

if [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
	usage
	exit 0
fi

[[ $# -eq 1 ]] || {
	usage
	exit 1
}

version="$1"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version must use X.Y.Z"

require_command gh
require_command git
require_file "${project_dir}/CHANGELOG.md"

grep -Fq "## [${version}]" "${project_dir}/CHANGELOG.md" \
	|| fail "CHANGELOG.md does not contain a ${version} release section"

cd "${project_dir}"
[[ -z "$(git status --porcelain)" ]] || fail "the working tree must be clean"

branch="$(git symbolic-ref --quiet --short HEAD)" \
	|| fail "releases must be triggered from a branch"
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" \
	|| fail "the current branch has no upstream"

git fetch --quiet
[[ "$(git rev-parse HEAD)" == "$(git rev-parse "${upstream}")" ]] \
	|| fail "the current branch must match ${upstream}"

gh auth status >/dev/null
gh workflow run release.yml --ref "${branch}" --field "version=${version}"

echo "Triggered draft release v${version} from ${branch}"
