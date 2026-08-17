#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = ["dmgbuild==1.6.7"]
# ///
# SPDX-License-Identifier: MPL-2.0

"""Build and verify the distributable Arknights Client disk image."""

from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

from build_app import APP_NAME, build
from lib.common import DIST_DIR, PROJECT_DIR, info, remove_path, run, run_main, success


def build_dmg(runtime: Path) -> Path:
    app = build(runtime)
    destination = DIST_DIR / f"{APP_NAME}.dmg"
    with tempfile.TemporaryDirectory(prefix=".dmg-build.", dir=DIST_DIR) as name:
        staged = Path(name) / destination.name
        info("Creating the compressed disk image")
        run(
            [
                sys.executable,
                "-m",
                "dmgbuild",
                "--settings",
                PROJECT_DIR / "scripts/lib/dmg_settings.py",
                "-D",
                f"app_bundle={app}",
                APP_NAME,
                staged,
            ]
        )
        info("Verifying the disk image")
        run(["hdiutil", "verify", staged])
        remove_path(destination)
        staged.replace(destination)
    success(f"Built {destination.relative_to(PROJECT_DIR)}")
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", required=True, type=Path)
    arguments = parser.parse_args()
    build_dmg(arguments.runtime.resolve())


if __name__ == "__main__":
    run_main(main)
