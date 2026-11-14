#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Pin both lanes of a published runtime release and update every mention of it.

Without options the script resolves `latest`, reads `provenance.json` and the `.sha256`
files of that release over HTTPS, and rewrites both lanes of `runtime.json`, the generated
`runtime` blocks, and (through `scripts/licenses.py`) the license documents. `--architecture`
limits the update to one lane. `--tag TAG` pins a given release. `latest` skips drafts and
prereleases unless `--include-prerelease` is set. `--check` verifies `runtime.json` and the
generated blocks offline and writes nothing.
"""

from __future__ import annotations

import argparse

from lib.common import PROJECT_DIR, run_main
from lib.console import info, success
from lib.licenses import regenerate
from lib.project_config import load_project_configuration
from lib.runtime_update import (
    check,
    https_fetcher,
    latest_tag,
    normalize_tag,
    update,
)
from runtime_config import RUNTIME_ARCHITECTURES


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", default="latest", help="release tag or latest")
    parser.add_argument(
        "--architecture",
        choices=tuple(RUNTIME_ARCHITECTURES),
        help="runtime lane to pin (default: both lanes)",
    )
    parser.add_argument(
        "--include-prerelease",
        action="store_true",
        help="let latest select a prerelease",
    )
    parser.add_argument(
        "--moltenvk-version",
        help="MoltenVK version; required only when its commit changes",
    )
    parser.add_argument("--check", action="store_true", help="verify, do not write")
    arguments = parser.parse_args()

    if arguments.check:
        check(PROJECT_DIR)
        success("The runtime pin and its generated blocks are current")
        return

    product = load_project_configuration().product
    fetch = https_fetcher(f"{product.bundle_identifier}.build")
    architectures = (
        tuple(RUNTIME_ARCHITECTURES)
        if arguments.architecture is None
        else (arguments.architecture,)
    )
    info("Resolving the runtime release")
    tag = (
        latest_tag(fetch, arguments.include_prerelease)
        if arguments.tag == "latest"
        else normalize_tag(arguments.tag)
    )
    lanes = ", ".join(architectures)
    info(f"Pinning the {lanes} runtime {tag}")
    info("Reading the release provenance")
    changed = update(
        PROJECT_DIR,
        tag,
        fetch,
        arguments.moltenvk_version,
        architectures=architectures,
    )
    changed.extend(regenerate(PROJECT_DIR))
    for path in changed:
        info(f"Updated {path}")
    success(
        f"The {lanes} runtime {tag} is pinned"
        if changed
        else f"The {lanes} runtime {tag} was already pinned"
    )


if __name__ == "__main__":
    run_main(main)
