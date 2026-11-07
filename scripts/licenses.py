#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Generate or check the third-party license notices.

Without options the script rewrites the generated blocks of `docs/legal/`. Without
`--runtime` it uses the prepared runtime in `.build/runtime-<lane>` when that runtime
matches `runtime.json`.
`--check` fails when the index, `Package.resolved`, `web/package.json`, the bundled
resources, the license texts, or the generated blocks disagree.
`--runtime DIR` validates the license index of a prepared runtime. It never rewrites
the website documents; the installed runtime archive shows its own notices. `--strict`
fails on any license that is not verified and on a runtime without license files.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from lib.common import PROJECT_DIR, run_main
from lib.console import info, success, warning
from lib.licenses import (
    check_all,
    regenerate,
)
from runtime_config import prepared_runtime


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", choices=("generate",), default="generate")
    parser.add_argument("--check", action="store_true", help="verify, do not write")
    parser.add_argument("--runtime", type=Path, help="prepared runtime directory")

    parser.add_argument(
        "--strict", action="store_true", help="fail on unverified licenses"
    )
    arguments = parser.parse_args()
    runtime = (
        arguments.runtime.resolve()
        if arguments.runtime
        else prepared_runtime(PROJECT_DIR)
    )

    if arguments.check:
        warnings = check_all(PROJECT_DIR, runtime, arguments.strict)
        for message in warnings:
            warning(message)
        success("License inventory is consistent")
        return

    for path in regenerate(PROJECT_DIR):
        info(f"Updated {path}")
    success("Generated blocks are current")


if __name__ == "__main__":
    run_main(main)
