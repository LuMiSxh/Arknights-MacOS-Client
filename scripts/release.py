#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Print or validate the release notes of one version in CHANGELOG.md."""

from __future__ import annotations

import argparse
import re
import xml.etree.ElementTree as ET
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


SPARKLE_VERSION_TAG = "{http://www.andymatuschak.org/xml-namespaces/sparkle}version"


def latest_published_build(appcast_text: str) -> int:
    """Return the highest `sparkle:version` listed by a published appcast."""
    try:
        root = ET.fromstring(appcast_text)
    except ET.ParseError as error:
        fail(f"could not parse the previous Sparkle appcast: {error}")
    builds: list[int] = []
    for element in root.iter(SPARKLE_VERSION_TAG):
        text = (element.text or "").strip()
        if not re.fullmatch(r"[0-9]+", text):
            fail(f"previous Sparkle appcast has a non-numeric sparkle:version {text!r}")
        builds.append(int(text))
    if not builds:
        fail("previous Sparkle appcast lists no sparkle:version")
    return max(builds)


def bundle_version(run_number: int, appcast_text: str | None) -> int:
    """Return the CFBundleVersion that Sparkle orders updates by.

    The CI run number restarts when the workflow is renamed or recreated, so the
    result must stay above every build already published. Without a previous
    appcast (the first release), the run number is used.
    """
    if appcast_text is None:
        return run_number
    return max(latest_published_build(appcast_text) + 1, run_number)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    notes_parser = commands.add_parser("notes", help="print the release notes")
    notes_parser.add_argument("version")
    validate_parser = commands.add_parser("validate", help="check release metadata")
    validate_parser.add_argument("version")
    bundle_parser = commands.add_parser(
        "bundle-version", help="print the next CFBundleVersion"
    )
    bundle_parser.add_argument("run_number", type=int)
    bundle_parser.add_argument("--previous-appcast", type=Path)
    arguments = parser.parse_args()
    if arguments.command == "bundle-version":
        appcast_text = (
            arguments.previous_appcast.read_text(encoding="utf-8")
            if arguments.previous_appcast
            else None
        )
        print(bundle_version(arguments.run_number, appcast_text))
        return
    changelog = PROJECT_DIR / "CHANGELOG.md"
    if arguments.command == "notes":
        print(extract(changelog.read_text(encoding="utf-8"), arguments.version))
        return
    marketing_version = load_project_configuration().product.marketing_version
    validate_release(arguments.version, changelog, marketing_version)
    success(f"Release metadata matches {arguments.version}")


if __name__ == "__main__":
    run_main(main)
