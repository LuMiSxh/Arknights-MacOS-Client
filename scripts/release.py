#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Print or validate the release notes of one version in CHANGELOG.md."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from lib.common import PROJECT_DIR, VERSION_PATTERN, fail, run_main
from lib.console import success
from lib.project_config import load_project_configuration


def extract(text: str, version: str) -> str:
    heading = re.compile(
        rf"^## \[{re.escape(version)}\](?:[ \t]+-[ \t]+[^\r\n]+)?$",
        re.MULTILINE,
    )
    match = heading.search(text)
    if match is None:
        fail(f"CHANGELOG.md does not contain a {version} release section")
    start = match.end()
    next_heading = re.search(r"^## \[", text[start:], re.MULTILINE)
    end = start + next_heading.start() if next_heading else len(text)
    body = text[start:end].strip()
    if not body:
        fail(f"CHANGELOG.md section {version} is empty")
    return body


def validate_release(version: str, changelog_path: Path, marketing_version: str) -> str:
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
    parser.add_argument("command", choices=("notes", "validate"))
    parser.add_argument("version")
    arguments = parser.parse_args()
    changelog = PROJECT_DIR / "CHANGELOG.md"
    if arguments.command == "notes":
        print(extract(changelog.read_text(encoding="utf-8"), arguments.version))
        return
    marketing_version = load_project_configuration().product.marketing_version
    validate_release(arguments.version, changelog, marketing_version)
    success(f"Release metadata matches {arguments.version}")


if __name__ == "__main__":
    run_main(main)
