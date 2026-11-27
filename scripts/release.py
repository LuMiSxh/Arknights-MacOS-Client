#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Print or validate the release notes of one version in CHANGELOG.md."""

import argparse
import re
import xml.etree.ElementTree as ET
from pathlib import Path

from lib.common import PROJECT_DIR, VERSION_PATTERN, fail, run_main
from lib.console import success
from lib.project_config import load_project_configuration
from lib.sparkle_appcast import CANARY_CHANNEL

STABLE_CHANNEL = "stable"
RELEASE_CANDIDATE_SUFFIX = re.compile(r"-rc\.[1-9][0-9]*$")


def base_version(version: str) -> str:
    """Return `X.Y.Z` for a release version that may end in `-rc.N`."""
    return RELEASE_CANDIDATE_SUFFIX.sub("", version)


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


def validate_release(
    version: str,
    changelog_path: Path,
    marketing_version: str,
    channel: str = STABLE_CHANNEL,
) -> str:
    """Validate the requested version and return its release notes.

    Only the canary channel accepts `X.Y.Z-rc.N`; notes and the app version use `X.Y.Z`.
    """
    base = base_version(version) if channel == CANARY_CHANNEL else version
    if not VERSION_PATTERN.fullmatch(base):
        fail("version must use X.Y.Z with numeric components (X.Y.Z-rc.N for canary)")
    release_notes = extract(changelog_path.read_text(encoding="utf-8"), base)
    if marketing_version != base:
        fail(
            "Resources/Info.plist CFBundleShortVersionString "
            f"is {marketing_version!r}, expected {base!r}"
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


def bundle_version(
    run_number: int, appcast_text: str | None, minimum_build: int = 0
) -> int:
    """Return the CFBundleVersion that Sparkle orders updates by.

    The CI run number restarts when the workflow is renamed or recreated, so the
    result must stay above every build already published. Without a previous
    appcast (the first release), the run number is used. A yanked release no
    longer appears in the latest appcast, so `minimum_build` lifts the result
    above builds that users may still have installed.
    """
    published = 0 if appcast_text is None else latest_published_build(appcast_text) + 1
    return max(published, run_number, minimum_build)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    notes_parser = commands.add_parser("notes", help="print the release notes")
    notes_parser.add_argument("version")
    validate_parser = commands.add_parser("validate", help="check release metadata")
    validate_parser.add_argument("version")
    validate_parser.add_argument(
        "--channel", choices=(STABLE_CHANNEL, CANARY_CHANNEL), default=STABLE_CHANNEL
    )
    bundle_parser = commands.add_parser(
        "bundle-version", help="print the next CFBundleVersion"
    )
    bundle_parser.add_argument("run_number", type=int)
    bundle_parser.add_argument("--previous-appcast", type=Path)
    bundle_parser.add_argument("--minimum-build", type=int, default=0)
    arguments = parser.parse_args()
    if arguments.command == "bundle-version":
        appcast_text = (
            arguments.previous_appcast.read_text(encoding="utf-8")
            if arguments.previous_appcast
            else None
        )
        print(
            bundle_version(arguments.run_number, appcast_text, arguments.minimum_build)
        )
        return
    changelog = PROJECT_DIR / "CHANGELOG.md"
    if arguments.command == "notes":
        print(
            extract(
                changelog.read_text(encoding="utf-8"), base_version(arguments.version)
            )
        )
        return
    marketing_version = load_project_configuration().product.marketing_version
    validate_release(arguments.version, changelog, marketing_version, arguments.channel)
    success(f"Release metadata matches {arguments.version}")


if __name__ == "__main__":
    run_main(main)
