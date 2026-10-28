#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Generate or check every output of `support-codes.json`."""

from __future__ import annotations

import argparse

from lib.common import PROJECT_DIR, run_main
from lib.console import info, success, warning
from lib.support_codes import check, regenerate


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail when a generated support-code file is missing, stale, or orphaned",
    )
    args = parser.parse_args()

    if args.check:
        problems = check(PROJECT_DIR)
        for problem in problems:
            warning(problem)
        if problems:
            raise SystemExit(1)
        success("support-code outputs are current")
        return

    changed = regenerate(PROJECT_DIR)
    for path in changed:
        info(f"wrote {path}")
    success(f"support-code outputs are current ({len(changed)} changed)")


if __name__ == "__main__":
    run_main(main)
