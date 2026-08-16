#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Validate release metadata stored in the repository."""

from __future__ import annotations

import argparse
import plistlib
import re
from pathlib import Path

from extract_changelog import extract
from lib.common import PROJECT_DIR, fail, run_main, success

VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


def validate_release(
    version: str,
    changelog_path: Path,
    info_plist_path: Path,
) -> str:
    """Validate the requested version and return its release notes."""
    if not VERSION_PATTERN.fullmatch(version):
        fail("version must use X.Y.Z with numeric components")

    release_notes = extract(changelog_path.read_text(encoding="utf-8"), version)
    with info_plist_path.open("rb") as file:
        info_plist = plistlib.load(file)
    bundle_version = info_plist.get("CFBundleShortVersionString")
    if bundle_version != version:
        fail(
            "Resources/Info.plist CFBundleShortVersionString "
            f"is {bundle_version!r}, expected {version!r}"
        )
    return release_notes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    arguments = parser.parse_args()
    validate_release(
        arguments.version,
        PROJECT_DIR / "CHANGELOG.md",
        PROJECT_DIR / "Resources/Info.plist",
    )
    success(f"Release metadata matches {arguments.version}")


if __name__ == "__main__":
    run_main(main)
