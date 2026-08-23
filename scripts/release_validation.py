#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Validate release metadata stored in the repository."""

from __future__ import annotations

import argparse
from pathlib import Path

from extract_changelog import extract
from lib.common import PROJECT_DIR, VERSION_PATTERN, fail, run_main, success
from lib.project_config import load_project_configuration


def validate_release(
    version: str,
    changelog_path: Path,
    marketing_version: str,
) -> str:
    """Validate the requested version and return its release notes."""
    if not VERSION_PATTERN.fullmatch(version):
        fail("version must use X.Y.Z with numeric components")

    release_notes = extract(changelog_path.read_text(encoding="utf-8"), version)
    if marketing_version != version:
        fail(
            "Resources/Info.plist CFBundleShortVersionString "
            f"is {marketing_version!r}, expected {version!r}"
        )
    return release_notes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    arguments = parser.parse_args()
    configuration = load_project_configuration()
    validate_release(
        arguments.version,
        PROJECT_DIR / "CHANGELOG.md",
        configuration.product.marketing_version,
    )
    success(f"Release metadata matches {arguments.version}")


if __name__ == "__main__":
    run_main(main)
