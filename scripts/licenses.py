#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Generate or check the third-party license notices.

Without options the script rewrites the generated blocks of `docs/legal/`.
`--check` fails when the index, `Package.resolved`, `web/package.json`, the bundled
resources, the license texts, or the generated blocks disagree.
`--runtime DIR` merges the license index of a prepared runtime into the check and into
the generated license-text page and the compiled notices file.
`--bundle RESOURCES` writes the compiled notices of an app build and merges the license
index of `--runtime`. `--strict` fails on any license that is not verified and on a
runtime without license files.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from lib.common import PROJECT_DIR, run_main
from lib.console import info, success, warning
from lib.licenses import (
    COMPILED_NOTICES,
    check_all,
    generate_documents,
    stage_bundle,
    write_compiled_notices,
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", choices=("generate",), default="generate")
    parser.add_argument("--check", action="store_true", help="verify, do not write")
    parser.add_argument("--runtime", type=Path, help="prepared runtime directory")
    parser.add_argument("--bundle", type=Path, help="app Resources directory to fill")
    parser.add_argument(
        "--strict", action="store_true", help="fail on unverified licenses"
    )
    arguments = parser.parse_args()
    runtime = arguments.runtime.resolve() if arguments.runtime else None

    if arguments.check:
        warnings = check_all(PROJECT_DIR, runtime, arguments.strict)
        for message in warnings:
            warning(message)
        success("License inventory is consistent")
        return
    if arguments.bundle is not None:
        warnings = stage_bundle(
            PROJECT_DIR, arguments.bundle.resolve(), runtime, arguments.strict
        )
        for message in warnings:
            warning(message)
        success("Wrote the compiled notices")
        return
    if write_compiled_notices(PROJECT_DIR, runtime):
        info(f"Updated {COMPILED_NOTICES}")
    for path, text in generate_documents(PROJECT_DIR, runtime).items():
        target = PROJECT_DIR / path
        if target.read_text(encoding="utf-8") != text:
            target.write_text(text, encoding="utf-8")
            info(f"Updated {path}")
    success("Generated blocks are current")


if __name__ == "__main__":
    run_main(main)
